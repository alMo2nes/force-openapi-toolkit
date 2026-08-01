/**
 * EndpointConfigGeneratorTest
 *
 * Test coverage for EndpointConfigGenerator class.
 * Exercises OpenAPI and operation generation from mocked REST endpoint metadata.
 */
@isTest
private class EndpointConfigGeneratorTest {

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

    private static String buildSearchBody(String apexClassId, String apexClassName) {
        return JSON.serialize(new Map<String, Object>{
            'searchRecords' => new List<Object>{
                new Map<String, Object>{ 'Id' => apexClassId, 'Name' => apexClassName }
            }
        });
    }

    private static String buildQueryBody(String apexClassId, String apexClassName, String body, String symbolTableJson) {
        return JSON.serialize(new Map<String, Object>{
            'records' => new List<Object>{
                new Map<String, Object>{
                    'Id' => apexClassId,
                    'Name' => apexClassName,
                    'Body' => body,
                    'SymbolTable' => JSON.deserializeUntyped(symbolTableJson)
                }
            }
        });
    }

    @isTest
    static void generatePathsConfig_ReturnsPathOperations_WhenEndpointsAreDiscovered() {
        // Given
        String classId = '01p000000000001AAA';
        String className = 'AccountsResource';
        String apexBody = '@RestResource(urlMapping=\'/accounts/*\')\n'
            + 'public class AccountsResource {\n'
            + '    /**\n'
            + '     * @description Get an account\n'
            + '     * @param [required][path] {String} recordId Account Id\n'
            + '     */\n'
            + '    @HttpGet\n'
            + '    public static String doGet(String recordId) { return recordId; }\n'
            + '    /**\n'
            + '     * @description Create an account\n'
            + '     * @param [required] {String} name Account name\n'
            + '     */\n'
            + '    @HttpPost\n'
            + '    public static String doPost(String name) { return name; }\n'
            + '}';

        String symbolTableJson = JSON.serialize(new Map<String, Object>{
            'methods' => new List<Object>{
                new Map<String, Object>{
                    'name' => 'doGet',
                    'returnType' => 'String',
                    'location' => new Map<String, Object>{ 'line' => 8 },
                    'annotations' => new List<Object>{ new Map<String, Object>{ 'name' => 'HttpGet' } },
                    'parameters' => new List<Object>{ new Map<String, Object>{ 'name' => 'recordId', 'type' => 'String' } }
                },
                new Map<String, Object>{
                    'name' => 'doPost',
                    'returnType' => 'String',
                    'location' => new Map<String, Object>{ 'line' => 15 },
                    'annotations' => new List<Object>{ new Map<String, Object>{ 'name' => 'HttpPost' } },
                    'parameters' => new List<Object>{ new Map<String, Object>{ 'name' => 'name', 'type' => 'String' } }
                }
            }
        });

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(
            buildSearchBody(classId, className),
            buildQueryBody(classId, className, apexBody, symbolTableJson)
        ));

        // When
        Test.startTest();
        String result = EndpointConfigGenerator.generatePathsConfig();
        Test.stopTest();

