public with sharing class MaintenanceController {

    public class MaintenanceResult {
        @AuraEnabled
        public List<Maintenance_Request__c> records { get; set; }

        public MaintenanceResult() {
            records = new List<Maintenance_Request__c>();
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Maintenance_Request__c> getMaintenanceRequests(
        String statusFilter
    ) {
        if (String.isBlank(statusFilter) || statusFilter == 'All') {
            return [
                SELECT Id,
                       Name,
                       Property__c,
                       Property__r.Name,
                       Vendor__c,
                       Vendor__r.Name,
                       Status__c,
                       Description__c,
                       Assigned_Date__c,
                       CreatedDate
                FROM Maintenance_Request__c
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        }

        Set<String> allowedStatuses = new Set<String>{
            'Open',
            'In Progress',
            'Completed',
            'Cancelled'
        };

        if (!allowedStatuses.contains(statusFilter)) {
            throw new AuraHandledException(
                'Invalid maintenance status.'
            );
        }

        return [
            SELECT Id,
                   Name,
                   Property__c,
                   Property__r.Name,
                   Vendor__c,
                   Vendor__r.Name,
                   Status__c,
                   Description__c,
                   Assigned_Date__c,
                   CreatedDate
            FROM Maintenance_Request__c
            WHERE Status__c = :statusFilter
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static Id createMaintenanceRequest(
        Id propertyId,
        String description
    ) {
        if (propertyId == null) {
            throw new AuraHandledException(
                'Please select a property.'
            );
        }

        if (String.isBlank(description)) {
            throw new AuraHandledException(
                'Please enter a maintenance description.'
            );
        }

        // Confirm the property exists and is accessible.
        List<Property__c> properties = [
            SELECT Id, Name
            FROM Property__c
            WHERE Id = :propertyId
            WITH USER_MODE
            LIMIT 1
        ];

        if (properties.isEmpty()) {
            throw new AuraHandledException(
                'The selected property was not found or is inaccessible.'
            );
        }

        // Retrieve active vendors.
        List<Vendor__c> vendors = [
            SELECT Id, Name
            FROM Vendor__c
            WHERE Is_Active__c = true
            WITH USER_MODE
            ORDER BY Name
        ];

        if (vendors.isEmpty()) {
            throw new AuraHandledException(
                'No active vendors are available for assignment.'
            );
        }

        Set<Id> vendorIds = new Map<Id, Vendor__c>(
            vendors
        ).keySet();

        // Count currently active maintenance assignments.
        Map<Id, Integer> workloadByVendor =
            new Map<Id, Integer>();

        for (Id vendorId : vendorIds) {
            workloadByVendor.put(vendorId, 0);
        }

        for (AggregateResult result : [
            SELECT Vendor__c vendorId, COUNT(Id) requestCount
            FROM Maintenance_Request__c
            WHERE Vendor__c IN :vendorIds
              AND Status__c IN ('Open', 'In Progress')
            WITH USER_MODE
            GROUP BY Vendor__c
        ]) {
            workloadByVendor.put(
                (Id) result.get('vendorId'),
                (Integer) result.get('requestCount')
            );
        }

        // Select the vendor with the smallest workload.
        // The vendor list is ordered by name, so ties are deterministic.
        Id selectedVendorId;
        Integer lowestWorkload;

        for (Vendor__c vendor : vendors) {
            Integer currentWorkload =
                workloadByVendor.get(vendor.Id);

            if (
                selectedVendorId == null ||
                currentWorkload < lowestWorkload
            ) {
                selectedVendorId = vendor.Id;
                lowestWorkload = currentWorkload;
            }
        }

        Maintenance_Request__c requestRecord =
            new Maintenance_Request__c(
                Property__c = propertyId,
                Vendor__c = selectedVendorId,
                Status__c = 'Open',
                Description__c = description.trim(),
                Assigned_Date__c = System.now()
            );

        insert as user requestRecord;

        return requestRecord.Id;
    }

    @AuraEnabled
    public static void updateMaintenanceStatus(
        Id requestId,
        String newStatus
    ) {
        if (requestId == null) {
            throw new AuraHandledException(
                'Maintenance request ID is required.'
            );
        }

        Set<String> allowedStatuses = new Set<String>{
            'Open',
            'In Progress',
            'Completed',
            'Cancelled'
        };

        if (!allowedStatuses.contains(newStatus)) {
            throw new AuraHandledException(
                'Please select a valid maintenance status.'
            );
        }

        Maintenance_Request__c requestRecord =
            new Maintenance_Request__c(
                Id = requestId,
                Status__c = newStatus
            );

        update as user requestRecord;
    }
}