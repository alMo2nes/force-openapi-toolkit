/**
 * SessionService
 *
 * Workaround to retrieve a full API-enabled Session ID from a Visualforce context,
 * which allows Tooling API calls from LWC/Aura controllers.
 */
public with sharing class SessionService {

    /**
     * Fetches a valid Session ID by scraping a hidden Visualforce page.
     */
    public static String getSessionId() {
        if (Test.isRunningTest()) return 'test-session-id';

        // This page contains only {!$Api.Session_ID}
        PageReference bridge = Page.SessionBridge;
        String content;

        try {
            content = bridge.getContent().toString();
        } catch (Exception e) {
            // Fallback for contexts where getContent() is restricted
            return UserInfo.getSessionId();
        }

        // Visualforce output usually contains whitespace or extra characters, clean it
        return content.trim();
    }
}