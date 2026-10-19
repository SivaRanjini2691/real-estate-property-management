public without sharing class MaintenanceVendorAssignmentService {

    public static void assignLeastLoadedVendor(
        List<Maintenance_Request__c> requests
    ) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        List<Vendor__c> vendors = [
            SELECT Id, Name
            FROM Vendor__c
            WHERE Is_Active__c = true
            ORDER BY Name ASC, Id ASC
        ];

        if (vendors.isEmpty()) {
            for (Maintenance_Request__c requestRecord : requests) {
                if (requestRecord.Vendor__c == null) {
                    requestRecord.addError(
                        'Cannot create the maintenance request because no active vendors are available.'
                    );
                }
            }
            return;
        }

        Set<Id> vendorIds = new Map<Id, Vendor__c>(vendors).keySet();

        Map<Id, Integer> workloadByVendor = new Map<Id, Integer>();

        for (Vendor__c vendor : vendors) {
            workloadByVendor.put(vendor.Id, 0);
        }

        for (AggregateResult result : [
            SELECT Vendor__c vendorId, COUNT(Id) requestCount
            FROM Maintenance_Request__c
            WHERE Vendor__c IN :vendorIds
              AND Status__c IN ('Open', 'In Progress')
            GROUP BY Vendor__c
        ]) {
            workloadByVendor.put(
                (Id) result.get('vendorId'),
                (Integer) result.get('requestCount')
            );
        }

        Id selectedVendorId;
        Integer lowestWorkload;

        for (Vendor__c vendor : vendors) {
            Integer currentWorkload = workloadByVendor.get(vendor.Id);

            if (
                selectedVendorId == null ||
                currentWorkload < lowestWorkload
            ) {
                selectedVendorId = vendor.Id;
                lowestWorkload = currentWorkload;
            }
        }

        for (Maintenance_Request__c requestRecord : requests) {
            if (requestRecord.Vendor__c == null) {
                requestRecord.Vendor__c = selectedVendorId;
            }
        }
    }
}
