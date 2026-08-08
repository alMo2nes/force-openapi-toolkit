public class ToolingApiMock implements HttpCalloutMock {
    private String searchBody;
    private String queryBody;
    private Integer callCount = 0;

    public ToolingApiMock(String searchBody, String queryBody) {
        this.searchBody = searchBody;
        this.queryBody = queryBody;
    }

    public static ToolingApiMock defaultMock() {
        // Build a richer payload with multiple REST resource classes modeled after force-app-samples
        List<Map<String, Object>> classes = new List<Map<String, Object>>();

        classes.add(new Map<String, Object>{
            'Id' => '01pAccApi000000001A',
            'Name' => 'AccountApi',
            'Body' => '@RestResource(UrlMapping=\'/v1/accounts/*\')\npublic with sharing class AccountApi {\n  @HttpGet\n  global static Account getAccount() { return null; }\n  @HttpPatch\n  global static Account updateAccount() { return null; }\n}',
            'Methods' => new List<Map<String, Object>>{
                new Map<String, Object>{ 'name' => 'getAccount', 'annotation' => 'HttpGet', 'line' => 12 },
                new Map<String, Object>{ 'name' => 'updateAccount', 'annotation' => 'HttpPatch', 'line' => 75 }
            }
        });

        classes.add(new Map<String, Object>{
            'Id' => '01pConApi000000002B',
            'Name' => 'ContactApi',
            'Body' => '@RestResource(urlMapping=\'/v1/contacts/*\')\nglobal with sharing class ContactApi {\n  @HttpGet\n  global static Contact getContact() { return null; }\n  @HttpPost\n  global static Contact createContact() { return null; }\n}',
            'Methods' => new List<Map<String, Object>>{
                new Map<String, Object>{ 'name' => 'getContact', 'annotation' => 'HttpGet', 'line' => 12 },
                new Map<String, Object>{ 'name' => 'createContact', 'annotation' => 'HttpPost', 'line' => 35 }
            }
        });

        classes.add(new Map<String, Object>{
            'Id' => '01pCplxApi000000003C',
            'Name' => 'ComplexApi',
            'Body' => '@RestResource(urlMapping=\'/v1/complex/*\')\nglobal with sharing class ComplexApi {\n  @HttpGet\n  global static Account getComplexData() { return null; }\n}',
            'Methods' => new List<Map<String, Object>>{
                new Map<String, Object>{ 'name' => 'getComplexData', 'annotation' => 'HttpGet', 'line' => 17 }
            }
        });

        // Build search body
        String search = buildSearchBody(classes);
        // Build query/body payload
        String query = buildQueryBody(classes);

        return new ToolingApiMock(search, query);
    }

    public HttpResponse respond(HttpRequest req) {
        callCount++;
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/json');
        res.setBody(callCount == 1 ? searchBody : queryBody);
        return res;
    }

    // Helper builders to produce Tooling-like payloads
    private static String buildSearchBody(List<Map<String, Object>> classes) {
        List<String> parts = new List<String>();
        for (Map<String, Object> cls : classes) {
            parts.add('{"Id":"' + (String)cls.get('Id') + '","Name":"' + (String)cls.get('Name') + '"}');
        }
        return '{"searchRecords":[' + String.join(parts, ',') + ']}';
    }

    private static String buildQueryBody(List<Map<String, Object>> classes) {
        List<String> recs = new List<String>();
        for (Map<String, Object> cls : classes) {
            String id = (String) cls.get('Id');
            String name = (String) cls.get('Name');
            String body = (String) cls.get('Body');
            String ns = cls.containsKey('NamespacePrefix')
                ? (String) cls.get('NamespacePrefix')
                : '';
            List<Map<String, Object>> methods = (List<Map<String, Object>>) cls.get('Methods');

            // Build symbol table
            List<String> methodParts = new List<String>();
            for (Map<String, Object> m : methods) {
                String mname = (String) m.get('name');
                String ann = (String) m.get('annotation');
                Integer line = (Integer) m.get('line');
                methodParts.add('{"name":"' + mname + '","returnType":"void","location":{"line":' + String.valueOf(line) + '},"annotations":[{"name":"' + ann + '"}],"parameters":[]}');
            }
            String symbolTable = '{"methods":[' + String.join(methodParts, ',') + ']}';

            String escaped = body.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r');

            recs.add('{"Id":"' + id + '","Name":"' + name + '","NamespacePrefix":"' + (ns != null ? ns : '') + '","Body":"' + escaped + '","SymbolTable":' + symbolTable + '}');
        }
        return '{"records":[' + String.join(recs, ',') + ']}';
    }

}
