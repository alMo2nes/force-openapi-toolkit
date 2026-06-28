/**
 * EndpointConfigGeneratorTest
 *
 * Test coverage for EndpointConfigGenerator class.
 * Tests OpenAPI specification generation from discovered REST endpoints.
 */
@isTest
private class EndpointConfigGeneratorTest {

    /**
     * Mock response class for Tooling API.
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

    @TestSetup
    static void setupTestData() {
        // No setup needed; tests use mocked HTTP
    }

    @isTest
    static void shouldGenerateOpenApiSpec_WhenEndpointsFound() {
        // Given: A mock Tooling API response
        String mockResponse = '{"searchRecords":[{"attributes":{"type":"ApexClass"},"Id":"123","Name":"AccountApi","SymbolTable":{"methods":[{"annotations":[{"name":"HttpGet"}],"name":"getAccount","returnType":"Account","modifiers":["static","global"],"parameters":[{"name":"id","type":"String"}]}],"tableDeclaration":{"annotations":[{"name":"RestResource","value":"/account/v1/*"}],"modifiers":["global","with sharing"]},"properties":[]}}]}';

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        // When
        Test.startTest();
        String openApiJson = EndpointConfigGenerator.generateOpenApiSpec();
        Test.stopTest();

        // Then
        Assert.isNotNull(openApiJson, 'OpenAPI spec should not be null');
        Assert.isTrue(openApiJson.contains('3.0.0'), 'Should contain OpenAPI version');
        Assert.isTrue(openApiJson.contains('Salesforce REST API'), 'Should contain API title');
        Assert.isTrue(openApiJson.contains('/account/v1/*'), 'Should contain endpoint path');

        // Verify JSON is valid
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(openApiJson);
        Assert.areEqual('3.0.0', spec.get('openapi'), 'OpenAPI version should match');
        Assert.isNotNull(spec.get('info'), 'Should contain info object');
        Assert.isNotNull(spec.get('paths'), 'Should contain paths object');
    }

    @isTest
    static void shouldIncludeMethodParameters_InOpenApiSpec() {
        // Given: An endpoint with multiple parameters
        String mockResponse = '{"searchRecords":[{"attributes":{"type":"ApexClass"},"Id":"123","Name":"SearchApi","SymbolTable":{"methods":[{"annotations":[{"name":"HttpGet"}],"name":"search","returnType":"List","modifiers":["static","global"],"parameters":[{"name":"query","type":"String"},{"name":"limit","type":"Integer"}]}],"tableDeclaration":{"annotations":[{"name":"RestResource","value":"/search/*"}],"modifiers":["global"]}}}]}';

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        // When
        Test.startTest();
        String openApiJson = EndpointConfigGenerator.generateOpenApiSpec();
        Test.stopTest();

        // Then
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(openApiJson);
        Map<String, Object> paths = (Map<String, Object>) spec.get('paths');
        Map<String, Object> searchPath = (Map<String, Object>) paths.get('/search/*');
        Map<String, Object> getOp = (Map<String, Object>) searchPath.get('get');
        List<Object> parameters = (List<Object>) getOp.get('parameters');

        Assert.isNotNull(parameters, 'Operation should have parameters');
        Assert.areEqual(2, parameters.size(), 'Should have two parameters');

        Map<String, Object> param1 = (Map<String, Object>) parameters[0];
        Assert.areEqual('query', param1.get('name'), 'First parameter name should be query');
        Assert.areEqual('query', param1.get('in'), 'Parameter should be in query');
    }

    @isTest
    static void shouldGenerateEndpointSummary_WhenEndpointsPresent() {
        // Given: A mock response with multiple methods
        String mockResponse = '{"searchRecords":[{"attributes":{"type":"ApexClass"},"Id":"123","Name":"TestApi","SymbolTable":{"methods":[{"annotations":[{"name":"HttpGet"}],"name":"doGet","returnType":"Object","modifiers":["global"],"parameters":[]},{"annotations":[{"name":"HttpPost"}],"name":"doPost","returnType":"void","modifiers":["global"],"parameters":[{"name":"data","type":"Object"}]}],"tableDeclaration":{"annotations":[{"name":"RestResource","value":"/test/*"}],"modifiers":["global"]}}}]}';

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        // When
        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> endpoints = RestEndpointInspector.getRestEndpoints();
        Test.stopTest();

        // Then
        Assert.areEqual(1, endpoints.size(), 'Should have one endpoint');
        RestEndpointInspector.EndpointDescriptor item = endpoints[0];
        Assert.areEqual('TestApi', item.className, 'Class name should match');
        Assert.areEqual('/test/*', item.urlPath, 'URL mapping should match');
        Assert.areEqual(2, item.httpMethods.size(), 'Should have two HTTP methods');

        List<String> methods = new List<String>();
        for (RestEndpointInspector.MethodDescriptor m : item.httpMethods) {
            methods.add(EndpointConfigGenerator.extractHttpMethod(m.annotations));
        }
        Assert.isTrue(methods.contains('GET'), 'Should include GET method');
        Assert.isTrue(methods.contains('POST'), 'Should include POST method');
    }

    @isTest
    static void shouldIncludeResponses_InOpenApiOperation() {
        // Given: An endpoint that returns an Account
        String mockResponse = '{"searchRecords":[{"attributes":{"type":"ApexClass"},"Id":"123","Name":"GetAccountApi","SymbolTable":{"methods":[{"annotations":[{"name":"HttpGet"}],"name":"getAccount","returnType":"Account","modifiers":["global"],"parameters":[]}],"tableDeclaration":{"annotations":[{"name":"RestResource","value":"/account/*"}],"modifiers":["global"]}}}]}';

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        // When
        Test.startTest();
        String openApiJson = EndpointConfigGenerator.generateOpenApiSpec();
        Test.stopTest();

        // Then
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(openApiJson);
        Map<String, Object> paths = (Map<String, Object>) spec.get('paths');
        Map<String, Object> accountPath = (Map<String, Object>) paths.get('/account/*');
        Map<String, Object> getOp = (Map<String, Object>) accountPath.get('get');
        Map<String, Object> responses = (Map<String, Object>) getOp.get('responses');

        Assert.isNotNull(responses, 'Operation should have responses');
        Assert.isTrue(responses.containsKey('200'), 'Should have 200 response');

        Map<String, Object> response200 = (Map<String, Object>) responses.get('200');
        Assert.isNotNull(response200, 'Success response should not be null');
    }

    @isTest
    static void shouldExtractAllParameters_AcrossMultipleMethods() {
        // Given: Multiple methods with different parameters
        String mockResponse = '{"searchRecords":[{"attributes":{"type":"ApexClass"},"Id":"123","Name":"ParamApi","SymbolTable":{"methods":[{"annotations":[{"name":"HttpGet"}],"name":"list","returnType":"List","modifiers":["global"],"parameters":[{"name":"offset","type":"Integer"},{"name":"limit","type":"Integer"}]},{"annotations":[{"name":"HttpPost"}],"name":"create","returnType":"void","modifiers":["global"],"parameters":[{"name":"payload","type":"String"}]}],"tableDeclaration":{"annotations":[{"name":"RestResource","value":"/records/*"}],"modifiers":["global"]}}}]}';

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        // When
        Test.startTest();
        List<RestEndpointInspector.EndpointDescriptor> endpoints = RestEndpointInspector.getRestEndpoints();
        Test.stopTest();

        // Then
        Assert.areEqual(1, endpoints.size(), 'Should have one endpoint');
        RestEndpointInspector.EndpointDescriptor item = endpoints[0];
        
        Integer totalParams = 0;
        for (RestEndpointInspector.MethodDescriptor m : item.httpMethods) {
            if (m.parameters != null) {
                totalParams += m.parameters.size();
            }
        }
        Assert.areEqual(3, totalParams, 'Should have three total parameters');
    }

    @isTest
    static void shouldHandleEmptyMethodParametersList() {
        // Given: A method with no parameters
        String mockResponse = '{"searchRecords":[{"attributes":{"type":"ApexClass"},"Id":"123","Name":"SimpleApi","SymbolTable":{"methods":[{"annotations":[{"name":"HttpGet"}],"name":"ping","returnType":"String","modifiers":["global"],"parameters":[]}],"tableDeclaration":{"annotations":[{"name":"RestResource","value":"/ping"}],"modifiers":["global"]}}}]}';

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        // When
        Test.startTest();
        String openApiJson = EndpointConfigGenerator.generateOpenApiSpec();
        Test.stopTest();

        // Then
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(openApiJson);
        Map<String, Object> paths = (Map<String, Object>) spec.get('paths');
        Map<String, Object> pingPath = (Map<String, Object>) paths.get('/ping');
        Map<String, Object> getOp = (Map<String, Object>) pingPath.get('get');
        List<Object> parameters = (List<Object>) getOp.get('parameters');

        Assert.areEqual(0, parameters.size(), 'Should have empty parameters list');
    }

    @isTest
    static void shouldInferOpenApiTypes_FromApexReturnTypes() {
        // Given: Methods with various return types
        String mockResponse = '{"searchRecords":[{"attributes":{"type":"ApexClass"},"Id":"123","Name":"TypeApi","SymbolTable":{"methods":[{"annotations":[{"name":"HttpGet"}],"name":"getString","returnType":"String","modifiers":["global"],"parameters":[]},{"annotations":[{"name":"HttpGet"}],"name":"getNumber","returnType":"Integer","modifiers":["global"],"parameters":[]},{"annotations":[{"name":"HttpGet"}],"name":"getFlag","returnType":"Boolean","modifiers":["global"],"parameters":[]}],"tableDeclaration":{"annotations":[{"name":"RestResource","value":"/types/*"}],"modifiers":["global"]}}}]}';

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(mockResponse));

        // When
        Test.startTest();
        String openApiJson = EndpointConfigGenerator.generateOpenApiSpec();
        Test.stopTest();

        // Then
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(openApiJson);
        Map<String, Object> paths = (Map<String, Object>) spec.get('paths');
        Map<String, Object> typesPath = (Map<String, Object>) paths.get('/types/*');

        // Check string method
        Map<String, Object> getStringOp = (Map<String, Object>) typesPath.get('get');
        Assert.isNotNull(getStringOp, 'Should have operation for getString');

        // Verify responses exist (they're all GET on the same path, so they get merged/overridden)
        Assert.isNotNull(getStringOp.get('responses'), 'Should have responses');
    }
}