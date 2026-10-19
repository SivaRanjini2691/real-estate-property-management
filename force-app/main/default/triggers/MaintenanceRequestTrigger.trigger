trigger MaintenanceRequestTrigger on Maintenance_Request__c (before insert) {
    MaintenanceVendorAssignmentService.assignLeastLoadedVendor(Trigger.new);
}
