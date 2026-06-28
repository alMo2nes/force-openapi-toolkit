/**
 * OpenApiManagerControllerTest
 *
 * Test coverage for OpenApiManagerController class.
 */
@isTest
private class OpenApiManagerControllerTest {

    private class ToolingApiMock implements HttpCalloutMock {
        private String mockResponse;

        public ToolingApiMock(String mockResponse) {
            this.mockResponse = mockResponse;
        }

        public HttpResponse respond(HttpRequest request) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            if (request.getEndpoint().contains('/tooling/query/')) {
                Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(mockResponse);
                List<Object> searchRecords = (List<Object>) bodyMap.get('searchRecords');
                List<Object> records = new List<Object>();
                if (searchRecords != null) {
                    for (Object sr : searchRecords) {
                        Map<String, Object> srMap = (Map<String, Object>) sr;
                        Map<String, Object> symbolTable = (Map<String, Object>) srMap.get('SymbolTable');
                        if (symbolTable != null) {
                            Map<String, Object> tableDecl = (Map<String, Object>) symbolTable.get('tableDeclaration');
                            if (tableDecl != null) {
                                List<Object> annotations = (List<Object>) tableDecl.get('annotations');
                                if (annotations != null && !annotations.isEmpty()) {
                                    String val = (String) ((Map<String, Object>) annotations[0]).get('value');
                                    srMap.put('Body', '@RestResource(urlMapping=\'' + val + '\')\nglobal class ' + srMap.get('Name') + ' {}');
                                }
                            }
                        }
                        records.add(srMap);
                    }
                }
                res.setBody(JSON.serialize(new Map<String, Object>{'records' => records}));
            } else {
                res.setBody(mockResponse);
            }
            return res;
        }
    }

    private class DeploymentStatusMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public DeploymentStatusMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest request) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            return res;
        }
    }

    @isTest
    static void testGetDiscoveredEndpoints() {
        String mockResponse = '{"searchRecords":[{"attributes":{"type":"ApexClass"},"Id":"123","Name":"TestApi","SymbolTable":{"methods":[{"annotations":[{"name":"HttpGet"}],"name":"doGet","returnType":"Object","modifiers":["global"],"parameters":[]}],"tableDeclaration":{"annotations":[{"name":"RestResource","value":"/test/*"}],"modifiers":["global"]}}}]}';
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> endpoints = OpenApiManagerController.getDiscoveredEndpoints();
        Test.stopTest();

        Assert.isNotNull(endpoints, 'Endpoints list should not be null');
        Assert.areEqual(1, endpoints.size(), 'Should discover exactly one endpoint');
    }

    @isTest
    static void testGetSidebarItems() {
        String mockResponse = '{"searchRecords":[{"attributes":{"type":"ApexClass"},"Id":"123","Name":"TestApi","SymbolTable":{"methods":[{"annotations":[{"name":"HttpGet"}],"name":"doGet","returnType":"Object","modifiers":["global"],"parameters":[]}],"tableDeclaration":{"annotations":[{"name":"RestResource","value":"/test/*"}],"modifiers":["global"]}}}]}';
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        Test.startTest();
        List<OpenApiManagerController.SidebarItem> items = OpenApiManagerController.getSidebarItems();
        Test.stopTest();

        Assert.isNotNull(items, 'Sidebar items should not be null');
        Assert.areEqual(1, items.size(), 'Should have one sidebar item from discovered endpoints');
        Assert.areEqual('TestApi', items[0].className, 'Sidebar item class should match the discovered endpoint');
    }

    @isTest
    static void testGetConfigsForClass() {
        String mockResponse = '{"searchRecords":[{"attributes":{"type":"ApexClass"},"Id":"123","Name":"TestApi","SymbolTable":{"methods":[{"annotations":[{"name":"HttpGet"}],"name":"doGet","returnType":"Object","modifiers":["global"],"parameters":[]}],"tableDeclaration":{"annotations":[{"name":"RestResource","value":"/test/*"}],"modifiers":["global"]}}}]}';
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        Test.startTest();
        List<OpenApiManagerController.ConfigComparison> configs = OpenApiManagerController.getConfigsForClass('TestApi');
        Test.stopTest();

        Assert.isNotNull(configs, 'Configs should not be null');
        Assert.areEqual(1, configs.size(), 'Should have one configuration');
        Assert.areEqual('TestApi', configs[0].className, 'Class name should match');
        Assert.areEqual('doGet', configs[0].methodName, 'Method name should match');
    }

    @isTest
    static void testGetConfigsForClassWithBlankClassName() {
        Test.startTest();
        List<OpenApiManagerController.ConfigComparison> configs = OpenApiManagerController.getConfigsForClass('');
        Test.stopTest();

        Assert.areEqual(0, configs.size(), 'Blank class names should return no configurations');
    }

    @isTest
    static void testSaveConfigs() {
        OpenApiManagerController.ConfigComparison rec = new OpenApiManagerController.ConfigComparison();
        rec.className = 'TestApi';
        rec.methodName = 'doGet';
        rec.httpMethod = 'GET';
        rec.currentPath = '/services/apexrest/test';
        rec.currentSpec = '{}';
        rec.currentVersion = '1.0';
        rec.currentActive = true;
        rec.currentDeprecated = false;

        List<String> jsonConfigs = new List<String>{ JSON.serialize(rec) };

        Test.startTest();
        String jobId = OpenApiManagerController.saveConfigs(jsonConfigs);
        Test.stopTest();

        Assert.areEqual('test-job-id', jobId, 'Test context should return a deterministic job id');
    }

    @isTest
    static void testSaveConfigsRejectsInvalidJsonSpec() {
        OpenApiManagerController.ConfigComparison rec = new OpenApiManagerController.ConfigComparison();
        rec.className = 'TestApi';
        rec.methodName = 'doGet';
        rec.httpMethod = 'GET';
        rec.currentPath = '/services/apexrest/test';
        rec.currentSpec = '{invalid';
        rec.currentVersion = '1.0';
        rec.currentActive = true;
        rec.currentDeprecated = false;

        Test.startTest();
        try {
            OpenApiManagerController.saveConfigs(new List<String>{ JSON.serialize(rec) });
            Assert.fail('Expected invalid JSON specs to be rejected');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Invalid JSON should raise an AuraHandledException');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveConfigsRejectsBlankVersion() {
        OpenApiManagerController.ConfigComparison rec = new OpenApiManagerController.ConfigComparison();
        rec.className = 'TestApi';
        rec.methodName = 'doGet';
        rec.httpMethod = 'GET';
        rec.currentPath = '/services/apexrest/test';
        rec.currentSpec = '{}';
        rec.currentVersion = ' ';
        rec.currentActive = true;
        rec.currentDeprecated = false;

        Test.startTest();
        try {
            OpenApiManagerController.saveConfigs(new List<String>{ JSON.serialize(rec) });
            Assert.fail('Expected blank versions to be rejected');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Blank versions should raise an AuraHandledException');
        }
        Test.stopTest();
    }

    @isTest
    static void testCheckDeploymentStatusRejectsInvalidJobId() {
        Test.startTest();
        try {
            OpenApiManagerController.checkDeploymentStatus('not-a-salesforce-id');
            Assert.fail('Expected invalid deployment job IDs to be rejected');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Invalid deployment IDs should raise an AuraHandledException');
        }
        Test.stopTest();
    }

    @isTest
    static void testCheckDeploymentStatusReturnsStatus() {
        Test.setMock(HttpCalloutMock.class, new DeploymentStatusMock(200, '{"records":[{"Status":"Succeeded"}]}'));

        Test.startTest();
        String status = OpenApiManagerController.checkDeploymentStatus(UserInfo.getUserId());
        Test.stopTest();

        Assert.areEqual('Succeeded', status, 'Status should come from the DeployRequest response');
    }

    @isTest
    static void testCheckDeploymentStatusReturnsPendingWhenNoRecordFound() {
        Test.setMock(HttpCalloutMock.class, new DeploymentStatusMock(200, '{"records":[]}'));

        Test.startTest();
        String status = OpenApiManagerController.checkDeploymentStatus(UserInfo.getUserId());
        Test.stopTest();

        Assert.areEqual('Pending', status, 'Missing DeployRequest records should be treated as pending');
    }

    @isTest
    static void testCheckDeploymentStatusReturnsErrorWhenCalloutFails() {
        Test.setMock(HttpCalloutMock.class, new DeploymentStatusMock(500, '{"message":"failure"}'));

        Test.startTest();
        String status = OpenApiManagerController.checkDeploymentStatus(UserInfo.getUserId());
        Test.stopTest();

        Assert.areEqual('Error', status, 'Non-successful Tooling API responses should return Error');
    }
}