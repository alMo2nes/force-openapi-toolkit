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
                        Version__c,
                        Spec__c,
                        Deprecated__c,
                        Active__c,
                        Class_Name__c
                FROM OpenApi_Endpoint__mdt
                WHERE Active__c = TRUE
                ORDER BY Class_Name__c, Path__c, Http_Method__c, Version__c
        ];

        Map<String, List<OpenApi_Endpoint__mdt>> grouped =
                new Map<String, List<OpenApi_Endpoint__mdt>>();

        Set<String> classNames = new Set<String>();

        for (OpenApi_Endpoint__mdt rec : records) {

            String key =
                    rec.Class_Name__c + '|' +
                            rec.Path__c + '|' +
                            rec.Http_Method__c.toLowerCase();

            if (!grouped.containsKey(key)) {
                grouped.put(key, new List<OpenApi_Endpoint__mdt>());
            }

            grouped.get(key).add(rec);

            if (String.isNotBlank(rec.Class_Name__c)) {
                classNames.add(rec.Class_Name__c);
            }
        }

        for (String key : grouped.keySet()) {

            List<String> parts = key.split('\\|');

            String className = parts[0];
            String path = parts[1];
            String method = parts[2];

            List<OpenApi_Endpoint__mdt> versions =
                    grouped.get(key);

            OpenApi_Endpoint__mdt latest =
                    versions[versions.size() - 1];

            Map<String, Object> operation =
                    (Map<String, Object>)JSON.deserializeUntyped(
                            latest.Spec__c
                    );

            // Tag each operation with its Apex class name so Swagger UI groups by class
            operation.put('tags', new List<String>{ className });

            //
            // Version selector
            //
            List<Object> parameters =
                    operation.containsKey('parameters')
                            ? (List<Object>)operation.get('parameters')
                            : new List<Object>();

            List<String> enumValues = new List<String>();

            for (OpenApi_Endpoint__mdt v : versions) {

                String label = v.Version__c;

                if (v.Deprecated__c) {
                    label += ' (deprecated)';
                }

                enumValues.add(label);
            }

            parameters.add(
                    new Map<String, Object>{
                            'name' => 'version',
                            'in' => 'header',
                            'required' => true,
                            'description' => 'API Version',
                            'schema' => new Map<String, Object>{
                                    'type' => 'string',
                                    'enum' => enumValues
                            }
                    }
            );

            operation.put('parameters', parameters);

            //
            // Merge schemas
            //
            List<Object> oneOfSchemas =
                    new List<Object>();

            for (OpenApi_Endpoint__mdt v : versions) {

                try {

                    Map<String, Object> versionOp =
                            (Map<String, Object>)JSON.deserializeUntyped(
                                    v.Spec__c
                            );

                    Map<String, Object> responses =
                            (Map<String, Object>)versionOp.get('responses');

                    if (responses == null ||
                            !responses.containsKey('200')) {
                        continue;
                    }

                    Map<String, Object> response200 =
                            (Map<String, Object>)responses.get('200');

                    Map<String, Object> content =
                            (Map<String, Object>)response200.get('content');

                    if (content == null ||
                            !content.containsKey('application/json')) {
                        continue;
                    }

                    Map<String, Object> jsonContent =
                            (Map<String, Object>)content.get(
                                    'application/json'
                            );

                    Map<String, Object> schema =
                            (Map<String, Object>)jsonContent.get('schema');

                    if (schema == null) {
                        continue;
                    }

                    oneOfSchemas.add(
                            new Map<String, Object>{
                                    'title' => v.Version__c,
                                    'description' =>
                                            v.Deprecated__c
                                                    ? 'Deprecated'
                                                    : 'Current',
                                    'allOf' => new List<Object>{ schema }
                            }
                    );

                } catch (Exception e) {
                    System.debug(e);
                }
            }

            if (!oneOfSchemas.isEmpty()) {

                operation.put(
                        'responses',
                        new Map<String, Object>{
                                '200' => new Map<String, Object>{
                                        'description' =>
                                                'Version-specific response',
                                        'content' =>
                                                new Map<String, Object>{
                                                        'application/json' =>
                                                                new Map<String, Object>{
                                                                        'schema' =>
                                                                                new Map<String, Object>{
                                                                                        'oneOf' =>
                                                                                                oneOfSchemas
                                                                                }
                                                                }
                                                }
                                }
                        }
                );
            }

            if (!paths.containsKey(path)) {
                paths.put(path,
                        new Map<String, Object>());
            }

            ((Map<String, Object>)paths.get(path))
                    .put(method, operation);
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