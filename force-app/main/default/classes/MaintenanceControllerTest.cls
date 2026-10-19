@IsTest
private class MaintenanceControllerTest {
    @TestSetup
    static void setupData() {
        Property__c propertyRecord = new Property__c(
            Name = 'Maintenance Test Property',
            Address__c = '20 Test Road',
            City__c = 'Chennai',
            State__c = 'Tamil Nadu',
            Postal_Code__c = '600002',
            Country__c = 'India',
            Property_Type__c = 'Residential',
            Status__c = 'Available',
            Rent__c = 18000
        );
        insert propertyRecord;

        insert new List<Vendor__c>{
            new Vendor__c(Name = 'Active Vendor A', Email__c = 'a.vendor@example.com', Is_Active__c = true),
            new Vendor__c(Name = 'Active Vendor B', Email__c = 'b.vendor@example.com', Is_Active__c = true)
        };
    }

    @IsTest
    static void createRequestAssignsActiveVendor() {
        Property__c propertyRecord = [SELECT Id FROM Property__c LIMIT 1];

        Test.startTest();
        Id requestId = MaintenanceController.createMaintenanceRequest(
            propertyRecord.Id,
            'Repair leaking kitchen tap'
        );
        Test.stopTest();

        Maintenance_Request__c savedRequest = [
            SELECT Property__c, Vendor__c, Status__c, Description__c, Assigned_Date__c
            FROM Maintenance_Request__c WHERE Id = :requestId
        ];
        System.assertEquals(propertyRecord.Id, savedRequest.Property__c);
        System.assertNotEquals(null, savedRequest.Vendor__c);
        System.assertEquals('Open', savedRequest.Status__c);
        System.assertEquals('Repair leaking kitchen tap', savedRequest.Description__c);
        System.assertNotEquals(null, savedRequest.Assigned_Date__c);
    }

    @IsTest
    static void createRequestRejectsMissingProperty() {
        try {
            MaintenanceController.createMaintenanceRequest(null, 'Repair window');
            System.assert(false, 'Expected missing property to be rejected.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('property'));
        }
    }

    @IsTest
    static void createRequestRejectsBlankDescription() {
        Property__c propertyRecord = [SELECT Id FROM Property__c LIMIT 1];
        try {
            MaintenanceController.createMaintenanceRequest(propertyRecord.Id, '  ');
            System.assert(false, 'Expected blank description to be rejected.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('description'));
        }
    }

    @IsTest
    static void getRequestsSupportsAllAndStatusFilter() {
        Property__c propertyRecord = [SELECT Id FROM Property__c LIMIT 1];
        Maintenance_Request__c requestRecord = new Maintenance_Request__c(
            Property__c = propertyRecord.Id,
            Description__c = 'Test completed request',
            Status__c = 'Completed'
        );
        insert requestRecord;

        Test.startTest();
        List<Maintenance_Request__c> allRows =
            MaintenanceController.getMaintenanceRequests('All');
        List<Maintenance_Request__c> completedRows =
            MaintenanceController.getMaintenanceRequests('Completed');
        Test.stopTest();

        System.assertEquals(1, allRows.size());
        System.assertEquals(1, completedRows.size());
        System.assertEquals('Completed', completedRows[0].Status__c);
    }

    @IsTest
    static void getRequestsRejectsInvalidStatus() {
        try {
            MaintenanceController.getMaintenanceRequests('Waiting for approval');
            System.assert(false, 'Expected invalid status to be rejected.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Invalid maintenance status'));
        }
    }

    @IsTest
    static void updateStatusChangesRequest() {
        Property__c propertyRecord = [SELECT Id FROM Property__c LIMIT 1];
        Maintenance_Request__c requestRecord = new Maintenance_Request__c(
            Property__c = propertyRecord.Id,
            Description__c = 'Test status update',
            Status__c = 'Open'
        );
        insert requestRecord;

        Test.startTest();
        MaintenanceController.updateMaintenanceStatus(requestRecord.Id, 'In Progress');
        Test.stopTest();

        System.assertEquals(
            'In Progress',
            [SELECT Status__c FROM Maintenance_Request__c WHERE Id = :requestRecord.Id].Status__c
        );
    }

    @IsTest
    static void updateStatusRejectsNullIdAndInvalidStatus() {
        try {
            MaintenanceController.updateMaintenanceStatus(null, 'Open');
            System.assert(false, 'Expected null ID to be rejected.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'));
        }

        Maintenance_Request__c requestRecord = new Maintenance_Request__c(
            Property__c = [SELECT Id FROM Property__c LIMIT 1].Id,
            Description__c = 'Invalid status test',
            Status__c = 'Open'
        );
        insert requestRecord;

        try {
            MaintenanceController.updateMaintenanceStatus(requestRecord.Id, 'Unknown');
            System.assert(false, 'Expected invalid status to be rejected.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('valid maintenance status'));
        }
    }
}
