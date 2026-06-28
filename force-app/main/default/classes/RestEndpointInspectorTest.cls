/**
 * RestEndpointInspectorTest
 *
 * Test coverage for RestEndpointInspector class.
 * Uses HttpCalloutMock to simulate Tooling API SOSL responses with SymbolTable data.
 */
@isTest
private class RestEndpointInspectorTest {

    /**
     * Mock response class for Tooling API SOSL search.
     */
    private class ToolingApiMock implements HttpCalloutMock {
        private String mockResponse;

        public ToolingApiMock(String mockResponse) {
            this.mockResponse = mockResponse;
        }

        public HttpResponse respond(HttpRequest request) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(mockResponse);
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        // No actual record creation needed for these tests
        // Tests use mocked HTTP responses
    }

    @isTest
    static void shouldParseAccountApiSymbolTable_WhenValidSearchResponse() {
        // Given: A mock Tooling API response with AccountApi SymbolTable
        String mockResponse = '{"searchRecords":[{"attributes":{"type":"ApexClass","url":"/services/data/v66.0/tooling/sobjects/ApexClass/01pg5000007BgsxAAC"},"Id":"01pg5000007BgsxAAC","Name":"AccountApi","SymbolTable":{"constructors":[],"externalReferences":[],"id":"AccountApi","innerClasses":[],"interfaces":[],"methods":[{"annotations":[{"name":"HttpGet"}],"location":{"column":27,"line":17},"modifiers":["static","global"],"name":"getAccount","parameters":[],"references":[],"returnType":"Account","type":null},{"annotations":[{"name":"TestVisible"}],"location":{"column":28,"line":71},"modifiers":["private","static"],"name":"isValidSalesforceId","parameters":[{"name":"candidateId","type":"String"}],"references":[],"returnType":"Boolean","type":null}],"name":"AccountApi","namespace":null,"parentClass":"","properties":[{"annotations":[],"location":{"column":33,"line":7},"modifiers":["private","static","final"],"name":"INVALID_ID_MESSAGE","references":[],"type":"String"}],"tableDeclaration":{"annotations":[{"name":"RestResource","value":"/account/v1/*"}],"location":{"column":27,"line":5},"modifiers":["global","with sharing"],"name":"AccountApi","references":[],"type":"AccountApi"},"variables":[]}}}]}';

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        // When
        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> descriptors = RestEndpointInspector.getRestEndpoints();
        Test.stopTest();

        // Then
        Assert.isNotNull(descriptors, 'Descriptors should not be null');
        Assert.areEqual(1, descriptors.size(), 'Should find exactly one endpoint');

        RestEndpointInspector.EndpointDescriptor ep = descriptors[0];
        Assert.areEqual('AccountApi', ep.className, 'Class name should match');
        Assert.areEqual('/account/v1/*', ep.urlPath, 'URL mapping should match RestResource value');
    }

    @isTest
    static void shouldExtractHttpMethods_WhenMultipleMethodsPresent() {
        // Given: A mock response with an @HttpGet method
        String mockResponse = '{"searchRecords":[{"attributes":{"type":"ApexClass"},"Id":"123","Name":"TestApi","SymbolTable":{"methods":[{"annotations":[{"name":"HttpGet"}],"name":"getRecord","returnType":"Object","modifiers":["global","static"],"parameters":[]},{"annotations":[],"name":"helper","returnType":"void","modifiers":["private"],"parameters":[]}],"tableDeclaration":{"annotations":[{"name":"RestResource","value":"/test/*"}],"modifiers":["global"]},"properties":[],"variables":[],"constructors":[]}}]}';

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        // When
        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> descriptors = RestEndpointInspector.getRestEndpoints();
        Test.stopTest();

        // Then
        Assert.areEqual(1, descriptors.size(), 'Should parse one endpoint');
        RestEndpointInspector.EndpointDescriptor ep = descriptors[0];
        Assert.isNotNull(ep.httpMethods, 'HTTP methods should not be null');
        Assert.areEqual(1, ep.httpMethods.size(), 'Should find one HTTP method');
        Assert.areEqual('getRecord', ep.httpMethods[0].name, 'Method name should match');
        Assert.areEqual('HttpGet', ep.httpMethods[0].annotations[0].name, 'Should have HttpGet annotation');
    }

