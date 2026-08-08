public with sharing class SwaggerUIController {
    public String specJson { get; private set; }
    public String orgDomain { get; private set; }
    public String sessionToken { get; private set; }
    public Boolean isGuest { get; private set; }

    public SwaggerUIController() {

        // Determine guest status first so generateSpec() can use it.
        try {
            Boolean guest = UserInfo.getUserType() == 'Guest';
            isGuest = guest;
            sessionToken = guest ? '' : UserInfo.getSessionId();
        } catch (Exception e) {
            isGuest = false;
            sessionToken = '';
        }

        // Determine guest status first so generateSpec() can use it.
        try {
            Boolean guest = UserInfo.getUserType() == 'Guest';
            isGuest = guest;
            sessionToken = guest ? '' : UserInfo.getSessionId();
        } catch (Exception e) {
            isGuest = false;
            sessionToken = '';
        }

        specJson = JSON.serialize(generateSpec());

        // Ensure essential top-level keys exist even if generateSpec produced partial output
        try {
            Map<String, Object> specMap = (Map<String, Object>) JSON.deserializeUntyped(specJson);
            if (specMap == null) specMap = new Map<String, Object>();
            if (!specMap.containsKey('paths')) specMap.put('paths', new Map<String, Object>());
            if (!specMap.containsKey('tags')) specMap.put('tags', new List<Object>());
            // Ensure components.securitySchemes has the expected entries
            Map<String, Object> components = (Map<String, Object>) specMap.get('components');
            if (components == null) {
                components = new Map<String, Object>();
            }
            Map<String, Object> schemes = (Map<String, Object>) components.get('securitySchemes');
            if (schemes == null) {
                schemes = new Map<String, Object>();
            }
            if (!schemes.containsKey('BearerAuth')) {
                schemes.put('BearerAuth', new Map<String, Object>{
                        'type' => 'http', 'scheme' => 'bearer', 'bearerFormat' => 'JWT'
                });
            }
            if (!schemes.containsKey('salesforce_oauth')) {
                schemes.put(
                        'salesforce_oauth',
                        new Map<String, Object>{
                                'type' => 'oauth2',
                                'flows' => new Map<String, Object>{
                                        'authorizationCode' => new Map<String, Object>{
                                                'authorizationUrl' => 'https://login.salesforce.com/services/oauth2/authorize',
                                                'tokenUrl' => 'https://login.salesforce.com/services/oauth2/token',
                                                'scopes' => new Map<String, Object>{
                                                        'api' => 'Access API'
                                                }
                                        }
                                }
                        }
                );
            }
            components.put('securitySchemes', schemes);
            specMap.put('components', components);

            // Ensure global security array exists with both entries
            List<Object> securityList = (List<Object>) specMap.get('security');
            if (securityList == null) {
                securityList = new List<Object>();
            }
            Boolean hasBearer = false;
            Boolean hasOauth = false;
            for (Object o : securityList) {
                if (o instanceof Map<String, Object>) {
                    Map<String, Object> m = (Map<String, Object>) o;
                    if (m.containsKey('BearerAuth')) hasBearer = true;
                    if (m.containsKey('salesforce_oauth')) hasOauth = true;
                }
            }
            if (!hasBearer) securityList.add(new Map<String, Object>{
                    'BearerAuth' => new List<String>()
            });
            if (!hasOauth) securityList.add(new Map<String, Object>{
                    'salesforce_oauth' => new List<String>{
                            'api'
                    }
            });
            specMap.put('security', securityList);

            specJson = JSON.serialize(specMap);
        } catch (Exception e) {
            // If any error occurs while normalizing, fall back to the original serialized string
        }

        try {
            String host = System.DomainCreator.getOrgMyDomainHostname();
            orgDomain = (host != null &&
                    host.trim().length() > 0)
                    ? 'https://' + host
                    : 'https://login.salesforce.com';
        } catch (Exception e) {
            orgDomain = 'https://login.salesforce.com';
        }
    }

    private Map<String, Object> generateSpec() {
        Map<String, Object> spec = new Map<String, Object>();
        Map<String, Object> paths = new Map<String, Object>();

        List<OpenApi_Endpoint__mdt> records = [
                SELECT
                        Path__c,
                        Http_Method__c,
                        Spec__c,
                        Active__c,
                        Deprecated__c,
                        Class_Name__c,
                        Method_Name__c,
                        Auto_Sync_Spec__c
                FROM OpenApi_Endpoint__mdt
                WHERE Active__c = TRUE
                ORDER BY Class_Name__c, Path__c, Http_Method__c
        ];

        Set<String> classNames = new Set<String>();

        for (OpenApi_Endpoint__mdt rec : records) {
            if (String.isNotBlank(rec.Class_Name__c)) {
                classNames.add(rec.Class_Name__c);
            }

            String specToUse = rec.Spec__c;
            String path = rec.Path__c;

            if (
                    rec.Auto_Sync_Spec__c &&
                            !isGuest &&
                            String.isNotBlank(rec.Method_Name__c)
            ) {
                Map<String, Object> generatedOp = EndpointConfigGenerator.getOperationSpec(
                        rec.Class_Name__c,
                        rec.Method_Name__c
                );
                if (generatedOp != null) {
                    specToUse = JSON.serialize(generatedOp);
                }
                String generatedPath = EndpointConfigGenerator.getGeneratedPath(
                        rec.Class_Name__c,
                        rec.Method_Name__c
                );
                if (String.isNotBlank(generatedPath)) {
                    path = generatedPath;
                }
            }

            Map<String, Object> operation = null;
            try {
                if (String.isBlank(specToUse)) {
                    operation = new Map<String, Object>();
                } else {
                    operation = (Map<String, Object>) JSON.deserializeUntyped(specToUse);
                    if (operation == null) operation = new Map<String, Object>();
                }
            } catch (Exception ex) {
                // If the stored Spec__c is not valid JSON, skip using it and fall back to an empty operation
                operation = new Map<String, Object>();
            }

            // Ensure tags and deprecated flags are presentable even when input was malformed
            if (!operation.containsKey('tags')) operation.put('tags', new List<String>());
            List<Object> opTags = (List<Object>) operation.get('tags');
            if (rec.Class_Name__c != null && !opTags.contains(rec.Class_Name__c)) opTags.add(rec.Class_Name__c);
            operation.put('tags', opTags);
            if (rec.Deprecated__c) {
                operation.put('deprecated', true);
            }

            String method = rec.Http_Method__c.toLowerCase();

            if (!paths.containsKey(path)) {
                paths.put(path, new Map<String, Object>());
            }

            ((Map<String, Object>) paths.get(path)).put(method, operation);
        }

        spec.put('openapi', '3.0.3');

        spec.put(
                'info',
                new Map<String, Object>{
                        'title' => 'Salesforce API', 'version' => '1.0'
                }
        );

        List<Map<String, String>> tagsList = new List<Map<String, String>>();
        List<String> sortedClassNames = new List<String>(classNames);
        sortedClassNames.sort();
        for (String cn : sortedClassNames) {
            tagsList.add(new Map<String, String>{
                    'name' => cn
            });
        }
        spec.put('tags', tagsList);

        spec.put('paths', paths);

        spec.put(
                'components',
                new Map<String, Object>{
                        'securitySchemes' => new Map<String, Object>{
                                'BearerAuth' => new Map<String, Object>{
                                        'type' => 'http',
                                        'scheme' => 'bearer',
                                        'bearerFormat' => 'JWT'
                                },
                                'salesforce_oauth' => new Map<String, Object>{
                                        'type' => 'oauth2',
                                        'flows' => new Map<String, Object>{
                                                'authorizationCode' => new Map<String, Object>{
                                                        'authorizationUrl' => 'https://login.salesforce.com/services/oauth2/authorize',
                                                        'tokenUrl' => 'https://login.salesforce.com/services/oauth2/token',
                                                        'scopes' => new Map<String, Object>{
                                                                'api' => 'Access API'
                                                        }
                                                }
                                        }
                                }
                        }
                }
        );

        spec.put(
                'security',
                new List<Object>{
                        new Map<String, Object>{
                                'BearerAuth' => new List<String>()
                        },
                        new Map<String, Object>{
                                'salesforce_oauth' => new List<String>{
                                        'api'
                                }
                        }
                }
        );

        return spec;
    }

    @TestVisible
    public static Map<String, Object> runGenerateSpecForTest() {
        // Instantiate controller under test conditions and invoke generateSpec to exercise code paths
        SwaggerUIController c = new SwaggerUIController();
        return c.generateSpec();
    }
}
