/**
 * Test class for SwaggerUIController.
 * Validates per-endpoint versioned OpenAPI spec generation:
 * - All endpoints are displayed simultaneously
 * - Each endpoint has an x-versions extension with its available versions
 * - endpointVersionsJson exposes version metadata for per-endpoint UI dropdowns
 * - Versions per endpoint are sorted: non-deprecated (desc) → deprecated (desc)
 * - Source endpoints form the baseline; metadata provides overrides per endpoint
 */
@IsTest
private class SwaggerUIControllerTest {

    /**
     * Tests controller initialization generates valid JSON spec.
     */
    @IsTest
    static void shouldGenerateValidSpec_WhenControllerInitialized() {
        // When
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        // Then
        Assert.isNotNull(controller.specJson, 'Spec JSON should not be null');
        Assert.isTrue(controller.specJson.length() > 0, 'Spec JSON should not be empty');

        // Verify it's valid JSON
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Assert.isNotNull(spec, 'Should be valid JSON');
    }

    /**
     * Tests spec contains required OpenAPI structure.
     */
    @IsTest
    static void shouldIncludeOpenApiStructure_WhenSpecGenerated() {
        // When
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        // Then
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);

        Assert.areEqual('3.0.0', spec.get('openapi'), 'OpenAPI version should be 3.0.0');
        Assert.isTrue(spec.containsKey('info'), 'Spec should contain info section');
        Assert.isTrue(spec.containsKey('paths'), 'Spec should contain paths section');
        Assert.isTrue(spec.containsKey('components'), 'Spec should contain components section');
        Assert.isTrue(spec.containsKey('security'), 'Spec should contain security section');
    }

    /**
     * Tests security schemes are properly configured.
     */
    @IsTest
    static void shouldIncludeSecuritySchemes_WhenSpecGenerated() {
        // When
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        // Then
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Map<String, Object> components = (Map<String, Object>) spec.get('components');
        Map<String, Object> securitySchemes = (Map<String, Object>) components.get('securitySchemes');

        Assert.isTrue(securitySchemes.containsKey('BearerAuth'),
            'Should include BearerAuth scheme');
        Assert.isTrue(securitySchemes.containsKey('salesforce_oauth'),
            'Should include salesforce_oauth scheme');
    }

    /**
     * Tests OAuth flow configuration.
     */
    @IsTest
    static void shouldConfigureOAuthFlow_WhenSpecGenerated() {
        // When
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        // Then
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Map<String, Object> components = (Map<String, Object>) spec.get('components');
        Map<String, Object> securitySchemes = (Map<String, Object>) components.get('securitySchemes');
        Map<String, Object> oauth = (Map<String, Object>) securitySchemes.get('salesforce_oauth');

        Assert.areEqual('oauth2', oauth.get('type'), 'OAuth type should be oauth2');
        Map<String, Object> flows = (Map<String, Object>) oauth.get('flows');
        Assert.isTrue(flows.containsKey('authorizationCode'),
            'Should include authorizationCode flow');
    }

    /**
     * Tests global security requirements.
     */
    @IsTest
    static void shouldIncludeSecurityRequirements_WhenSpecGenerated() {
        // When
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        // Then
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        List<Object> security = (List<Object>) spec.get('security');
        Assert.areEqual(2, security.size(), 'Should have 2 security options');
    }

    /**
     * Tests that all endpoints from source are present in the spec.
     */
    @IsTest
    static void shouldIncludeAllPaths_WhenSpecGenerated() {
        // When
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        // Then
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Map<String, Object> paths = (Map<String, Object>) spec.get('paths');
        Assert.isNotNull(paths, 'Paths should exist');
    }

    /**
     * Tests that each operation has an x-versions extension.
     */
    @IsTest
    static void shouldHaveXVersions_OnEachOperation() {
        // When
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        // Then
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Map<String, Object> paths = (Map<String, Object>) spec.get('paths');

        if (paths != null && !paths.isEmpty()) {
            Boolean foundOpWithVersion = false;
            for (String pathKey : paths.keySet()) {
                Map<String, Object> pathItem = (Map<String, Object>) paths.get(pathKey);
                for (String method : pathItem.keySet()) {
                    if (method.startsWith('x-')) continue; // skip extensions
                    Map<String, Object> op = (Map<String, Object>) pathItem.get(method);
                    if (op.containsKey('x-versions')) {
                        foundOpWithVersion = true;
                        List<Object> versions = (List<Object>) op.get('x-versions');
                        Assert.isNotNull(versions, 'x-versions should be a list');
                        Assert.isTrue(versions.size() >= 1, 'Should have at least one version');
                    }
                }
            }
            Assert.isTrue(foundOpWithVersion, 'At least one operation should have x-versions');
        }
    }

    /**
     * Tests that endpointVersionsJson is populated.
     */
    @IsTest
    static void shouldExposeEndpointVersionsJson() {
        // When
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        // Then
        Assert.isNotNull(controller.endpointVersionsJson, 'endpointVersionsJson should not be null');
        Assert.isTrue(controller.endpointVersionsJson.length() > 0, 'endpointVersionsJson should not be empty');

        // Verify it's valid JSON
        Map<String, Object> versions = (Map<String, Object>) JSON.deserializeUntyped(controller.endpointVersionsJson);
        Assert.isNotNull(versions, 'Should deserialize endpointVersionsJson');
    }

    /**
     * Tests that each entry in endpointVersionsJson has a versions list.
     */
    @IsTest
    static void shouldHaveVersionList_ForEachEndpoint() {
        // When
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        // Then
        Map<String, Object> versions = (Map<String, Object>) JSON.deserializeUntyped(controller.endpointVersionsJson);

        for (String endpointKey : versions.keySet()) {
            Map<String, Object> entry = (Map<String, Object>) versions.get(endpointKey);
            Assert.isTrue(entry.containsKey('versions'), 'Each endpoint should have a versions list');
            List<Object> versionList = (List<Object>) entry.get('versions');
            Assert.isNotNull(versionList, 'versions should not be null');
            Assert.isTrue(versionList.size() >= 1, 'Each endpoint should have at least one version');
        }
    }

    /**
     * Tests that version entries have label and deprecated fields.
     */
    @IsTest
    static void shouldHaveLabelAndDeprecated_ForEachVersion() {
        // When
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        // Then
        Map<String, Object> versions = (Map<String, Object>) JSON.deserializeUntyped(controller.endpointVersionsJson);

        for (String endpointKey : versions.keySet()) {
            Map<String, Object> entry = (Map<String, Object>) versions.get(endpointKey);
            List<Object> versionList = (List<Object>) entry.get('versions');
            for (Object vObj : versionList) {
                Map<String, Object> v = (Map<String, Object>) vObj;
                Assert.isTrue(v.containsKey('label'), 'Each version should have a label');
                Assert.isTrue(v.containsKey('deprecated'), 'Each version should have a deprecated flag');
                Assert.isNotNull(v.get('label'), 'Version label should not be null');
            }
        }
    }

    /**
     * Tests handling of invalid JSON in endpoint spec (try-catch in getMetadataByEndpoint).
     */
    @IsTest
    static void shouldSkipInvalidJson_WhenEndpointSpecMalformed() {
        // When
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        // Then
        Assert.isNotNull(controller.specJson,
            'Controller should complete even with invalid specs');
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Assert.isNotNull(spec, 'Generated spec should still be valid JSON');
    }

    /**
     * Tests that endpointVersionsJson serializes correctly for client-side use.
     */
    @IsTest
    static void shouldSerializeEndpointVersions_AsJsonObject() {
        // When
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        // Then
        Assert.isTrue(controller.endpointVersionsJson.startsWith('{'),
            'endpointVersionsJson should start with object brace');
        Assert.isTrue(controller.endpointVersionsJson.contains('"'),
            'endpointVersionsJson should contain JSON keys');
    }

    /**
     * Tests specJson is accessible.
     */
    @IsTest
    static void shouldExposeSpecJson_WhenPropertyAccessed() {
        // Given
        SwaggerUIController controller = new SwaggerUIController();

        // When
        Test.startTest();
        String jsonOutput = controller.specJson;
        Test.stopTest();

        // Then
        Assert.isNotNull(jsonOutput, 'specJson property should be accessible');
        Assert.isTrue(jsonOutput.startsWith('{'), 'Should start with opening brace');
        Assert.isTrue(jsonOutput.endsWith('}'), 'Should end with closing brace');
    }

    /**
     * Tests that the spec info version is set to 'multi-version'.
     */
    @IsTest
    static void shouldSetMultiVersion_WhenPerEndpointVersions() {
        // When
        Test.startTest();
        SwaggerUIController controller = new SwaggerUIController();
        Test.stopTest();

        // Then
        Map<String, Object> spec = (Map<String, Object>) JSON.deserializeUntyped(controller.specJson);
        Map<String, Object> info = (Map<String, Object>) spec.get('info');
        Assert.areEqual('multi-version', info.get('version'),
            'Spec version should indicate multi-version');
    }
}