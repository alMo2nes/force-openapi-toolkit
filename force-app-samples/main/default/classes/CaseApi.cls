/**
 * @description Dummy REST API for Case management.
 * This class purposefully lacks many ApexDoc tags to test the "Empty" state behavior.
 */
@RestResource(urlMapping='/v1/cases/*')
global with sharing class CaseApi {

    @HttpGet
    global static Case getCase() {
        RestRequest req = RestContext.request;
        String caseId = req.requestURI.substringAfterLast('/');
        return [SELECT Id, CaseNumber, Subject, Status FROM Case WHERE Id = :caseId WITH USER_MODE LIMIT 1];
    }
}
