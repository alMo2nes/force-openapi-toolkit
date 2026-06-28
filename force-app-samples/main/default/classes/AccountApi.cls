/**
 * @description Sample REST resource used by this package to expose Account data.
 */
@RestResource(UrlMapping='/v1/accounts/*')
global with sharing class AccountApi {

    /**
     * @description Returns account details for the account id included in the URL.
     * @param {String} accountId [path] The 15 or 18 character Salesforce ID.
     * @response 200 {Account} Successful retrieval of account.
     * @response 404 {String} Account not found error message.
     */
    @HttpGet
    global static Account getAccount() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;

        if (response == null) {
            response = new RestResponse();
            RestContext.response = response;
        }

        // Set Content-Type header for consistency
        response.addHeader('Content-Type', 'application/json; charset=UTF-8');

        String accId = request != null && request.requestURI != null
            ? request.requestURI.substringAfterLast('/')
            : null;
        String trimmedAccountId = accId != null ? accId.trim() : null;

        if (String.isBlank(trimmedAccountId) || !isValidSalesforceId(trimmedAccountId)) {
            response.statusCode = 400;
            response.responseBody = Blob.valueOf('{"error": "Account Id is required"}');
            return null;
        }

        try {
            List<Account> accounts = [SELECT Id, Name, Industry FROM Account WHERE Id = :trimmedAccountId WITH USER_MODE LIMIT 1];
            if (accounts.isEmpty()) {
                response.statusCode = 404;
                response.responseBody = Blob.valueOf('{"error": "Account not found"}');
                return null;
            }
            response.statusCode = 200;
            return accounts[0];
        } catch (Exception e) {
            response.statusCode = 500;
            response.responseBody = Blob.valueOf('{"error": "' + e.getMessage() + '"}');
            return null;
        }
    }

    /**
     * @description Updates specific Account fields.
     * @param {String} id [path] [required] The 15 or 18 character Salesforce ID of the account to update.
     * @param {
     *   name: string,
     *   industry: string
     * } accountBody
     * @response 200 {Account} The updated Account record.
     * @response 400 {String} Error if Id is missing.
     */
    @HttpPatch
    global static Account updateAccount() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        if (req.requestBody == null) {
            res.statusCode = 400;
            return null;
        }

        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
        String accId = req != null && req.requestURI != null
                ? req.requestURI.substringAfterLast('/')
                : null;
        if (String.isBlank(accId)) accId = (String) params.get('Id');

        if (String.isBlank(accId) || !isValidSalesforceId(accId)) {
            res.statusCode = 400;
            return null;
        }

        Account acc = new Account(Id = accId);
        Boolean hasUpdates = false;
        for (String key : params.keySet()) {
            if (key.equalsIgnoreCase('id')) continue;
            try {
                acc.put(key, params.get(key));
                hasUpdates = true;
            } catch (Exception e) { }
        }

        if (hasUpdates) update acc;

        List<Account> results = [SELECT Id, Name, Industry FROM Account WHERE Id = :accId WITH USER_MODE LIMIT 1];
        if (results.isEmpty()) {
            res.statusCode = 404;
            return null;
        }
        res.statusCode = 200;
        return results[0];
    }

    @TestVisible
    private static Boolean isValidSalesforceId(String candidateId) {
        if (String.isBlank(candidateId)) return false;
        Integer len = candidateId.length();
        if (len != 15 && len != 18) return false;
        try { Id.valueOf(candidateId); return true; } catch (Exception e) { return false; }
    }
}
