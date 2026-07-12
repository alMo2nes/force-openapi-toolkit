public with sharing class SwaggerUIController {

    public String specJson { get; private set; }
    public String orgDomain { get; private set; }
    public String sessionToken { get; private set; }
    public Boolean isGuest { get; private set; }

    public SwaggerUIController() {
        specJson = JSON.serialize(generateSpec());
        // Initialize orgDomain using System.DomainCreator; fallback to login.salesforce.com
        try {
            String host = System.DomainCreator.getOrgMyDomainHostname();
            if (host != null && host.trim().length() > 0) {
                orgDomain = 'https://' + host;
            } else {
                orgDomain = 'https://login.salesforce.com';
            }
        } catch (Exception e) {
            orgDomain = 'https://login.salesforce.com';
        }

        // Determine whether current user is a guest and whether to expose session id.
        // Use UserInfo.getUserType() instead of querying Profile, which guest users cannot access.
        try {
            Boolean guest = UserInfo.getUserType() == 'Guest';
            isGuest = guest;

            if (!guest) {
                sessionToken = UserInfo.getSessionId();
            } else {
                sessionToken = '';
            }
        } catch (Exception e) {
            isGuest = false;
            sessionToken = '';
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

            if (rec.Auto_Sync_Spec__c && String.isNotBlank(rec.Method_Name__c)) {
                Map<String, Object> generatedOp = EndpointConfigGenerator.getOperationSpec(rec.Class_Name__c, rec.Method_Name__c);
                if (generatedOp != null) {
                    specToUse = JSON.serialize(generatedOp);
                }
                String generatedPath = EndpointConfigGenerator.getGeneratedPath(rec.Class_Name__c, rec.Method_Name__c);
                if (String.isNotBlank(generatedPath)) {
                    path = generatedPath;
                }
            }

            Map<String, Object> operation =
                    (Map<String, Object>)JSON.deserializeUntyped(specToUse);

            operation.put('tags', new List<String>{ rec.Class_Name__c });
            if (rec.Deprecated__c) {
                operation.put('deprecated', true);
            }

            String method = rec.Http_Method__c.toLowerCase();

            if (!paths.containsKey(path)) {
                paths.put(path, new Map<String, Object>());
            }

            ((Map<String, Object>)paths.get(path)).put(method, operation);
        }

        spec.put('openapi', '3.0.3');

        spec.put(
                'info',
                new Map<String, Object>{
                        'title' => 'Salesforce API',
                        'version' => '1.0'
                }
        );

        List<Map<String, String>> tagsList = new List<Map<String, String>>();
        List<String> sortedClassNames = new List<String>(classNames);
        sortedClassNames.sort();
        for (String cn : sortedClassNames) {
            tagsList.add(new Map<String, String>{ 'name' => cn });
        }
        spec.put('tags', tagsList);

        spec.put('paths', paths);

        spec.put(
                'components',
                new Map<String, Object>{
                        'securitySchemes' =>
                                new Map<String, Object>{

                                        'BearerAuth' =>
                                                new Map<String, Object>{
                                                        'type' => 'http',
                                                        'scheme' => 'bearer',
                                                        'bearerFormat' => 'JWT'
                                                },

                                        'salesforce_oauth' =>
                                                new Map<String, Object>{
                                                        'type' => 'oauth2',
                                                        'flows' =>
                                                                new Map<String, Object>{
                                                                        'authorizationCode' =>
                                                                                new Map<String, Object>{
                                                                                        'authorizationUrl' =>
                                                                                                'https://login.salesforce.com/services/oauth2/authorize',
                                                                                        'tokenUrl' =>
                                                                                                'https://login.salesforce.com/services/oauth2/token',
                                                                                        'scopes' =>
                                                                                                new Map<String, Object>{
                                                                                                        'api' =>
                                                                                                                'Access API'
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
                                'BearerAuth' =>
                                        new List<String>()
                        },
                        new Map<String, Object>{
                                'salesforce_oauth' =>
                                        new List<String>{ 'api' }
                        }
                }
        );

        return spec;
    }

}