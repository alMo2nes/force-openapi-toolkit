/**
 * Test data factory for creating test records across test classes.
 * Centralizes test data creation to ensure consistency and reusability.
 */
@IsTest
public class TestDataFactory {

    /**
     * Creates a list of Account records.
     * 
     * @param numAccounts Number of accounts to create
     * @param doInsert Whether to insert the records (true) or return them without inserting (false)
     * @return List of Account records
     */
    public static List<Account> createAccounts(Integer numAccounts, Boolean doInsert) {
        List<Account> accounts = new List<Account>();
        
        for (Integer i = 0; i < numAccounts; i++) {
            Account acc = new Account(
                Name = 'Test Account ' + i,
                Industry = 'Technology',
                Phone = '555-000-' + String.valueOf(i).leftPad(4, '0'),
                Website = 'https://testaccount' + i + '.example.com',
                BillingStreet = i + ' Test Street',
                BillingCity = 'San Francisco',
                BillingState = 'CA',
                BillingPostalCode = '94105',
                BillingCountry = 'USA'
            );
            accounts.add(acc);
        }
        
        if (doInsert) {
            insert accounts;
        }
        
        return accounts;
    }

    /**
     * Creates a single Account record.
     * 
     * @param doInsert Whether to insert the record (true) or return it without inserting (false)
     * @return Account record
     */
    public static Account createAccount(Boolean doInsert) {
        List<Account> accounts = createAccounts(1, doInsert);
        return accounts[0];
    }

    /**
     * Creates a list of Account records with custom field values.
     * 
     * @param numAccounts Number of accounts to create
     * @param fieldValues Map of field API names to values to override defaults
     * @param doInsert Whether to insert the records (true) or return them without inserting (false)
     * @return List of Account records
     */
    public static List<Account> createAccountsWithFields(
        Integer numAccounts, 
        Map<String, Object> fieldValues, 
        Boolean doInsert
    ) {
        List<Account> accounts = createAccounts(numAccounts, false);
        
        // Apply custom field values to each account
        for (Account acc : accounts) {
            for (String fieldName : fieldValues.keySet()) {
                acc.put(fieldName, fieldValues.get(fieldName));
            }
        }
        
        if (doInsert) {
            insert accounts;
        }
        
        return accounts;
    }

    /**
     * Creates mock OpenApi_Endpoint__mdt records for testing.
     * Note: Custom Metadata cannot be inserted in tests, but this method
     * returns a list structure that can be used for mocking.
     * 
     * @return List of OpenApi_Endpoint__mdt records (not inserted)
     */
    public static List<OpenApi_Endpoint__mdt> createOpenApiEndpoints() {
        List<OpenApi_Endpoint__mdt> endpoints = new List<OpenApi_Endpoint__mdt>();
        
        // Sample endpoint 1
        OpenApi_Endpoint__mdt endpoint1 = new OpenApi_Endpoint__mdt(
            DeveloperName = 'Test_Endpoint_1',
            MasterLabel = 'Test Endpoint 1',
            Path__c = '/api/v1/test',
            Http_Method__c = 'GET',
            Active__c = true,
            Version__c = '1.0',
            Deprecated__c = false,
            Spec__c = '{"summary":"Test endpoint","responses":{"200":{"description":"Success","content":{"application/json":{"schema":{"type":"object"}}}}}}'
        );
        endpoints.add(endpoint1);
        
        // Sample endpoint 2 (deprecated version)
        OpenApi_Endpoint__mdt endpoint2 = new OpenApi_Endpoint__mdt(
            DeveloperName = 'Test_Endpoint_2',
            MasterLabel = 'Test Endpoint 2',
            Path__c = '/api/v1/test',
            Http_Method__c = 'GET',
            Active__c = true,
            Version__c = '0.9',
            Deprecated__c = true,
            Spec__c = '{"summary":"Test endpoint (old)","responses":{"200":{"description":"Success","content":{"application/json":{"schema":{"type":"object"}}}}}}'
        );
        endpoints.add(endpoint2);
        
        // Sample endpoint 3 (POST)
        OpenApi_Endpoint__mdt endpoint3 = new OpenApi_Endpoint__mdt(
            DeveloperName = 'Test_Endpoint_3',
            MasterLabel = 'Test Endpoint 3',
            Path__c = '/api/v1/create',
            Http_Method__c = 'POST',
            Active__c = true,
            Version__c = '1.0',
            Deprecated__c = false,
            Spec__c = '{"summary":"Create endpoint","responses":{"201":{"description":"Created","content":{"application/json":{"schema":{"type":"object"}}}}}}'
        );
        endpoints.add(endpoint3);
        
        return endpoints;
    }

    /**
     * Creates a list of Contact records associated with an Account.
     * 
     * @param accountId The Account ID to associate contacts with
     * @param numContacts Number of contacts to create
     * @param doInsert Whether to insert the records (true) or return them without inserting (false)
     * @return List of Contact records
     */
    public static List<Contact> createContacts(Id accountId, Integer numContacts, Boolean doInsert) {
        List<Contact> contacts = new List<Contact>();
        
        for (Integer i = 0; i < numContacts; i++) {
            Contact con = new Contact(
                AccountId = accountId,
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                Email = 'testcontact' + i + '@example.com',
                Phone = '555-111-' + String.valueOf(i).leftPad(4, '0')
            );
            contacts.add(con);
        }
        
        if (doInsert) {
            insert contacts;
        }
        
        return contacts;
    }

    /**
     * Creates a list of Opportunity records associated with an Account.
     * 
     * @param accountId The Account ID to associate opportunities with
     * @param numOpportunities Number of opportunities to create
     * @param doInsert Whether to insert the records (true) or return them without inserting (false)
     * @return List of Opportunity records
     */
    public static List<Opportunity> createOpportunities(
        Id accountId, 
        Integer numOpportunities, 
        Boolean doInsert
    ) {
        List<Opportunity> opportunities = new List<Opportunity>();
        
        for (Integer i = 0; i < numOpportunities; i++) {
            Opportunity opp = new Opportunity(
                AccountId = accountId,
                Name = 'Test Opportunity ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Amount = 10000 + (i * 1000)
            );
            opportunities.add(opp);
        }
        
        if (doInsert) {
            insert opportunities;
        }
        
        return opportunities;
    }

    /**
     * Creates a User record for testing.
     * 
     * @param profileName The profile name to assign to the user
     * @param doInsert Whether to insert the record (true) or return it without inserting (false)
     * @return User record
     */
    public static User createUser(String profileName, Boolean doInsert) {
        Profile profile = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        
        String uniqueUserName = 'testuser' + DateTime.now().getTime() + '@testorg.com';
        
        User testUser = new User(
            Alias = 'tuser',
            Email = 'testuser@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = uniqueUserName
        );
        
        if (doInsert) {
            insert testUser;
        }
        
        return testUser;
    }
}