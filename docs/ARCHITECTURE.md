# Architecture

## Overview

The project follows a Salesforce-native layered approach:

1. **Presentation layer:** Lightning Web Components render forms, lists, filters, action buttons, and status updates.
2. **Application/controller layer:** Apex controllers expose operations to LWCs with `@AuraEnabled` methods.
3. **Business service layer:** Apex services implement background or reusable business behavior, including vendor assignment and lease reminders.
4. **Data layer:** Salesforce custom objects and fields store property, tenant, lease, maintenance, vendor, image-staging, and reminder-log records.
5. **Platform automation:** Apex trigger and scheduled/batch Apex provide event-driven assignment and scheduled reminder processing.

## Component map

| User workflow | LWC | Apex entry point / service | Primary records |
|---|---|---|---|
| Browse/filter properties | `propertyExplorer` | `PropertyController` | `Property__c` |
| Map property locations | `propertyLocationMap` | Confirm controller/data source in component source before deployment | `Property__c` and location fields |
| Manage tenants | `tenantManagement` | `TenantController` | `Tenant__c` |
| Manage lease agreements | `leaseAgreementManagement` | `LeaseAgreementController` | `Lease_Agreement__c`, `Tenant__c`, `Property__c` |
| Download/email lease PDF | `leaseAgreementActions` | `LeaseAgreementPdfController` | `Lease_Agreement__c`, tenant email |
| Manage maintenance | `maintenanceRequestManager` | `MaintenanceController` | `Maintenance_Request__c`, `Vendor__c`, `Property__c` |
| Assign vendor on insert | Trigger + service | `MaintenanceRequestTrigger`, `MaintenanceVendorAssignmentService` | `Maintenance_Request__c`, `Vendor__c` |
| Remind about lease expiry | Scheduled/batch Apex | `LeaseExpiryReminderScheduler`, `LeaseExpiryReminderService` | `Lease_Agreement__c`, `Tenant__c`, `Lease_Reminder_Log__c` |

## Design principles

- Keep user-interface code in LWC and server-side operations in Apex.
- Use Salesforce record IDs as references rather than hard-coded IDs.
- Validate user inputs before performing DML.
- Use bulk-safe Apex patterns for trigger-driven work.
- Use reminder logs to support idempotency and auditability.
- Use `WITH USER_MODE` in the PDF controller queries to respect user access.
- Keep setup and deployment reproducible through Salesforce DX source and Git.

## Runtime flows

### Lease PDF

1. User opens a Lease Agreement record and invokes the LWC action.
2. LWC loads the jsPDF static resource.
3. LWC calls `getLeaseDetails` to retrieve lease, tenant and property details.
4. LWC renders a PDF in the browser.
5. Download action saves the PDF locally; email action sends the Base64 PDF to `sendLeasePdfEmail`.
6. Apex validates inputs and tenant email, decodes the PDF, checks attachment size, and sends the email.

### Maintenance vendor assignment

1. A `Maintenance_Request__c` record is inserted without an explicitly selected vendor.
2. `MaintenanceRequestTrigger` calls `MaintenanceVendorAssignmentService`.
3. The service identifies eligible active vendors and assigns a vendor according to its current workload logic.
4. The saved maintenance request retains the selected vendor.

### Lease-expiry reminder

1. `LeaseExpiryReminderScheduler` starts `LeaseExpiryReminderService`.
2. The service finds eligible leases based on configured expiry windows and reminder history.
3. Reminder messages are attempted and corresponding log records are used to avoid repeated reminders.
4. Validate exact timing, picklist values and duplicate-key behavior against the current service implementation and target-org metadata before production use.
