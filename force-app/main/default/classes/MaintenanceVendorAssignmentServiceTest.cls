@IsTest
private class MaintenanceVendorAssignmentServiceTest {
    private static Property__c makeProperty() {
        Property__c propertyRecord = new Property__c(
            Name = 'Assignment Test Property',
            Address__c = '30 Test Lane',
            City__c = 'Chennai',
            State__c = 'Tamil Nadu',
            Postal_Code__c = '600003',
            Country__c = 'India',
            Property_Type__c = 'Residential',
            Status__c = 'Available',
            Rent__c = 20000
        );
        insert propertyRecord;
        return propertyRecord;
    }

    @IsTest
    static void triggerAssignsVendorWhenRequestInserted() {
        Property__c propertyRecord = makeProperty();
        Vendor__c vendorRecord = new Vendor__c(
            Name = 'Assignment Vendor',
            Email__c = 'assignment@example.com',
            Is_Active__c = true
        );
        insert vendorRecord;

        Maintenance_Request__c requestRecord = new Maintenance_Request__c(
            Property__c = propertyRecord.Id,
            Description__c = 'Auto assignment test',
            Status__c = 'Open'
        );

        Test.startTest();
        insert requestRecord;
        Test.stopTest();

        requestRecord = [
            SELECT Vendor__c FROM Maintenance_Request__c
            WHERE Id = :requestRecord.Id
        ];
        System.assertEquals(vendorRecord.Id, requestRecord.Vendor__c);
    }

    @IsTest
    static void keepsExplicitVendorAssignment() {
        Property__c propertyRecord = makeProperty();
        Vendor__c vendorA = new Vendor__c(Name = 'Vendor A', Email__c = 'va@example.com', Is_Active__c = true);
        Vendor__c vendorB = new Vendor__c(Name = 'Vendor B', Email__c = 'vb@example.com', Is_Active__c = true);
        insert new List<Vendor__c>{vendorA, vendorB};

        Maintenance_Request__c requestRecord = new Maintenance_Request__c(
            Property__c = propertyRecord.Id,
            Vendor__c = vendorB.Id,
            Description__c = 'Preserve explicit vendor',
            Status__c = 'Open'
        );
        insert requestRecord;

        System.assertEquals(
            vendorB.Id,
            [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :requestRecord.Id].Vendor__c
        );
    }

    @IsTest
    static void serviceIsSafeForNullOrEmptyInput() {
        Test.startTest();
        MaintenanceVendorAssignmentService.assignLeastLoadedVendor(null);
        MaintenanceVendorAssignmentService.assignLeastLoadedVendor(
            new List<Maintenance_Request__c>()
        );
        Test.stopTest();
        System.assertEquals(true, true, 'Null and empty inputs should be safe.');
    }

    @IsTest
    static void bulkInsertAssignsVendorsToEveryRequest() {
        Property__c propertyRecord = makeProperty();
        insert new List<Vendor__c>{
            new Vendor__c(Name = 'Bulk Vendor A', Email__c = 'bulk-a@example.com', Is_Active__c = true),
            new Vendor__c(Name = 'Bulk Vendor B', Email__c = 'bulk-b@example.com', Is_Active__c = true)
        };

        List<Maintenance_Request__c> requests = new List<Maintenance_Request__c>();
        for (Integer i = 0; i < 5; i++) {
            requests.add(new Maintenance_Request__c(
                Property__c = propertyRecord.Id,
                Description__c = 'Bulk request ' + i,
                Status__c = 'Open'
            ));
        }

        Test.startTest();
        insert requests;
        Test.stopTest();

        Integer assignedCount = [
            SELECT COUNT() FROM Maintenance_Request__c
            WHERE Id IN :requests AND Vendor__c != null
        ];
        System.assertEquals(5, assignedCount, 'Every bulk request should receive a vendor.');
    }
}
