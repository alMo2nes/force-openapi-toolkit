/**
 * RestEndpointInspectorTest
 *
 * Test coverage for RestEndpointInspector class.
 * Uses HttpCalloutMock to simulate Tooling API SOSL and query responses with SymbolTable data.
 */
@isTest
private class RestEndpointInspectorTest {

    // ── Mock Helpers ─────────────────────────────────────────────────────────

    /**
     * Chains two HTTP responses: first the SOSL search result, then the SOQL query result.
     * The Tooling API calls are made in order: search → query.
     */
    private class ToolingApiMock implements HttpCalloutMock {
        private String searchBody;
        private String queryBody;
        private Integer callCount = 0;

        ToolingApiMock(String searchBody, String queryBody) {
            this.searchBody = searchBody;
            this.queryBody = queryBody;
        }

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(callCount == 1 ? searchBody : queryBody);
            return res;
        }
    }

    /** Returns a non-200 status on every call. */
    private class ErrorMock implements HttpCalloutMock {
        private Integer statusCode;
        ErrorMock(Integer statusCode) { this.statusCode = statusCode; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody('{"message":"error"}');
            return res;
        }
    }

    /** Returns 200 for search, error for query. */
    private class SearchOkQueryErrorMock implements HttpCalloutMock {
        private String searchBody;
        private Integer callCount = 0;
        SearchOkQueryErrorMock(String searchBody) { this.searchBody = searchBody; }
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            if (callCount == 1) {
                res.setStatusCode(200);
                res.setBody(searchBody);
            } else {
                res.setStatusCode(500);
                res.setBody('{"message":"server error"}');
            }
            return res;
        }
    }

    // ── JSON Builders ─────────────────────────────────────────────────────────

    private static String buildSearchBody(String apexClassId, String apexClassName) {
        return '{"searchRecords":[{"Id":"' + apexClassId + '","Name":"' + apexClassName + '"}]}';
    }

    private static String buildEmptySearchBody() {
        return '{"searchRecords":[]}';
    }

    /**
     * Builds a minimal SymbolTable with one method annotated with the given HTTP verb.
     */
    private static String buildQueryBody(
        String apexClassId,
        String apexClassName,
        String httpVerb,
        String body,
        Integer methodLine
    ) {
        String symbolTable = '{'
            + '"methods":[{'
            + '"name":"do' + httpVerb + '",'
            + '"returnType":"void",'
            + '"location":{"line":' + methodLine + '},'
            + '"annotations":[{"name":"' + httpVerb + '"}],'
            + '"parameters":[]'
            + '}]'
            + '}';
        String escaped = body.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r');
        return '{"records":[{"Id":"' + apexClassId + '","Name":"' + apexClassName
            + '","Body":"' + escaped + '","SymbolTable":' + symbolTable + '}]}';
    }

    /** Query body whose SymbolTable is null — simulates uncompiled class. */
    private static String buildQueryBodyNullSymbolTable(String apexClassId, String apexClassName) {
        return '{"records":[{"Id":"' + apexClassId + '","Name":"' + apexClassName
            + '","Body":"","SymbolTable":null}]}';
    }

    /** Body without @RestResource annotation. */
    private static String buildQueryBodyNoAnnotation(String apexClassId, String apexClassName) {
        String symbolTable = '{"methods":[]}';
        return '{"records":[{"Id":"' + apexClassId + '","Name":"' + apexClassName
            + '","Body":"","SymbolTable":' + symbolTable + '}]}';
    }

    // ── getRestEndpoints ───────────────────────────────────────────────────────

    @isTest
    static void getRestEndpoints_HttpGetMethod_ReturnsDescriptor() {
        // Given
        String classId = '01p000000000001AAA';
        String className = 'MyRestResource';
        String apexBody = '@RestResource(urlMapping=\'/myresource/*\')\npublic class MyRestResource {\n'
            + '    /**\n     * @description Get a resource\n     */\n'
            + '    @HttpGet\n    public static void doGet() {}\n}';

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(
            buildSearchBody(classId, className),
            buildQueryBody(classId, className, 'HttpGet', apexBody, 6)
        ));

        // When
        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> results = RestEndpointInspector.getRestEndpoints();
        Test.stopTest();

        // Then
        Assert.areEqual(1, results.size(), 'Should return one endpoint descriptor');
        RestEndpointInspector.EndpointDescriptor ed = results[0];
        Assert.areEqual(className, ed.className, 'Class name should match');
        Assert.areEqual('/myresource/*', ed.urlPath, 'URL mapping should be extracted');
        Assert.areEqual(1, ed.httpMethods.size(), 'Should have one HTTP method');
        Assert.areEqual('doHttpGet', ed.httpMethods[0].name, 'Method name should match');
    }

    @isTest
    static void getRestEndpoints_HttpPostMethod_ReturnsDescriptor() {
        // Given
        String classId = '01p000000000002AAA';
        String className = 'PostResource';
        String apexBody = '@RestResource(urlMapping=\'/postresource\')\npublic class PostResource {\n'
            + '    @HttpPost\n    public static void doPost() {}\n}';

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(
            buildSearchBody(classId, className),
            buildQueryBody(classId, className, 'HttpPost', apexBody, 3)
        ));

        // When
        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> results = RestEndpointInspector.getRestEndpoints();
        Test.stopTest();

        // Then
        Assert.areEqual(1, results.size(), 'Should return one descriptor for HttpPost class');
        Assert.areEqual(1, results[0].httpMethods.size(), 'Should have one HttpPost method');
    }

    @isTest
    static void getRestEndpoints_SearchReturnsEmpty_ReturnsEmptyList() {
        // Given
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(buildEmptySearchBody(), ''));

        // When
        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> results = RestEndpointInspector.getRestEndpoints();
        Test.stopTest();

        // Then
        Assert.areEqual(0, results.size(), 'Should return empty list when SOSL finds nothing');
    }

    @isTest
    static void getRestEndpoints_SearchHttpError_ReturnsEmptyList() {
        // Given
        Test.setMock(HttpCalloutMock.class, new ErrorMock(500));

        // When
        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> results = RestEndpointInspector.getRestEndpoints();
        Test.stopTest();

        // Then
        Assert.areEqual(0, results.size(), 'Should return empty list on search HTTP error');
    }

    @isTest
    static void getRestEndpoints_QueryHttpError_ReturnsEmptyList() {
        // Given
        String classId = '01p000000000003AAA';
        Test.setMock(HttpCalloutMock.class, new SearchOkQueryErrorMock(
            buildSearchBody(classId, 'AnyClass')
        ));

        // When
        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> results = RestEndpointInspector.getRestEndpoints();
        Test.stopTest();

        // Then
        Assert.areEqual(0, results.size(), 'Should return empty list on query HTTP error');
    }

    @isTest
    static void getRestEndpoints_NullSymbolTable_SkipsRecord() {
        // Given
        String classId = '01p000000000004AAA';
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(
            buildSearchBody(classId, 'NoSymbol'),
            buildQueryBodyNullSymbolTable(classId, 'NoSymbol')
        ));

        // When
        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> results = RestEndpointInspector.getRestEndpoints();
        Test.stopTest();

        // Then
        Assert.areEqual(0, results.size(), 'Null SymbolTable should be skipped');
    }

    @isTest
    static void getRestEndpoints_NoHttpMethods_ExcludesDescriptor() {
        // Given: class has no HTTP verb annotations
        String classId = '01p000000000005AAA';
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(
            buildSearchBody(classId, 'NoHttpMethods'),
            buildQueryBodyNoAnnotation(classId, 'NoHttpMethods')
        ));

        // When
        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> results = RestEndpointInspector.getRestEndpoints();
        Test.stopTest();

        // Then
        Assert.areEqual(0, results.size(), 'Classes with no HTTP verb annotations should be excluded');
    }

    // ── buildFullPath ──────────────────────────────────────────────────────────

    @isTest
    static void buildFullPath_PathTagAbsolute_ReturnedAsIs() {
        // Given
        RestEndpointInspector.MethodDescriptor md = new RestEndpointInspector.MethodDescriptor();
        md.pathTag = '/services/apexrest/custom/path';
        md.parameters = new List<RestEndpointInspector.MethodParameter>();

        // When
        Test.startTest();
        String result = RestEndpointInspector.buildFullPath('/myclass/*', md);
        Test.stopTest();

        // Then
        Assert.areEqual('/services/apexrest/custom/path', result, 'Absolute path tag should be returned unchanged');
    }

    @isTest
    static void buildFullPath_PathTagRelative_PrependedWithBase() {
        // Given
        RestEndpointInspector.MethodDescriptor md = new RestEndpointInspector.MethodDescriptor();
        md.pathTag = '/myendpoint';
        md.parameters = new List<RestEndpointInspector.MethodParameter>();

        // When
        Test.startTest();
        String result = RestEndpointInspector.buildFullPath('/myclass/*', md);
        Test.stopTest();

        // Then
        Assert.areEqual('/services/apexrest/myendpoint', result, 'Relative path tag should be prefixed with base');
    }

    @isTest
    static void buildFullPath_PathTagRelativeNoLeadingSlash_PrependedWithSlash() {
        // Given
        RestEndpointInspector.MethodDescriptor md = new RestEndpointInspector.MethodDescriptor();
        md.pathTag = 'noslash';
        md.parameters = new List<RestEndpointInspector.MethodParameter>();

        // When
        Test.startTest();
        String result = RestEndpointInspector.buildFullPath('/myclass/*', md);
        Test.stopTest();

        // Then
        Assert.areEqual('/services/apexrest/noslash', result, 'Path tag without leading slash should be prefixed correctly');
    }

    @isTest
    static void buildFullPath_NoPathTag_MappingWithWildcard_InjectsPathParams() {
        // Given
        RestEndpointInspector.MethodParameter pathParam = new RestEndpointInspector.MethodParameter();
        pathParam.name = 'recordId';
        pathParam.location = 'path';

        RestEndpointInspector.MethodDescriptor md = new RestEndpointInspector.MethodDescriptor();
        md.pathTag = null;
        md.parameters = new List<RestEndpointInspector.MethodParameter>{ pathParam };

        // When
        Test.startTest();
        String result = RestEndpointInspector.buildFullPath('/accounts/*', md);
        Test.stopTest();

        // Then
        Assert.areEqual('/services/apexrest/accounts/{recordId}', result,
            'Wildcard mapping should have path param injected');
    }

    @isTest
    static void buildFullPath_NoPathTag_MappingWithoutWildcard_UsedDirectly() {
        // Given
        RestEndpointInspector.MethodDescriptor md = new RestEndpointInspector.MethodDescriptor();
        md.pathTag = null;
        md.parameters = new List<RestEndpointInspector.MethodParameter>();

        // When
        Test.startTest();
        String result = RestEndpointInspector.buildFullPath('/contacts', md);
        Test.stopTest();

        // Then
        Assert.areEqual('/services/apexrest/contacts', result,
            'Static mapping without wildcard should be returned directly');
    }

    @isTest
    static void buildFullPath_NullClassMapping_ReturnsBase() {
        // Given
        RestEndpointInspector.MethodDescriptor md = new RestEndpointInspector.MethodDescriptor();
        md.pathTag = null;
        md.parameters = new List<RestEndpointInspector.MethodParameter>();

        // When
        Test.startTest();
        String result = RestEndpointInspector.buildFullPath(null, md);
        Test.stopTest();

        // Then
        Assert.areEqual('/services/apexrest', result, 'Null class mapping should return the base path');
    }

    @isTest
    static void buildFullPath_MappingAlreadyContainsBase_NotDoubled() {
        // Given
        RestEndpointInspector.MethodDescriptor md = new RestEndpointInspector.MethodDescriptor();
        md.pathTag = null;
        md.parameters = new List<RestEndpointInspector.MethodParameter>();

        // When
        Test.startTest();
        String result = RestEndpointInspector.buildFullPath('/services/apexrest/orders', md);
        Test.stopTest();

        // Then
        Assert.isFalse(result.startsWith('/services/apexrest/services/apexrest'),
            'Base path should not be doubled when mapping already contains it');
        Assert.areEqual('/services/apexrest/orders', result, 'Path should not duplicate base segment');
    }

    @isTest
    static void buildFullPath_PathTagEqualsBase_ReturnedAsIs() {
        // Given
        RestEndpointInspector.MethodDescriptor md = new RestEndpointInspector.MethodDescriptor();
        md.pathTag = '/services/apexrest';
        md.parameters = new List<RestEndpointInspector.MethodParameter>();

        // When
        Test.startTest();
        String result = RestEndpointInspector.buildFullPath('/anything', md);
        Test.stopTest();

        // Then
        Assert.areEqual('/services/apexrest', result, 'Path tag equal to base should be returned unchanged');
    }

    @isTest
    static void buildFullPath_NoPathTag_MultiplePathParams_AllInjected() {
        // Given
        RestEndpointInspector.MethodParameter p1 = new RestEndpointInspector.MethodParameter();
        p1.name = 'accountId';
        p1.location = 'path';

        RestEndpointInspector.MethodParameter p2 = new RestEndpointInspector.MethodParameter();
        p2.name = 'contactId';
        p2.location = 'path';

        RestEndpointInspector.MethodParameter p3 = new RestEndpointInspector.MethodParameter();
        p3.name = 'filter';
        p3.location = 'query';

        RestEndpointInspector.MethodDescriptor md = new RestEndpointInspector.MethodDescriptor();
        md.pathTag = null;
        md.parameters = new List<RestEndpointInspector.MethodParameter>{ p1, p2, p3 };

        // When
        Test.startTest();
        String result = RestEndpointInspector.buildFullPath('/resource/*', md);
        Test.stopTest();

        // Then
        Assert.isTrue(result.contains('{accountId}'), 'accountId path param should be injected');
        Assert.isTrue(result.contains('{contactId}'), 'contactId path param should be injected');
        Assert.isFalse(result.contains('{filter}'), 'Query params should not be injected into the path');
    }
}