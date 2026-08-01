@IsTest
private class SwaggerUIControllerTest {

    @IsTest
    static void shouldGenerateValidJson_WhenControllerInitialized() {
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        Assert.isNotNull(controller.specJson, 'specJson should not be null');
        Assert.isTrue(controller.specJson.length() > 0, 'specJson should not be empty');
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Assert.isNotNull(spec, 'specJson should be valid JSON');
    }

    @IsTest
    static void shouldContainRequiredOpenApiTopLevelKeys_WhenSpecGenerated() {
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Assert.areEqual('3.0.3', spec.get('openapi'), 'OpenAPI version should be 3.0.3');
        Assert.isTrue(spec.containsKey('info'), 'Spec should contain info');
        Assert.isTrue(spec.containsKey('paths'), 'Spec should contain paths');
        Assert.isTrue(spec.containsKey('components'), 'Spec should contain components');
        Assert.isTrue(spec.containsKey('security'), 'Spec should contain security');
        Assert.isTrue(spec.containsKey('tags'), 'Spec should contain tags');
    }

    @IsTest
    static void shouldSetInfoTitleAndVersion_WhenSpecGenerated() {
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Map<String, Object> info = (Map<String, Object>) spec.get('info');
        Assert.isNotNull(info, 'Info section should not be null');
        Assert.areEqual('Salesforce API', info.get('title'), 'Info title should be Salesforce API');
        Assert.areEqual('1.0', info.get('version'), 'Info version should be 1.0');
    }

    @IsTest
    static void shouldIncludeBothSecuritySchemes_WhenSpecGenerated() {
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Map<String, Object> schemes = (Map<String, Object>)
            ((Map<String, Object>) spec.get('components')).get('securitySchemes');
        Assert.isNotNull(schemes, 'securitySchemes should not be null');
        Assert.isTrue(schemes.containsKey('BearerAuth'), 'Should include BearerAuth scheme');
        Assert.isTrue(schemes.containsKey('salesforce_oauth'), 'Should include salesforce_oauth scheme');
    }

    @IsTest
    static void shouldConfigureBearerAuthAsHttpBearer_WhenSpecGenerated() {
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Map<String, Object> bearerAuth = (Map<String, Object>)
            ((Map<String, Object>) ((Map<String, Object>) spec.get('components')).get('securitySchemes')).get('BearerAuth');
        Assert.areEqual('http', bearerAuth.get('type'), 'BearerAuth type should be http');
        Assert.areEqual('bearer', bearerAuth.get('scheme'), 'BearerAuth scheme should be bearer');
        Assert.areEqual('JWT', bearerAuth.get('bearerFormat'), 'BearerAuth bearerFormat should be JWT');
    }

    @IsTest
    static void shouldConfigureOAuthAuthorizationCodeFlow_WhenSpecGenerated() {
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Map<String, Object> oauth = (Map<String, Object>)
            ((Map<String, Object>) ((Map<String, Object>) spec.get('components')).get('securitySchemes')).get('salesforce_oauth');
        Assert.areEqual('oauth2', oauth.get('type'), 'salesforce_oauth type should be oauth2');
        Map<String, Object> flows = (Map<String, Object>) oauth.get('flows');
        Assert.isNotNull(flows, 'OAuth flows should not be null');
        Assert.isTrue(flows.containsKey('authorizationCode'), 'Should include authorizationCode flow');
    }

    @IsTest
    static void shouldIncludeTwoGlobalSecurityOptions_WhenSpecGenerated() {
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        List<Object> security = (List<Object>) spec.get('security');
        Assert.isNotNull(security, 'Security list should not be null');
        Assert.areEqual(2, security.size(), 'Should have 2 global security options');
    }

    @IsTest
    static void shouldSetOrgDomainWithHttpsScheme_WhenControllerInitialized() {
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        Assert.isNotNull(controller.orgDomain, 'orgDomain should not be null');
        Assert.isTrue(
            controller.orgDomain.startsWith('https://'),
            'orgDomain should start with https://, got: ' + controller.orgDomain
        );
    }

    @IsTest
    static void shouldSetIsGuestFalse_WhenRunAsAuthenticatedUser() {
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        Assert.areEqual(false, controller.isGuest, 'isGuest should be false for an authenticated test user');
    }

    @IsTest
    static void shouldExposeSpecJsonStartingAndEndingWithBraces_WhenPropertyAccessed() {
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        String jsonOutput = controller.specJson;
        Test.stopTest();

        Assert.isNotNull(jsonOutput, 'specJson property should be accessible');
        Assert.isTrue(jsonOutput.startsWith('{'), 'specJson should start with {');
        Assert.isTrue(jsonOutput.endsWith('}'), 'specJson should end with }');
    }

    @IsTest
    static void shouldMarkEndpointDeprecated_WhenDeprecatedFlagIsTrue() {
        // Relies on any deployed OpenApi_Endpoint__mdt record with Deprecated__c = true.
        // Validates the deprecated flag is propagated into the operation object when present.
        List<OpenApi_Endpoint__mdt> deprecatedRecords = [
            SELECT Path__c, Http_Method__c
            FROM OpenApi_Endpoint__mdt
            WHERE Active__c = TRUE AND Deprecated__c = TRUE
            LIMIT 1
        ];
        if (deprecatedRecords.isEmpty()) {
            return; // No deprecated CMT records deployed — skip rather than fail
        }

        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Map<String, Object> paths = (Map<String, Object>) spec.get('paths');
        String path = deprecatedRecords[0].Path__c;
        String method = deprecatedRecords[0].Http_Method__c.toLowerCase();
        Assert.isTrue(paths.containsKey(path), 'Spec paths should contain: ' + path);
        Map<String, Object> operation = (Map<String, Object>)
            ((Map<String, Object>) paths.get(path)).get(method);
        Assert.areEqual(true, operation.get('deprecated'), 'Operation should be marked deprecated');
    }

    @IsTest
    static void shouldTagOperationWithClassName_WhenEndpointHasClassName() {
        List<OpenApi_Endpoint__mdt> records = [
            SELECT Path__c, Http_Method__c, Class_Name__c
            FROM OpenApi_Endpoint__mdt
            WHERE Active__c = TRUE AND Class_Name__c != NULL
            LIMIT 1
        ];
        if (records.isEmpty()) {
            return;
        }

        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Map<String, Object> paths = (Map<String, Object>) spec.get('paths');
        String path = records[0].Path__c;
        String method = records[0].Http_Method__c.toLowerCase();
        Map<String, Object> operation = (Map<String, Object>)
            ((Map<String, Object>) paths.get(path)).get(method);
        List<Object> tags = (List<Object>) operation.get('tags');
        Assert.isNotNull(tags, 'Operation should have tags');
        Assert.isTrue(tags.contains(records[0].Class_Name__c),
            'Operation tags should include class name: ' + records[0].Class_Name__c);
    }
}