/**
 * EndpointConfigGenerator
 */
public with sharing class EndpointConfigGenerator {

    @AuraEnabled
    public static String generatePathsConfig() {
        List<RestEndpointInspector.EndpointDescriptor> endpoints = RestEndpointInspector.getRestEndpoints();
        Map<String, Object> paths = new Map<String, Object>();
        for (RestEndpointInspector.EndpointDescriptor ed : endpoints) {
            for (RestEndpointInspector.MethodDescriptor method : ed.httpMethods) {
                String httpMethod = extractHttpMethod(method.annotations);
                String fullPath = calculateFinalPath(ed.urlPath, method);
                if (!paths.containsKey(fullPath)) paths.put(fullPath, new Map<String, Object>());
                ((Map<String, Object>)paths.get(fullPath)).put(httpMethod.toLowerCase(), buildOperation(ed.className, fullPath, method));
            }
        }
        return JSON.serializePretty(paths);
    }

    public static Map<String, Object> getOperationSpec(String className, String methodName) {
        List<RestEndpointInspector.EndpointDescriptor> endpoints = RestEndpointInspector.getRestEndpoints();
        for (RestEndpointInspector.EndpointDescriptor ed : endpoints) {
            if (ed.className == className) {
                for (RestEndpointInspector.MethodDescriptor method : ed.httpMethods) {
                    if (method.name == methodName) {
                        return buildOperation(ed.className, calculateFinalPath(ed.urlPath, method), method);
                    }
                }
            }
        }
        return null;
    }

    @AuraEnabled
    public static String generateOpenApiSpec() {
        Map<String, Object> spec = new Map<String, Object>{
            'openapi' => '3.0.0',
            'info' => new Map<String, Object>{ 'title' => 'Salesforce REST API', 'version' => '1.0.0' },
            'paths' => JSON.deserializeUntyped(generatePathsConfig())
        };
        return JSON.serializePretty(spec);
    }

    private static String calculateFinalPath(String classMapping, RestEndpointInspector.MethodDescriptor method) {
        return RestEndpointInspector.buildFullPath(classMapping, method);
    }

    public static Map<String, Object> buildOperation(String className, String urlPath, RestEndpointInspector.MethodDescriptor method) {
        Map<String, Object> op = new Map<String, Object>();
        op.put('operationId', className + '_' + method.name);
        op.put('summary', String.isNotBlank(method.description) ? method.description : 'Call ' + method.name);
        List<Map<String, Object>> parameters = new List<Map<String, Object>>();
        Map<String, Object> reqBody;
        Set<String> pathTokens = new Set<String>();
        Pattern pat = Pattern.compile('\\{([^}]+)\\}');
        Matcher mat = pat.matcher(urlPath);
        while (mat.find()) pathTokens.add(mat.group(1));
        if (method.parameters != null) {
            for (RestEndpointInspector.MethodParameter p : method.parameters) {
                String loc = String.isNotBlank(p.location) ? p.location : (pathTokens.contains(p.name) ? 'path' : '');
                String mType = extractHttpMethod(method.annotations);
                if (loc == 'path' || loc == 'query' || mType == 'GET' || mType == 'DELETE') {
                    parameters.add(new Map<String, Object>{
                        'name' => p.name, 'in' => (String.isBlank(loc) ? 'query' : loc),
                        'required' => (loc == 'path' || p.required == true),
                        'schema' => buildSchema(p.type), 'description' => p.description
                    });
                } else if (reqBody == null) {
                    reqBody = new Map<String, Object>{ 'content' => new Map<String, Object>{ 'application/json' => new Map<String, Object>{ 'schema' => buildSchema(p.type) } } };
                    if (String.isNotBlank(p.description)) reqBody.put('description', p.description);
                }
            }
        }
        if (!parameters.isEmpty()) op.put('parameters', parameters);
        if (reqBody != null) op.put('requestBody', reqBody);
        Map<String, Object> resMap = new Map<String, Object>();
        if (method.responses != null && !method.responses.isEmpty()) {
            for (RestEndpointInspector.ResponseDescriptor r : method.responses) {
                Map<String, Object> resp = new Map<String, Object>{ 'description' => r.description };
                if (String.isNotBlank(r.type)) resp.put('content', new Map<String, Object>{ 'application/json' => new Map<String, Object>{ 'schema' => buildSchema(r.type) } });
                resMap.put(r.code, resp);
            }
        } else { resMap.put('200', new Map<String, Object>{ 'description' => 'Success' }); }
        op.put('responses', resMap);
        return op;
    }

    private static Map<String, Object> buildSchema(String apexType) {
        if (String.isBlank(apexType)) return new Map<String, Object>{'type' => 'string'};
        String t = apexType.replaceAll('\\s+', '');
        if (t.contains(':')) {
            Map<String, Object> props = new Map<String, Object>();
            String c = t.replace('{', '').replace('}', '');
            for (String f : c.split(',')) props.put(f.substringBefore(':').trim(), buildSchema(f.substringAfter(':').trim()));
            return new Map<String, Object>{ 'type' => 'object', 'properties' => props };
        }
        Map<String, Object> s = new Map<String, Object>();
        String lt = apexType.toLowerCase();
        if (lt.contains('list<') || lt.contains('set<') || lt.endsWith('[]')) {
            s.put('type', 'array');
            s.put('items', buildSchema(lt.contains('<') ? apexType.substringBetween('<', '>') : apexType.substring(0, apexType.length()-2)));
        } else {
            String type = inferType(apexType);
            s.put('type', type);
            if (type == 'object') { s.put('additionalProperties', true); s.put('description', 'Apex: ' + apexType); }
        }
        return s;
    }

    private static String inferType(String a) {
        String l = a.toLowerCase();
        if (l == 'integer' || l == 'long' || l == 'double' || l == 'decimal') return 'number';
        if (l == 'boolean') return 'boolean';
        if (l == 'string' || l == 'id' || l == 'date' || l == 'datetime' || l == 'time') return 'string';
        return 'object';
    }

    public static String extractHttpMethod(List<RestEndpointInspector.MethodAnnotation> ann) {
        if (ann == null) return 'GET';
        for (RestEndpointInspector.MethodAnnotation a : ann) {
            if (a.name == 'HttpGet') return 'GET';
            if (a.name == 'HttpPost') return 'POST';
            if (a.name == 'HttpPut') return 'PUT';
            if (a.name == 'HttpPatch') return 'PATCH';
            if (a.name == 'HttpDelete') return 'DELETE';
        }
        return 'GET';
    }
}