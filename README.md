# Apex API Studio

## Overview
Apex API Studio is a Salesforce-native toolkit that discovers, documents, and manages Apex REST APIs by generating OpenAPI (Swagger) specifications from Apex source and structured ApexDoc comments.

## Features
- Auto-discovery of classes and methods annotated with `@RestResource`.
- ApexDoc parser mapping structured comments to OpenAPI operations, parameters, and responses.
- In-app JSON editor (CodeMirror) with linting and themes.
- Embedded Swagger UI with optional auto-login for convenient exploration.
- Public Swagger UI hosted via a Salesforce Site (or Visualforce page) so external API consumers can browse and test published OpenAPI docs without logging into the org.
- Admin Lightning App (Apex API Studio) that allows org administrators to discover endpoints, generate OpenAPI descriptions, compare generated specs with saved metadata, and manage publishing.
- Side-by-side comparison of generated specs and saved metadata configurations.

## Getting Started
### Prerequisites
- Node.js (>=18)
- Salesforce CLI (`sf`) authenticated to your org
- A `codemirror` Static Resource containing CodeMirror v5 assets

### Install (development tools, optional)
```sh
npm install
```

### Deploy
- Deploy everything: `npm run deploy:all`
- Deploy core only: `npm run deploy:core`
- Deploy samples only: `npm run deploy:samples`

### Public API Explorer & Admin App
- The project includes a Swagger UI (served from a Visualforce page and optionally exposed through a Salesforce Site) so external API users can explore your published OpenAPI docs. Configure the Site's Guest User access carefully to expose only the intended API documentation and static assets.
- The included Lightning App (Apex API Studio) provides administrators with an interface to discover `@RestResource` endpoints, generate OpenAPI specs, preview them, and publish to the Site.

---
## 🚨 CRITICAL CONFIGURATION: Enable CORS for OAuth Endpoints 🚨

> **&#x26A0; IMPORTANT: ADMIN ACTION REQUIRED FOR OAUTH FUNCTIONALITY &#x26A0;**
> To ensure proper functionality of OAuth flows within the Swagger UI, especially when interacting with your Salesforce org's APIs, **you MUST enable "CORS for OAuth endpoints"**.

**Follow these steps:**
1.  Navigate to **Setup**.
2.  In the Quick Find box, search for and select **CORS**.
3.  In the "Cross-Origin Resource Sharing (CORS) Policy Settings" section, click **Edit**.
4.  **Enable** the checkbox for `Enable CORS for OAuth endpoints`.
5.  **Save** your changes.
---

## Screenshots
Below are screenshots showing the public Swagger UI and the Apex API Studio admin interface.

![Swagger UI on Site](images/swagger-site.png)
*Swagger UI exposed via Salesforce Site (public explorer).* 

![Apex API Studio - Admin App](images/swagger-app.png)
*Lightning App used by administrators to discover endpoints and generate OpenAPI descriptions.*

## ApexDoc Annotations
Use Javadoc-style tags above your `@RestResource` methods to control generated OpenAPI metadata. These comments are parsed to enrich your OpenAPI specification.

**Example:**

```apex
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
        // ... implementation ...
    }

    /**
     * @description Updates specific Account fields.
     * @param {String} id [path][required] The 15 or 18 character Salesforce ID of the account to update.
     * @param {
     *   name: string,
     *   industry: string
     * } accountBody The fields to update on the Account record.
     * @response 200 {Account} The updated Account record.
     * @response 400 {String} Error if Id is missing or invalid.
     */
    @HttpPatch
    global static Account updateAccount() {
        // ... implementation ...
    }
}
```

**Available Tags:**
- `@description` — operation summary
- `@path` — override the method path (e.g. `/accounts/{id}/details`)
- `@param {Type} name [flags] Description` — flags: `[path]`, `[query]`, `[required]`
- `@response {Code} {Type} Description`

## Development & Maintenance
- Ensure the `codemirror` Static Resource includes `lib/codemirror.js`, `mode/javascript/javascript.js`, lint addons, and a JSON validator (`jsonlint.js`).
- Formatting: `npm run format`
- Linting: `npm run lint`
- Unit tests: `npm test` (`sfdx-lwc-jest`)

## Contributing
Fork the repo, create a topic branch, and open a PR. Add or update unit tests when changing parsing or metadata generation logic.

## License & Support
- License: MIT — add or check the LICENSE file for details.
- Support: open an issue on the repository to report bugs or request features.