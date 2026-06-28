/**
 * Test class for AccountApi REST resource.
 * Validates account retrieval, error handling, and edge cases.
 */
@IsTest
private class AccountApiTest {

    @TestSetup
    static void setupTestData() {
        List<Account> accounts = TestDataFactory.createAccounts(3, true);
    }

    /**
     * Tests successful account retrieval with valid 18-character ID
     */
    @IsTest
    static void shouldReturnAccount_WhenValidId18() {
        // Given
        Account testAccount = [SELECT Id, Name, Industry FROM Account LIMIT 1];
        String accountId18 = String.valueOf(testAccount.Id);

        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/v1/accounts/' + accountId18;
        RestContext.request = request;
        RestContext.response = new RestResponse();

        // When
        Test.startTest();
        Account result = AccountApi.getAccount();
        Test.stopTest();

        // Then
        Assert.areEqual(testAccount.Id, result.Id, 'Should return the correct account');
        Assert.areEqual(testAccount.Name, result.Name, 'Account name should match');
        Assert.areEqual(200, RestContext.response.statusCode, 'Should return 200 status code');
    }

    /**
     * Tests successful account retrieval with valid 15-character ID
     */
    @IsTest
    static void shouldReturnAccount_WhenValidId15() {
        // Given
        Account testAccount = [SELECT Id, Name, Industry FROM Account LIMIT 1];
        String accountId15 = String.valueOf(testAccount.Id).substring(0, 15);

        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/v1/accounts/' + accountId15;
        RestContext.request = request;
        RestContext.response = new RestResponse();

        // When
        Test.startTest();
        Account result = AccountApi.getAccount();
        Test.stopTest();

        // Then
        Assert.areEqual(testAccount.Id, result.Id, 'Should return the correct account');
        Assert.areEqual(200, RestContext.response.statusCode, 'Should return 200 status code');
    }

    /**
     * Tests error handling when account ID is null
     */
    @IsTest
    static void shouldReturn400_WhenIdIsNull() {
        // Given
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/v1/accounts/';
        RestContext.request = request;
        RestContext.response = new RestResponse();

        // When
        Test.startTest();
        Account result = AccountApi.getAccount();
        Test.stopTest();

        // Then
        Assert.isNull(result, 'Should return null');
        Assert.areEqual(400, RestContext.response.statusCode, 'Should return 400 status code');
        String responseBody = RestContext.response.responseBody.toString();
        Assert.isTrue(responseBody.contains('Account Id is required'), 
            'Response should indicate missing ID');
    }

    /**
     * Tests error handling when account ID is empty string
     */
    @IsTest
    static void shouldReturn400_WhenIdIsEmpty() {
        // Given
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/v1/accounts/   ';
        RestContext.request = request;
        RestContext.response = new RestResponse();

        // When
        Test.startTest();
        Account result = AccountApi.getAccount();
        Test.stopTest();

        // Then
        Assert.isNull(result, 'Should return null');
        Assert.areEqual(400, RestContext.response.statusCode, 'Should return 400 status code');
        String responseBody = RestContext.response.responseBody.toString();
        Assert.isTrue(responseBody.contains('Account Id is required'), 
            'Response should indicate missing ID');
    }

    /**
     * Tests error handling when account ID format is invalid
     */
    @IsTest
    static void shouldReturn400_WhenIdFormatInvalid() {
        // Given
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/v1/accounts/INVALID123';
        RestContext.request = request;
        RestContext.response = new RestResponse();

        // When
        Test.startTest();
        Account result = AccountApi.getAccount();
        Test.stopTest();

        // Then
        Assert.isNull(result, 'Should return null');
        Assert.areEqual(400, RestContext.response.statusCode, 'Should return 400 status code');
        String responseBody = RestContext.response.responseBody.toString();
        Assert.isTrue(responseBody.contains('Account Id is required'), 
            'Response should indicate invalid ID');
    }

    /**
     * Tests error handling when account ID has wrong length
     */
    @IsTest
    static void shouldReturn400_WhenIdLengthInvalid() {
        // Given
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/v1/accounts/001234567890';
        RestContext.request = request;
        RestContext.response = new RestResponse();

        // When
        Test.startTest();
        Account result = AccountApi.getAccount();
        Test.stopTest();

        // Then
        Assert.isNull(result, 'Should return null');
        Assert.areEqual(400, RestContext.response.statusCode, 'Should return 400 status code');
    }

