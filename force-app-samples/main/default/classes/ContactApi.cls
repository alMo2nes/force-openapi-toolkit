/**
 * @description Dummy REST API for Contact management.
 */
@RestResource(urlMapping='/v1/contacts/*')
global with sharing class ContactApi {

    /**
     * @description Fetches a contact by ID.
     * @param {String} contactId [path] The Salesforce ID of the contact.
     * @response 200 {Contact} Contact details.
     * @response 404 Contact not found.
     */
    @HttpGet
    global static Contact getContact() {
        RestRequest req = RestContext.request;
        String contactId = req.requestURI.substringAfterLast('/');
        try {
            return [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Id = :contactId WITH USER_MODE LIMIT 1];
        } catch (Exception e) {
            RestContext.response.statusCode = 404;
            return null;
        }
    }

    /**
     * @description Creates a new contact.
     * @param {FirstName: string, LastName: string, Email: string} contactBody JSON details for the new contact.
     * @response 201 {Contact} The newly created contact.
     */
    @HttpPost
    global static Contact createContact() {
        RestRequest req = RestContext.request;
        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
        Contact c = new Contact(
            FirstName = (String)params.get('FirstName'),
            LastName = (String)params.get('LastName'),
            Email = (String)params.get('Email')
        );
        insert as user c;
        RestContext.response.statusCode = 201;
        return c;
    }
}
