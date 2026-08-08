/**
 * Created by minas on 02/08/2026.
 */

global without sharing class PostInstallHandler implements InstallHandler {

    // Permission Set API Names
    @TestVisible
    private static final String ADMIN_PERMISSION_SET = 'Force_OpenApi_Toolkit_Admin';
    @TestVisible
    private static final String GUEST_PERMISSION_SET = 'Force_OpenApi_Toolkit_Guest';
    private static final String SWAGGER_SITE_NAME = 'Swagger_UI';
    @TestVisible
    private static Id guestUserId;
    global void onInstall(InstallContext context) {

        assignAdminPermissionSet();
        assignGuestPermissionSet();

    }

    /**
     * Assign the admin permission set to all System Administrators.
     */
    @TestVisible
    private static void assignAdminPermissionSet() {

        PermissionSet ps = getPermissionSet(ADMIN_PERMISSION_SET);

        if (ps == null) {
            System.debug('Permission Set not found: ' + ADMIN_PERMISSION_SET);
            return;
        }

        Set<Id> adminIds = new Set<Id>();

        for (User u : [
                SELECT Id
                FROM User
                WHERE IsActive = true
                AND Profile.PermissionsModifyAllData = true
        ]) {
            adminIds.add(u.Id);
        }

        if (adminIds.isEmpty()) {
            return;
        }

        Set<Id> alreadyAssigned = new Set<Id>();

        for (PermissionSetAssignment psa : [
                SELECT AssigneeId
                FROM PermissionSetAssignment
                WHERE PermissionSetId = :ps.Id
                AND AssigneeId IN :adminIds
        ]) {
            alreadyAssigned.add(psa.AssigneeId);
        }

        List<PermissionSetAssignment> inserts = new List<PermissionSetAssignment>();

        for (Id userId : adminIds) {
            if (!alreadyAssigned.contains(userId)) {
                inserts.add(new PermissionSetAssignment(
                        AssigneeId = userId,
                        PermissionSetId = ps.Id
                ));
            }
        }

        if (!inserts.isEmpty()) {
            insert inserts;
        }
    }

    /**
     * Assign the guest permission set to every Site Guest User.
     */
    @TestVisible
    private static void assignGuestPermissionSet() {

        PermissionSet ps = getPermissionSet(GUEST_PERMISSION_SET);

        if (ps == null) {
            System.debug('Permission Set not found: ' + GUEST_PERMISSION_SET);
            return;
        }

        List<Site> sites = [
                    SELECT Id, GuestUserId
                    FROM Site
                    WHERE Name = :SWAGGER_SITE_NAME
            ];


        if (sites.isEmpty()) {
            return;
        }

        guestUserId = Test.isRunningTest() ? UserInfo.getUserId() : sites[0].GuestUserId;

        Set<Id> alreadyAssigned = new Set<Id>();

        for (PermissionSetAssignment psa : [
                SELECT AssigneeId
                FROM PermissionSetAssignment
                WHERE PermissionSetId = :ps.Id
                AND AssigneeId = :guestUserId
        ]) {
            alreadyAssigned.add(psa.AssigneeId);
        }

        List<PermissionSetAssignment> inserts = new List<PermissionSetAssignment>();

        if (!alreadyAssigned.contains(guestUserId)) {
            inserts.add(new PermissionSetAssignment(
                    AssigneeId = guestUserId,
                    PermissionSetId = ps.Id
            ));
        }

        if (!inserts.isEmpty()) {
            insert inserts;
        }
    }

    @TestVisible
    private static PermissionSet getPermissionSet(String apiName) {

        List<PermissionSet> ps = [
                SELECT Id
                FROM PermissionSet
                WHERE Name = :apiName
                LIMIT 1
        ];

        return ps.isEmpty() ? null : ps[0];
    }
}