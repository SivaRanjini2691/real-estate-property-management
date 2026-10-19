# Real Estate Property Management on Salesforce

A Salesforce DX portfolio project for managing properties, tenants, lease agreements, maintenance requests, vendor assignment, and lease-expiry reminders. The repository also contains Lightning Web Components (LWCs) for user-facing workflows and Apex controllers/services for server-side operations.

> **Documentation status:** This documentation is based on the Salesforce source ZIP reviewed for this project. Features are described as implemented only where supported by the source files. Reports, dashboards, external integrations, and production readiness must be validated in the target org before being represented as complete.

## Main capabilities represented in source

- Property browsing and filtering through `propertyExplorer` and `PropertyController`.
- Property image staging/finalization through `PropertyController` and `Property_Image_Staging__c`.
- Tenant management through `tenantManagement` and `TenantController`.
- Lease agreement management through `leaseAgreementManagement` and `LeaseAgreementController`.
- Lease agreement PDF generation/download and tenant email delivery through `leaseAgreementActions`, `LeaseAgreementPdfController`, and the `jspdf` static resource.
- Maintenance request management through `maintenanceRequestManager` and `MaintenanceController`.
- Automatic vendor assignment through `MaintenanceRequestTrigger` and `MaintenanceVendorAssignmentService`.
- Lease-expiry reminders through `LeaseExpiryReminderService`, `LeaseExpiryReminderScheduler`, and `Lease_Reminder_Log__c`.

## Technology stack

- Salesforce Platform / Salesforce DX
- Apex
- Lightning Web Components (LWC)
- Salesforce custom objects, fields, validation rules, and relationships
- Salesforce CLI (`sf`)
- Git and GitHub
- jsPDF loaded as a Salesforce Static Resource

## Repository structure

```text
force-app/main/default/
├── classes/          # Apex controllers, services, schedulers and tests
├── lwc/              # Lightning Web Components and Jest tests
├── objects/          # Custom objects, fields, relationships and validation rules
├── staticresources/  # Third-party static resources such as jsPDF
├── triggers/          # Apex triggers
└── ...
docs/
├── ARCHITECTURE.md
├── DATA_MODEL.md
├── TID.md
├── TDD.md
├── TESTING.md
├── DEPLOYMENT.md
└── USER_GUIDE.md
```

## Setup

### Prerequisites

1. Salesforce CLI installed.
2. VS Code with Salesforce extensions (recommended).
3. Access to a Salesforce org where you are authorized to deploy metadata.
4. Git installed.
5. The repository cloned locally.

### Authenticate and check org alias

```powershell
sf org login web --alias RealEstateDev
sf org display --target-org RealEstateDev
```

If the alias is already configured, do not log in again unless authentication has expired.

### Deploy the source

From the project root:

```powershell
sf project deploy start --source-dir force-app/main/default --target-org RealEstateDev --wait 30
```

Review the deployment output. Resolve compilation, metadata dependency, validation-rule, permission, or picklist errors before proceeding.

## Run Apex tests

Run local tests with coverage:

```powershell
sf apex run test `
  --target-org RealEstateDev `
  --test-level RunLocalTests `
  --code-coverage `
  --result-format human `
  --wait 30
```

The command's output is the source of truth for test pass/fail status and reported coverage. Do not claim a coverage percentage in project materials unless it has been measured in the target org.

To run selected tests, use the Salesforce CLI help for the installed version:

```powershell
sf apex run test --help
```

## Git workflow

Review all changes before staging:

```powershell
git status
git diff
```

Stage application source and documentation:

```powershell
git add force-app docs README.md sfdx-project.json
git status
git diff --cached --stat
```

Commit and push:

```powershell
git commit -m "Document real estate property management project"
git push origin main
```

If the push is rejected because the remote has commits you do not have, do not force-push. Fetch and reconcile the branches first.

## Security and configuration

- Never commit passwords, access tokens, private keys, session IDs, or org authentication files.
- Review `.gitignore` and `.forceignore` before committing.
- Apex methods using `WITH USER_MODE` require the running user to have suitable object, field, and record access.
- Validate profile/permission-set access and Lightning page placement in the target org.
- Verify org email deliverability before testing PDF email delivery.

## Documentation index

- [Architecture](docs/ARCHITECTURE.md)
- [Data Model](docs/DATA_MODEL.md)
- [Technical Implementation Document (TID)](docs/TID.md)
- [Technical Design Document (TDD)](docs/TDD.md)
- [Testing Strategy](docs/TESTING.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [User Guide](docs/USER_GUIDE.md)

## Known validation items

Before presenting the project as production-ready, validate the following in the target org:

- Full Apex test run is green.
- Every project Apex class has suitable test coverage and meaningful assertions.
- `LeaseAgreementPdfController` is deployed and its LWC imports resolve.
- Reminder picklist values match the values written by `LeaseExpiryReminderService`.
- Scheduler is scheduled only once per intended org/environment.
- Vendor assignment is tested for single and bulk request inserts.
- Required fields, validation rules, record access, and email deliverability are verified.
- Reports, dashboards, and any integrations are documented only after confirming their metadata/configuration exists.
