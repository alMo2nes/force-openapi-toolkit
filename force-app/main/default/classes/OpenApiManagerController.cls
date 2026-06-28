/**
 * OpenApiManagerController
 *
 * Backend for the Apex API Studio. Handles class discovery and metadata deployment.
 */
public with sharing class OpenApiManagerController {
    private static final String ENDPOINT_METADATA_TYPE = 'OpenApi_Endpoint';

    public class SidebarItem {
        @AuraEnabled public String className;
        @AuraEnabled public Boolean hasConfig;
        @AuraEnabled public Integer configCount;
        @AuraEnabled public String latestVersion;
    }

    @AuraEnabled(cacheable=true)
    public static List<SidebarItem> getSidebarItems() {
        List<RestEndpointInspector.EndpointDescriptor> sourceClasses = RestEndpointInspector.getRestEndpoints();
        Map<String, SidebarItem> itemMap = new Map<String, SidebarItem>();
        for (RestEndpointInspector.EndpointDescriptor ed : sourceClasses) {
            SidebarItem item = new SidebarItem();
            item.className = ed.className;
            item.hasConfig = false;
            item.configCount = 0;
            itemMap.put(ed.className, item);
        }

        for (OpenApi_Endpoint__mdt mdt : [SELECT Class_Name__c, Version__c FROM OpenApi_Endpoint__mdt WHERE Active__c = true WITH USER_MODE]) {
            if (itemMap.containsKey(mdt.Class_Name__c)) {
                SidebarItem item = itemMap.get(mdt.Class_Name__c);
                item.hasConfig = true;
                item.configCount++;
                item.latestVersion = mdt.Version__c;
            }
        }
        return itemMap.values();
    }

    @AuraEnabled
    public static List<RestEndpointInspector.EndpointDescriptor> getDiscoveredEndpoints() {
        return RestEndpointInspector.getRestEndpoints();
    }

    @AuraEnabled
    public static List<ConfigComparison> getConfigsForClass(String className) {
        if (String.isBlank(className)) {
            return new List<ConfigComparison>();
        }

        List<ConfigComparison> results = new List<ConfigComparison>();
        List<RestEndpointInspector.EndpointDescriptor> all = RestEndpointInspector.getRestEndpoints();
        RestEndpointInspector.EndpointDescriptor target;
        for (RestEndpointInspector.EndpointDescriptor ed : all) { if (ed.className == className) { target = ed; break; } }
        if (target == null) return results;

        Map<String, OpenApi_Endpoint__mdt> mdtMap = new Map<String, OpenApi_Endpoint__mdt>();
        for (OpenApi_Endpoint__mdt mdt : [
            SELECT DeveloperName, Path__c, Http_Method__c, Spec__c, Version__c, Active__c, Deprecated__c, Method_Name__c
            FROM OpenApi_Endpoint__mdt WHERE Class_Name__c = :className WITH USER_MODE
        ]) { mdtMap.put(mdt.Http_Method__c.toUpperCase() + '|' + mdt.Method_Name__c, mdt); }

        for (RestEndpointInspector.MethodDescriptor method : target.httpMethods) {
            String httpMethod = EndpointConfigGenerator.extractHttpMethod(method.annotations).toUpperCase();
            ConfigComparison comp = new ConfigComparison();
            comp.className = className;
            comp.methodName = method.name;
            comp.httpMethod = httpMethod;
            comp.srcPath = standardizePath(target.urlPath, method);
            comp.srcSpec = JSON.serializePretty(EndpointConfigGenerator.getOperationSpec(className, method.name));

            String key = httpMethod + '|' + method.name;
            if (mdtMap.containsKey(key)) {
                OpenApi_Endpoint__mdt mdt = mdtMap.get(key);
                comp.isNew = false;
                comp.mdtId = mdt.DeveloperName;
                comp.mdtPath = mdt.Path__c;
                comp.mdtSpec = mdt.Spec__c;
                comp.mdtVersion = mdt.Version__c;
                comp.mdtActive = mdt.Active__c;
                comp.mdtDeprecated = mdt.Deprecated__c;
                comp.currentPath = comp.mdtPath;
                comp.currentSpec = comp.mdtSpec;
                comp.currentVersion = comp.mdtVersion;
                comp.currentActive = comp.mdtActive;
                comp.currentDeprecated = comp.mdtDeprecated;
                comp.isPathOutdated = (comp.mdtPath != comp.srcPath);
                comp.isSpecOutdated = (comp.mdtSpec != comp.srcSpec);
            } else {
                comp.isNew = true;
                comp.currentPath = comp.srcPath;
                comp.currentSpec = comp.srcSpec;
                comp.currentVersion = '1.0';
                comp.currentActive = true;
                comp.currentDeprecated = false;
            }
            results.add(comp);
        }
        return results;
    }

    /**
     * Enqueues deployment and returns the Job ID for tracking.
     */
    @AuraEnabled
    public static String saveConfigs(List<String> jsonConfigs) {
        if (jsonConfigs == null || jsonConfigs.isEmpty()) {
            throw new AuraHandledException('No endpoint configurations were provided.');
        }

        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
        for (String jsonStr : jsonConfigs) {
            if (String.isBlank(jsonStr)) {
                throw new AuraHandledException('Endpoint configuration payload cannot be blank.');
            }

            ConfigComparison rec = (ConfigComparison) JSON.deserialize(jsonStr, ConfigComparison.class);
            validateConfigForSave(rec);

            Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
            String recordName = rec.className + '_' + rec.methodName + '_' + normalizeVersionForDeveloperName(rec.currentVersion);
            customMetadata.fullName = ENDPOINT_METADATA_TYPE + '.' + recordName;
            customMetadata.label = rec.className + ' ' + rec.methodName + ' v' + rec.currentVersion;
            addValue(customMetadata, 'Path__c', rec.currentPath);
            addValue(customMetadata, 'Http_Method__c', rec.httpMethod);
            addValue(customMetadata, 'Spec__c', rec.currentSpec);
            addValue(customMetadata, 'Version__c', rec.currentVersion);
            addValue(customMetadata, 'Active__c', rec.currentActive);
            addValue(customMetadata, 'Deprecated__c', rec.currentDeprecated);
            addValue(customMetadata, 'Class_Name__c', rec.className);
            addValue(customMetadata, 'Method_Name__c', rec.methodName);
            mdContainer.addMetadata(customMetadata);
        }

        if (Test.isRunningTest()) return 'test-job-id';
        return Metadata.Operations.enqueueDeployment(mdContainer, null);
    }

    /**
     * Checks the status of a specific metadata deployment.
     */
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
    @AuraEnabled
    public static String checkDeploymentStatus(String jobId) {
        Id deployRequestId;
        try {
            deployRequestId = Id.valueOf(jobId);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid deployment job id.');
        }

        // Same-org Tooling API query for the Metadata API deployment record.
        String domain = 'https://' + System.DomainCreator.getOrgMyDomainHostname();
        String url = domain + '/services/data/v66.0/tooling/query/?q=' +
                     EncodingUtil.urlEncode('SELECT Status FROM DeployRequest WHERE Id = \'' + String.escapeSingleQuotes(String.valueOf(deployRequestId)) + '\'', 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + SessionService.getSessionId());

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            return 'Error';
        }

        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> records = (List<Object>) data.get('records');
        if (records == null || records.isEmpty()) {
            return 'Pending';
        }

        return (String) ((Map<String, Object>)records[0]).get('Status');
    }

    public class ConfigComparison {
        @AuraEnabled public String methodName;
        @AuraEnabled public String httpMethod;
        @AuraEnabled public String className;
        @AuraEnabled public String mdtId;
        @AuraEnabled public String mdtPath;
        @AuraEnabled public String mdtSpec;
        @AuraEnabled public String mdtVersion;
        @AuraEnabled public Boolean mdtActive;
        @AuraEnabled public Boolean mdtDeprecated;
        @AuraEnabled public String srcPath;
        @AuraEnabled public String srcSpec;
        @AuraEnabled public String currentPath;
        @AuraEnabled public String currentSpec;
        @AuraEnabled public String currentVersion;
        @AuraEnabled public Boolean currentActive;
        @AuraEnabled public Boolean currentDeprecated;
        @AuraEnabled public Boolean isNew;
        @AuraEnabled public Boolean isPathOutdated;
        @AuraEnabled public Boolean isSpecOutdated;
    }

    private static void addValue(Metadata.CustomMetadata md, String field, Object val) {
        Metadata.CustomMetadataValue v = new Metadata.CustomMetadataValue();
        v.field = field; v.value = val; md.values.add(v);
    }

    private static void validateConfigForSave(ConfigComparison rec) {
        if (rec == null) {
            throw new AuraHandledException('Endpoint configuration payload is invalid.');
        }
        if (String.isBlank(rec.className) || String.isBlank(rec.methodName)) {
            throw new AuraHandledException('Endpoint class and method are required.');
        }
        if (String.isBlank(rec.httpMethod) || String.isBlank(rec.currentPath)) {
            throw new AuraHandledException('Endpoint HTTP method and path are required.');
        }
        if (String.isBlank(rec.currentVersion)) {
            throw new AuraHandledException('Endpoint version is required.');
        }
        if (String.isBlank(rec.currentSpec)) {
            throw new AuraHandledException('Endpoint OpenAPI spec cannot be blank.');
        }

        try {
            JSON.deserializeUntyped(rec.currentSpec);
        } catch (JSONException e) {
            throw new AuraHandledException('Endpoint OpenAPI spec must be valid JSON.');
        }
    }

    private static String normalizeVersionForDeveloperName(String version) {
        String normalized = version.trim().replaceAll('[^A-Za-z0-9]+', '_');
        while (normalized.startsWith('_')) {
            normalized = normalized.substring(1);
        }
        while (normalized.endsWith('_')) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }

        if (String.isBlank(normalized)) {
            throw new AuraHandledException('Endpoint version must contain at least one letter or number.');
        }
        return normalized;
    }

    private static String standardizePath(String classMapping, RestEndpointInspector.MethodDescriptor method) {
        String base = '/services/apexrest';
        if (String.isNotBlank(method.pathTag)) {
            String tag = method.pathTag.trim();
            return base + (tag.startsWith('/') ? '' : '/') + tag;
        }
        String mapping = (classMapping != null) ? classMapping.trim() : '';
        if (mapping.endsWith('/*')) {
            mapping = mapping.substring(0, mapping.length() - 2);
            String pathInjections = '';
            if (method.parameters != null) {
                for (RestEndpointInspector.MethodParameter p : method.parameters) {
                    if (p.location == 'path') pathInjections += '/{' + p.name + '}';
                }
            }
            mapping += pathInjections;
        }
        return base + (mapping.startsWith('/') ? '' : '/') + mapping;
    }
}