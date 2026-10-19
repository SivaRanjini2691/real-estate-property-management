# Technical Implementation Document (TID)

## 1. Document purpose

This TID explains how the Real Estate Property Management application is implemented in Salesforce source. It complements `TDD.md`, which records design choices and technical behavior.

## 2. Scope

Included in the reviewed source package:
- Property exploration and property image staging/finalization.
- Tenant management.
- Lease agreement management.
- Lease PDF download and email.
- Maintenance request management and vendor assignment.
- Lease-expiry reminder processing and reminder logging.

Not asserted as complete without additional org verification:
- Production report/dashboard configuration.
- External payment, mapping, SMS, or middleware integrations.
- Production deployment, monitoring, and operational alerting.

## 3. Implementation inventory

| Area | Implementation artifacts | Responsibility |
|---|---|---|
| Property | `PropertyController`, `propertyExplorer`, `propertyLocationMap`, `Property_Image_Staging__c` | Property retrieval/filtering, staging/finalization and map presentation |
| Tenant | `TenantController`, `tenantManagement` | Tenant data operations and UI |
| Lease | `LeaseAgreementController`, `leaseAgreementManagement` | Lease agreement data operations and UI |
| Lease PDF | `LeaseAgreementPdfController`, `leaseAgreementActions`, `jspdf` static resource | Retrieve lease details, generate client-side PDF, download or email attachment |
| Maintenance | `MaintenanceController`, `maintenanceRequestManager` | Create/query/update maintenance requests |
| Vendor assignment | `MaintenanceRequestTrigger`, `MaintenanceVendorAssignmentService` | Assign vendor during before-insert processing |
| Expiry reminders | `LeaseExpiryReminderScheduler`, `LeaseExpiryReminderService`, `Lease_Reminder_Log__c` | Scheduled/batch reminder processing and reminder history |

## 4. Apex implementation notes

### Controllers

Controllers expose UI-facing operations to Lightning components using `@AuraEnabled` methods. Input validation and exception handling should be reviewed for every public entry point.

`LeaseAgreementPdfController`:
- `getLeaseDetails(Id leaseId)` returns lease details, tenant name/email, property name, rent, dates, status and terms.
- `sendLeasePdfEmail(Id leaseId, String pdfBase64)` validates required inputs, queries the lease in user mode, checks tenant email, decodes Base64 data, enforces an attachment-size threshold, and sends a `Messaging.SingleEmailMessage`.

### Vendor assignment

`MaintenanceRequestTrigger` runs before insert and delegates to `MaintenanceVendorAssignmentService`. Keep the trigger thin and test assignment behavior with single and bulk inserts, explicitly assigned vendors, inactive vendors, and no eligible vendor conditions.

### Reminder processing

`LeaseExpiryReminderScheduler` starts the reminder service. `LeaseExpiryReminderService` processes qualifying lease records and uses `Lease_Reminder_Log__c` to record reminder history. Before production scheduling, validate:
- reminder windows and timezone expectations;
- exact restricted picklist values;
- duplicate-prevention behavior under retries and concurrent runs;
- handling of missing tenant email and failed email sends;
- batch size and governor-limit behavior.

## 5. Lightning Web Components

- `propertyExplorer`: property search/exploration UI.
- `propertyLocationMap`: property map presentation.
- `tenantManagement`: tenant management UI.
- `leaseAgreementManagement`: lease management UI.
- `leaseAgreementActions`: PDF generation, download and email actions.
- `maintenanceRequestManager`: maintenance request management UI.

Component public properties, targets, labels and page availability are defined in each component's `*.js-meta.xml`. Confirm Lightning page placement and user access in the target org.

## 6. Validation and security

- Enforce object, field and record access. The PDF controller uses `WITH USER_MODE` for its queries.
- Validate all inputs on the server, even if the LWC validates them first.
- Use generic UI-safe exception messages; avoid exposing stack traces or sensitive details.
- Restrict access to tenant contact information and lease terms.
- Verify email deliverability and authorized sender configuration before testing email features.
- Never hard-code org-specific record IDs.

## 7. Configuration

- Salesforce DX project configuration is in `sfdx-project.json`.
- jsPDF is loaded from a Salesforce Static Resource named `jspdf`.
- The deployment target is selected with the CLI org alias, such as `RealEstateDev`; do not embed credentials in source.
- Custom object, field, relationship, validation-rule and picklist definitions are stored under `force-app/main/default/objects`.

## 8. Implementation acceptance checklist

- [ ] All required metadata deploys successfully.
- [ ] No unresolved Apex action imports in LWC.
- [ ] Apex tests pass in the intended org.
- [ ] Coverage is reviewed per class, not only org-wide.
- [ ] Restricted picklist values align with Apex values.
- [ ] LWC components are exposed only on intended page types.
- [ ] CRUD/FLS/record access is verified with representative users.
- [ ] Email and scheduled jobs are tested in a sandbox.
- [ ] Documentation matches the actual deployed source and org configuration.
