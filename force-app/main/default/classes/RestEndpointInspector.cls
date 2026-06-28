/**
 * RestEndpointInspector
 */
public with sharing class RestEndpointInspector {

    public class MethodParameter {
        @AuraEnabled public String name;
        @AuraEnabled public String type;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean required;
        @AuraEnabled public String location;
    }

    public class MethodAnnotation { @AuraEnabled public String name; }

    public class ResponseDescriptor {
        @AuraEnabled public String code;
        @AuraEnabled public String type;
        @AuraEnabled public String description;
    }

    public class MethodDescriptor {
        @AuraEnabled public String name;
        @AuraEnabled public String returnType;
        @AuraEnabled public String description;
        @AuraEnabled public String pathTag;
        @AuraEnabled public List<MethodAnnotation> annotations;
        @AuraEnabled public List<MethodParameter> parameters;
        @AuraEnabled public List<ResponseDescriptor> responses;
        @AuraEnabled public Integer lineNumber;
    }

    public class EndpointDescriptor {
        @AuraEnabled public String className;
        @AuraEnabled public String urlPath;
        @AuraEnabled public String description;
        @AuraEnabled public List<MethodDescriptor> httpMethods;
    }

     @AuraEnabled
     public static List<EndpointDescriptor> getRestEndpoints() {
         String domain = 'https://' + System.DomainCreator.getOrgMyDomainHostname();
         String apiVersion = 'v67.0';

        // Use the elevated session ID from the SessionService bridge
        String sessionId = SessionService.getSessionId();

        // 1. Search
        String sosl = 'FIND {@RestResource} IN ALL FIELDS RETURNING ApexClass(Id, Name)';
        HttpResponse res = callTooling(domain + '/services/data/' + apiVersion + '/tooling/search/?q=' + EncodingUtil.urlEncode(sosl, 'UTF-8'), sessionId);

        if (res.getStatusCode() != 200) {
            System.debug('Tooling Search Error: ' + res.getBody());
            return new List<EndpointDescriptor>();
        }

        List<Object> searchRecords = (List<Object>) ((Map<String, Object>) JSON.deserializeUntyped(res.getBody())).get('searchRecords');
        if (searchRecords == null || searchRecords.isEmpty()) return new List<EndpointDescriptor>();

        List<String> ids = new List<String>();
        for (Object r : searchRecords) ids.add('\'' + (String)((Map<String, Object>)r).get('Id') + '\'');

        // 2. Query
        String query = 'SELECT Id, Name, Body, SymbolTable FROM ApexClass WHERE Id IN (' + String.join(ids, ',') + ')';
        HttpResponse qRes = callTooling(domain + '/services/data/' + apiVersion + '/tooling/query/?q=' + EncodingUtil.urlEncode(query, 'UTF-8'), sessionId);

        if (qRes.getStatusCode() != 200) {
            System.debug('Tooling Query Error: ' + qRes.getBody());
            return new List<EndpointDescriptor>();
        }

        List<Object> records = (List<Object>) ((Map<String, Object>) JSON.deserializeUntyped(qRes.getBody())).get('records');
        List<EndpointDescriptor> descriptors = new List<EndpointDescriptor>();
        for (Object recordObj : records) {
            Map<String, Object> record = (Map<String, Object>) recordObj;
            Map<String, Object> symbolTable = (Map<String, Object>) record.get('SymbolTable');
            String body = (String) record.get('Body');
            if (symbolTable == null) continue;

            EndpointDescriptor ed = new EndpointDescriptor();
            ed.className = (String) record.get('Name');
            ed.urlPath = extractUrlMapping(body);
            ed.description = parseApexDoc(body, 1).description;
            ed.httpMethods = filterHttpMethods(extractMethods(symbolTable, body));
            if (!ed.httpMethods.isEmpty()) descriptors.add(ed);
        }
        return descriptors;
    }

    private static HttpResponse callTooling(String url, String sessionId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'application/json');
        return new Http().send(req);
    }

    private static List<MethodDescriptor> extractMethods(Map<String, Object> symbolTable, String body) {
        List<MethodDescriptor> methods = new List<MethodDescriptor>();
        List<Object> methodObjs = (List<Object>) symbolTable.get('methods');
        if (methodObjs == null) return methods;
        for (Object methodObj : methodObjs) {
            Map<String, Object> methodMap = (Map<String, Object>) methodObj;
            MethodDescriptor md = new MethodDescriptor();
            md.name = (String) methodMap.get('name');
            md.returnType = (String) methodMap.get('returnType');
            Map<String, Object> loc = (Map<String, Object>) methodMap.get('location');
            md.lineNumber = loc != null ? (Integer) loc.get('line') : 0;
            md.annotations = new List<MethodAnnotation>();
            List<Object> annList = (List<Object>) methodMap.get('annotations');
            if (annList != null) {
                for (Object a : annList) {
                    MethodAnnotation ma = new MethodAnnotation();
                    ma.name = (String)((Map<String, Object>)a).get('name');
                    md.annotations.add(ma);
                }
            }
            Map<String, MethodParameter> pMap = new Map<String, MethodParameter>();
            List<Object> parameters = (List<Object>) methodMap.get('parameters');
            if (parameters != null) {
                for (Object p : parameters) {
                    Map<String, Object> pm = (Map<String, Object>) p;
                    MethodParameter mp = new MethodParameter();
                    mp.name = (String) pm.get('name');
                    mp.type = (String) pm.get('type');
                    mp.required = false;
                    pMap.put(mp.name, mp);
                }
            }
            if (md.lineNumber > 0) {
                DocInfo docInfo = parseApexDoc(body, md.lineNumber);
                md.description = docInfo.description;
                md.pathTag = docInfo.path;
                md.responses = docInfo.responses;
                for (String docParamName : docInfo.paramMap.keySet()) {
                    DocParam dp = docInfo.paramMap.get(docParamName);
                    if (pMap.containsKey(docParamName)) {
                        MethodParameter mp = pMap.get(docParamName);
                        mp.description = dp.description;
                        mp.required = dp.required;
                        mp.location = dp.location;
                        if (String.isNotBlank(dp.type)) mp.type = dp.type;
                    } else {
                        MethodParameter mp = new MethodParameter();
                        mp.name = docParamName;
                        mp.type = String.isNotBlank(dp.type) ? dp.type : 'String';
                        mp.description = dp.description;
                        mp.required = dp.required;
                        mp.location = dp.location;
                        pMap.put(docParamName, mp);
                    }
                }
            }
            md.parameters = pMap.values();
            methods.add(md);
        }
        return methods;
    }

    private class DocParam { public String type; public String description; public Boolean required = false; public String location; }
    private class DocInfo { public String description = ''; public String path = ''; public Map<String, DocParam> paramMap = new Map<String, DocParam>(); public List<ResponseDescriptor> responses = new List<ResponseDescriptor>(); }

    private static DocInfo parseApexDoc(String body, Integer targetLine) {
        DocInfo info = new DocInfo();
        if (String.isBlank(body)) return info;
        List<String> lines = body.split('\n');
        Integer idx = targetLine - 2;
        Boolean foundDocClose = false;
        // Scan backwards to find the end of the comment block (*/) while staying within the same method/class scope
        while (idx >= 0) {
            String line = lines[idx].trim();
            if (line.contains('*/')) {
                foundDocClose = true;
                break;
            }
            // Stop if we cross a method, variable, or class/interface boundary
            if (line.contains('{') || line.contains('}') ||
                line.contains('public ') || line.contains('private ') || line.contains('global ') || line.contains('protected ') ||
                line.contains('class ') || line.contains('interface ')) {
                break;
            }
            idx--;
        }
        if (!foundDocClose) return info;
        // Gather comment lines up to the opening /**
        List<String> docLines = new List<String>();
        while (idx >= 0) {
            docLines.add(lines[idx].trim());
            idx--;
            if (lines[idx + 1].trim().startsWith('/**')) break;
        }
        String currentTag = 'description';
        String currentBuffer = '';
        for (Integer i = docLines.size() - 1; i >= 0; i--) {
            String clean = docLines[i].replace('/**', '').replace('*/', '').trim();
            if (clean.startsWith('*')) clean = clean.substring(1).trim();
            if (String.isBlank(clean)) continue;
            if (clean.startsWith('@')) {
                processBuffer(currentTag, currentBuffer, info);
                currentTag = clean.substringAfter('@').split(' ')[0].trim();
                currentBuffer = clean.substringAfter('@' + currentTag).trim();
            } else {
                currentBuffer += (String.isBlank(currentBuffer) ? '' : ' ') + clean;
            }
        }
        processBuffer(currentTag, currentBuffer, info);
        return info;
    }

    private static void processBuffer(String tag, String buffer, DocInfo info) {
        if (String.isBlank(buffer)) return;
        String val = buffer.trim();
        if (tag == 'description') info.description = val;
        else if (tag == 'path') info.path = val;
        else if (tag == 'param') {
            DocParam dp = new DocParam();
            if (val.contains('[required]')) { dp.required = true; val = val.replace('[required]', '').trim(); }
            if (val.contains('[path]')) { dp.location = 'path'; dp.required = true; val = val.replace('[path]', '').trim(); }
            if (val.contains('[query]')) { dp.location = 'query'; val = val.replace('[query]', '').trim(); }
            if (val.startsWith('{')) { dp.type = val.substringAfter('{').substringBeforeLast('}'); val = val.substringAfterLast('}').trim(); }
            String pName = val.contains(' ') ? val.substringBefore(' ').trim() : val;
            dp.description = val.contains(' ') ? val.substringAfter(' ').trim() : '';
            if (String.isNotBlank(pName)) info.paramMap.put(pName, dp);
        } else if (tag == 'response') {
            ResponseDescriptor rd = new ResponseDescriptor();
            rd.code = val.substringBefore(' ').trim();
            val = val.substringAfter(' ').trim();
            if (val.startsWith('{')) { rd.type = val.substringAfter('{').substringBeforeLast('}'); rd.description = val.substringAfterLast('}').trim(); }
            else { rd.description = val; }
            if (String.isNotBlank(rd.code)) info.responses.add(rd);
        }
    }

    private static String extractUrlMapping(String body) {
        if (String.isBlank(body)) return null;
        Pattern p = Pattern.compile('(?i)@RestResource\\s*\\(\\s*urlMapping\\s*=\\s*[\'"]([^\'\"]+)[\'"]\\s*\\)');
        Matcher m = p.matcher(body);
        return m.find() ? m.group(1) : null;
    }

    private static List<MethodDescriptor> filterHttpMethods(List<MethodDescriptor> all) {
        List<MethodDescriptor> filtered = new List<MethodDescriptor>();
        Set<String> valid = new Set<String>{'HttpGet', 'HttpPost', 'HttpPut', 'HttpPatch', 'HttpDelete'};
        for (MethodDescriptor m : all) {
            if (m.annotations == null) continue;
            for (MethodAnnotation a : m.annotations) {
                if (valid.contains(a.name)) { filtered.add(m); break; }
            }
        }
        return filtered;
    }

    public static String buildFullPath(String classMapping, RestEndpointInspector.MethodDescriptor method) {
        String base = '/services/apexrest';
        if (String.isNotBlank(method.pathTag)) {
            String tag = method.pathTag.trim();
            if (tag.startsWith(base + '/')) {
                return tag;
            }
            if (tag == base) {
                return tag;
            }
            return base + (tag.startsWith('/') ? tag : '/' + tag);
        }
        String mapping = (classMapping != null) ? classMapping.trim() : '';
        if (mapping.startsWith(base + '/')) {
            mapping = mapping.substring(base.length());
        } else if (mapping == base) {
            mapping = '';
        }
        if (mapping.endsWith('/*')) {
            mapping = mapping.substring(0, mapping.length() - 2);
            String pathInjections = '';
            if (method.parameters != null) {
                for (RestEndpointInspector.MethodParameter p : method.parameters) {
                    if (p.location == 'path') {
                        pathInjections += '/{' + p.name + '}';
                    }
                }
            }
            mapping += pathInjections;
        }
        if (!mapping.startsWith('/') && String.isNotBlank(mapping)) {
            mapping = '/' + mapping;
        }
        return base + mapping;
    }
}