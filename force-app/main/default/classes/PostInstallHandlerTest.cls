/**
 * Created by minas on 02/08/2026.
 */

/**
 * Test class for PostInstallHandler
 */
@IsTest
private class PostInstallHandlerTest {

    private static final String ADMIN_PERMISSION_SET =
            'Force_OpenApi_Toolkit_Admin';

    private static final String GUEST_PERMISSION_SET =
            'Force_OpenApi_Toolkit_Guest';


    @TestSetup
    static void setupData() {

        Profile adminProfile = [
                SELECT Id
                FROM Profile
                WHERE PermissionsModifyAllData = true
                LIMIT 1
        ];

        User adminUser = new User(
                Alias = 'tadmin',
                Email = 'test.admin@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Test Admin',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = adminProfile.Id,
                TimeZoneSidKey = 'America/New_York',
                UserName = 'test.admin.' + System.currentTimeMillis() + '@example.com'
        );

        insert adminUser;
    }


    @IsTest
    static void testAdminPermissionAssignment() {

        User adminUser = [
                SELECT Id
                FROM User
                WHERE Alias = 'tadmin'
                LIMIT 1
        ];


        System.runAs(adminUser) {

            Test.startTest();

            PostInstallHandler.assignAdminPermissionSet();

            Test.stopTest();
        }


        PermissionSet adminPermissionSet = [
                SELECT Id
                FROM PermissionSet
                WHERE Name = :ADMIN_PERMISSION_SET
                LIMIT 1
        ];


        PermissionSetAssignment assignment = [
                SELECT Id, AssigneeId, PermissionSetId
                FROM PermissionSetAssignment
                WHERE AssigneeId = :adminUser.Id
                AND PermissionSetId = :adminPermissionSet.Id
                LIMIT 1
        ];


        System.assertNotEquals(
                null,
                assignment,
                'Admin permission set should be assigned'
        );

        System.assertEquals(
                adminUser.Id,
                assignment.AssigneeId
        );
    }


    @IsTest
    static void testGuestPermissionAssignment() {

        Test.startTest();

        PostInstallHandler.assignGuestPermissionSet();

        Test.stopTest();


        PermissionSet guestPermissionSet = [
                SELECT Id
                FROM PermissionSet
                WHERE Name = :GUEST_PERMISSION_SET
                LIMIT 1
        ];


        PermissionSetAssignment assignment = [
                SELECT Id, AssigneeId, PermissionSetId
                FROM PermissionSetAssignment
                WHERE AssigneeId = :UserInfo.getUserId()
                AND PermissionSetId = :guestPermissionSet.Id
                LIMIT 1
        ];


        System.assertNotEquals(
                null,
                assignment,
                'Guest permission set should be assigned'
        );


        System.assertEquals(
                UserInfo.getUserId(),
                assignment.AssigneeId,
                'During tests the guest assignment should use the running user'
        );
    }


    @IsTest
    static void testPostInstallExecution() {

        Test.startTest();

        Test.testInstall(
                new PostInstallHandler(),
                null
        );

        Test.stopTest();


        PermissionSet adminPermissionSet = [
                SELECT Id
                FROM PermissionSet
                WHERE Name = :ADMIN_PERMISSION_SET
                LIMIT 1
        ];


        Integer adminAssignments = [
                SELECT COUNT()
                FROM PermissionSetAssignment
                WHERE PermissionSetId = :adminPermissionSet.Id
        ];


        System.assert(
                adminAssignments > 0,
                'At least one admin should receive the admin permission set'
        );
    }


    @IsTest
    static void testNoDuplicateAssignment() {

        Test.startTest();

        PostInstallHandler.assignGuestPermissionSet();
        PostInstallHandler.assignGuestPermissionSet();

        Test.stopTest();


        PermissionSet guestPermissionSet = [
                SELECT Id
                FROM PermissionSet
                WHERE Name = :GUEST_PERMISSION_SET
                LIMIT 1
        ];


        Integer countAssignments = [
                SELECT COUNT()
                FROM PermissionSetAssignment
                WHERE AssigneeId = :UserInfo.getUserId()
                AND PermissionSetId = :guestPermissionSet.Id
        ];


        System.assertEquals(
                1,
                countAssignments,
                'Permission set should not be assigned twice'
        );
    }
}