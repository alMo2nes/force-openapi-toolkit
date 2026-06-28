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

## Screenshots
Below are screenshots showing the public Swagger UI and the Apex API Studio admin interface.

![Swagger UI on Site](images/swagger-site.png)
*Swagger UI exposed via Salesforce Site (public explorer).* 

![Apex API Studio - Admin App](images/swagger-app.png)
*Lightning App used by administrators to discover endpoints and generate OpenAPI descriptions.*

## ApexDoc Annotations
Use Javadoc-style tags above your `@RestResource` methods to control generated OpenAPI metadata:
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
