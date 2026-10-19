# User Guide

This guide describes the main UI areas present in the source. Exact navigation depends on Lightning page assignments and app configuration in the target org.

## Property exploration

1. Open the page where `propertyExplorer` is placed.
2. Browse available property records and use the provided search/filter controls.
3. Open a property record for its details.
4. If the map component is placed on the page, use it to view location information available to the component.

## Tenant management

1. Open the page containing `tenantManagement`.
2. Use the component's supported list/search and data-entry actions.
3. Provide required tenant information.
4. Save and confirm the record appears in the results.

The exact required fields are governed by object metadata, validation rules and the UI.

## Lease agreement management

1. Open the page containing `leaseAgreementManagement`.
2. Choose the tenant and property.
3. Enter the agreed rent, start date, end date, status and lease terms.
4. Save the lease.
5. Ensure the end date is later than the start date and required terms are supplied.

## Download a lease PDF

1. Open a Lease Agreement record.
2. Use the page action/component provided by `leaseAgreementActions`.
3. Select the download action.
4. The component retrieves authorized lease data and creates a PDF in the browser.
5. Check the downloaded PDF before sharing it.

## Email a lease PDF

1. Open the correct Lease Agreement record.
2. Use the email action in `leaseAgreementActions`.
3. Confirm the related tenant has a valid email address.
4. Wait for the success or error toast.
5. If delivery fails, check Salesforce email deliverability, record access, tenant email, and attachment size.

A success response indicates Salesforce accepted the send request; it does not guarantee the recipient's mail server delivered the message.

## Maintenance requests

1. Open the page containing `maintenanceRequestManager`.
2. Select the related property and enter a clear description of the issue.
3. Save the request.
4. The before-insert automation may assign an eligible vendor if no vendor was manually selected.
5. Update status using the available component controls.

Confirm actual status values in the deployed picklist. Do not assume values that are not configured in metadata.

## Lease expiry reminders

The reminder process is scheduled/background functionality, not necessarily a user-triggered screen action. Admins should verify the scheduled job, email deliverability, and reminder log records when validating this feature.