    /**
     * Tests error handling when account is not found
     */
    @IsTest
    static void shouldReturn404_WhenAccountNotFound() {
        // Given
        String nonExistentId = '001000000000000AAA';

        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/v1/accounts/' + nonExistentId;
        RestContext.request = request;
        RestContext.response = new RestResponse();

        // When
        Test.startTest();
        Account result = AccountApi.getAccount();
        Test.stopTest();

        // Then
        Assert.isNull(result, 'Should return null');
        Assert.areEqual(404, RestContext.response.statusCode, 'Should return 404 status code');
        String responseBody = RestContext.response.responseBody.toString();
        Assert.isTrue(responseBody.contains('Account not found'), 
            'Response should indicate account not found');
    }

    /**
     * Tests isValidSalesforceId with null input
     */
    @IsTest
    static void isValidSalesforceId_ShouldReturnFalse_WhenNull() {
        // When
        Test.startTest();
        Boolean result = AccountApi.isValidSalesforceId(null);
        Test.stopTest();

        // Then
        Assert.isFalse(result, 'Should return false for null ID');
    }

    /**
     * Tests isValidSalesforceId with empty string
     */
    @IsTest
    static void isValidSalesforceId_ShouldReturnFalse_WhenEmpty() {
        // When
        Test.startTest();
        Boolean result = AccountApi.isValidSalesforceId('');
        Test.stopTest();

        // Then
        Assert.isFalse(result, 'Should return false for empty string');
    }

    /**
     * Tests isValidSalesforceId with valid 15-character ID
     */
    @IsTest
    static void isValidSalesforceId_ShouldReturnTrue_WhenValid15Char() {
        // Given
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        String accountId15 = String.valueOf(testAccount.Id).substring(0, 15);

        // When
        Test.startTest();
        Boolean result = AccountApi.isValidSalesforceId(accountId15);
        Test.stopTest();

        // Then
        Assert.isTrue(result, 'Should return true for valid 15-character ID');
    }

    /**
     * Tests isValidSalesforceId with valid 18-character ID
     */
    @IsTest
    static void isValidSalesforceId_ShouldReturnTrue_WhenValid18Char() {
        // Given
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        String accountId18 = String.valueOf(testAccount.Id);

        // When
        Test.startTest();
        Boolean result = AccountApi.isValidSalesforceId(accountId18);
        Test.stopTest();

        // Then
        Assert.isTrue(result, 'Should return true for valid 18-character ID');
    }

    /**
     * Tests isValidSalesforceId with invalid format
     */
    @IsTest
    static void isValidSalesforceId_ShouldReturnFalse_WhenInvalidFormat() {
        // When
        Test.startTest();
        Boolean result = AccountApi.isValidSalesforceId('INVALID_ID_123');
        Test.stopTest();

        // Then
        Assert.isFalse(result, 'Should return false for invalid format');
    }

    /**
     * Tests that response has correct Content-Type header for error responses
     */
    @IsTest
    static void shouldSetContentTypeHeader_WhenError() {
        // Given
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/v1/accounts/INVALID';
        RestContext.request = request;
        RestContext.response = new RestResponse();

        // When
        Test.startTest();
        AccountApi.getAccount();
        Test.stopTest();

        // Then
        Map<String, String> headers = RestContext.response.headers;
        Assert.isTrue(headers.containsKey('Content-Type'), 
            'Should include Content-Type header');
        Assert.areEqual('application/json; charset=UTF-8', headers.get('Content-Type'),
            'Content-Type should be application/json with UTF-8');
    }

    /**
     * Tests bulk account retrieval - validates multiple sequential calls
     */
    @IsTest
    static void shouldHandleMultipleRequests_WhenCalledSequentially() {
        // Given
        List<Account> accounts = [SELECT Id FROM Account LIMIT 3];

        // When
        Test.startTest();
        for (Account acc : accounts) {
            RestRequest request = new RestRequest();
            request.requestURI = '/services/apexrest/v1/accounts/' + acc.Id;
            RestContext.request = request;
            RestContext.response = new RestResponse();
            
            Account result = AccountApi.getAccount();
            
            // Then (inline assertion per iteration)
            Assert.areEqual(acc.Id, result.Id, 
                'Should return correct account for ID: ' + acc.Id);
            Assert.areEqual(200, RestContext.response.statusCode, 
                'Should return 200 for valid ID: ' + acc.Id);
        }
        Test.stopTest();
    }
}