    @isTest
    static void shouldExtractMethodParameters_WhenParametersPresent() {
        // Given: A method with parameters
        String mockResponse = '{"searchRecords":[{"attributes":{"type":"ApexClass"},"Id":"123","Name":"TestApi","SymbolTable":{"methods":[{"annotations":[{"name":"HttpPost"}],"name":"createRecord","returnType":"void","modifiers":["global","static"],"parameters":[{"name":"recordId","type":"String"},{"name":"data","type":"Object"}]}],"tableDeclaration":{"annotations":[{"name":"RestResource","value":"/create/*"}],"modifiers":["global"]}}}]}';

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        // When
        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> descriptors = RestEndpointInspector.getRestEndpoints();
        Test.stopTest();

        // Then
        RestEndpointInspector.MethodDescriptor method = descriptors[0].httpMethods[0];
        Assert.areEqual(2, method.parameters.size(), 'Should have two parameters');
        Assert.areEqual('recordId', method.parameters[0].name, 'First param name should match');
        Assert.areEqual('String', method.parameters[0].type, 'First param type should be String');
        Assert.areEqual('data', method.parameters[1].name, 'Second param name should match');
        Assert.areEqual('Object', method.parameters[1].type, 'Second param type should be Object');
    }

    @isTest
    static void shouldReturnEmptyList_WhenNoRestResourceFound() {
        // Given: A response with no @RestResource classes
        String mockResponse = '{"searchRecords":[]}';

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        // When
        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> descriptors = RestEndpointInspector.getRestEndpoints();
        Test.stopTest();

        // Then
        Assert.areEqual(0, descriptors.size(), 'Should return empty list when no records found');
    }


    @isTest
    static void shouldExtractMultipleHttpMethodsFromOneClass() {
        // Given: A REST endpoint with GET, POST, PUT, DELETE methods
        String mockResponse = '{"searchRecords":[{"attributes":{"type":"ApexClass"},"Id":"123","Name":"MultiMethodApi","SymbolTable":{"methods":[{"annotations":[{"name":"HttpGet"}],"name":"doGet","returnType":"Object","modifiers":["global"],"parameters":[]},{"annotations":[{"name":"HttpPost"}],"name":"doPost","returnType":"void","modifiers":["global"],"parameters":[]},{"annotations":[{"name":"HttpPut"}],"name":"doPut","returnType":"void","modifiers":["global"],"parameters":[]},{"annotations":[{"name":"HttpDelete"}],"name":"doDelete","returnType":"void","modifiers":["global"],"parameters":[]}],"tableDeclaration":{"annotations":[{"name":"RestResource","value":"/resource/*"}],"modifiers":["global"]}}}]}';

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        // When
        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> descriptors = RestEndpointInspector.getRestEndpoints();
        Test.stopTest();

        // Then
        RestEndpointInspector.EndpointDescriptor ep = descriptors[0];
        Assert.areEqual(4, ep.httpMethods.size(), 'Should find all four HTTP methods');
        List<String> methodNames = new List<String>();
        for (RestEndpointInspector.MethodDescriptor m : ep.httpMethods) {
            methodNames.add(m.name);
        }
        Assert.isTrue(methodNames.contains('doGet'), 'Should contain GET method');
        Assert.isTrue(methodNames.contains('doPost'), 'Should contain POST method');
        Assert.isTrue(methodNames.contains('doPut'), 'Should contain PUT method');
        Assert.isTrue(methodNames.contains('doDelete'), 'Should contain DELETE method');
    }
}