        // Then
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(result);
        Assert.isTrue(parsed.containsKey('/services/apexrest/accounts/{recordId}'), 'GET path should be generated');
        Assert.isTrue(parsed.containsKey('/services/apexrest/accounts'), 'POST path should be generated');
    }

    @isTest
    static void getOperationSpec_ReturnsOperationMetadata_WhenClassAndMethodMatch() {
        // Given
        String classId = '01p000000000002AAA';
        String className = 'AccountsResource';
        String apexBody = '@RestResource(urlMapping=\'/accounts/*\')\n'
            + 'public class AccountsResource {\n'
            + '    /**\n'
            + '     * @description Get an account\n'
            + '     * @param [required][path] {String} recordId Account Id\n'
            + '     * @response 200 {String} Success\n'
            + '     */\n'
            + '    @HttpGet\n'
            + '    public static String doGet(String recordId) { return recordId; }\n'
            + '}';

        String symbolTableJson = JSON.serialize(new Map<String, Object>{
            'methods' => new List<Object>{
                new Map<String, Object>{
                    'name' => 'doGet',
                    'returnType' => 'String',
                    'location' => new Map<String, Object>{ 'line' => 8 },
                    'annotations' => new List<Object>{ new Map<String, Object>{ 'name' => 'HttpGet' } },
                    'parameters' => new List<Object>{ new Map<String, Object>{ 'name' => 'recordId', 'type' => 'String' } }
                }
            }
        });

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(
            buildSearchBody(classId, className),
            buildQueryBody(classId, className, apexBody, symbolTableJson)
        ));

        // When
        Test.startTest();
        Map<String, Object> operation = EndpointConfigGenerator.getOperationSpec(className, 'doGet');
        Test.stopTest();

        // Then
        Assert.isNotNull(operation, 'Operation metadata should be returned');
        Assert.areEqual(className + '_doGet', operation.get('operationId'), 'Operation ID should be based on class and method names');
        Assert.isTrue(operation.containsKey('parameters'), 'Operation should include parameters');
        Assert.isTrue(operation.containsKey('responses'), 'Operation should include responses');
    }

    @isTest
    static void getGeneratedPath_ReturnsFullPath_WithInjectedPathParameter() {
        // Given
        String classId = '01p000000000003AAA';
        String className = 'AccountsResource';
        String apexBody = '@RestResource(urlMapping=\'/accounts/*\')\n'
            + 'public class AccountsResource {\n'
            + '    /**\n'
            + '     * @description Get an account\n'
            + '     * @param [required][path] {String} recordId Account Id\n'
            + '     */\n'
            + '    @HttpGet\n'
            + '    public static String doGet(String recordId) { return recordId; }\n'
            + '}';

        String symbolTableJson = JSON.serialize(new Map<String, Object>{
            'methods' => new List<Object>{
                new Map<String, Object>{
                    'name' => 'doGet',
                    'returnType' => 'String',
                    'location' => new Map<String, Object>{ 'line' => 8 },
                    'annotations' => new List<Object>{ new Map<String, Object>{ 'name' => 'HttpGet' } },
                    'parameters' => new List<Object>{ new Map<String, Object>{ 'name' => 'recordId', 'type' => 'String' } }
                }
            }
        });

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(
            buildSearchBody(classId, className),
            buildQueryBody(classId, className, apexBody, symbolTableJson)
        ));

        // When
        Test.startTest();
        String path = EndpointConfigGenerator.getGeneratedPath(className, 'doGet');
        Test.stopTest();

        // Then
        Assert.areEqual('/services/apexrest/accounts/{recordId}', path, 'Wildcard mapping should include the injected path parameter');
    }

    @isTest
    static void generateOpenApiSpec_ReturnsOpenApiWrapper_WithPathsAndInfo() {
        // Given
        String classId = '01p000000000004AAA';
        String className = 'AccountsResource';
        String apexBody = '@RestResource(urlMapping=\'/accounts/*\')\n'
            + 'public class AccountsResource {\n'
            + '    /**\n'
            + '     * @description Get an account\n'
            + '     * @param [required][path] {String} recordId Account Id\n'
            + '     */\n'
            + '    @HttpGet\n'
            + '    public static String doGet(String recordId) { return recordId; }\n'
            + '}';

        String symbolTableJson = JSON.serialize(new Map<String, Object>{
            'methods' => new List<Object>{
                new Map<String, Object>{
                    'name' => 'doGet',
                    'returnType' => 'String',
                    'location' => new Map<String, Object>{ 'line' => 8 },
                    'annotations' => new List<Object>{ new Map<String, Object>{ 'name' => 'HttpGet' } },
                    'parameters' => new List<Object>{ new Map<String, Object>{ 'name' => 'recordId', 'type' => 'String' } }
                }
            }
        });

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(
            buildSearchBody(classId, className),
            buildQueryBody(classId, className, apexBody, symbolTableJson)
        ));

        // When
        Test.startTest();
        String specJson = EndpointConfigGenerator.generateOpenApiSpec();
        Test.stopTest();

        // Then
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(specJson);
        Assert.areEqual('3.0.0', spec.get('openapi'), 'OpenAPI version should be 3.0.0');
        Map<String, Object> info = (Map<String, Object>) spec.get('info');
        Assert.areEqual('Salesforce REST API', info.get('title'), 'OpenAPI title should be set');
        Map<String, Object> paths = (Map<String, Object>) spec.get('paths');
        Assert.isTrue(paths.containsKey('/services/apexrest/accounts/{recordId}'), 'OpenAPI paths should include the generated path');
    }
}