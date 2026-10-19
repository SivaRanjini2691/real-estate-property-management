@IsTest
private class LeaseAgreementControllerTest {

    @TestSetup
    static void createTestData() {
        Property__c property = new Property__c(
            Name = 'Test Available Property',
            Address__c = '10 Main Street',
            City__c = 'Chennai',
            State__c = 'Tamil Nadu',
            Postal_Code__c = '600001',
            Country__c = 'India',
            Property_Type__c = 'Residential',
            Furnishing_Status__c = 'Furnished',
            Status__c = 'Available',
            Rent__c = 25000,
            Description__c = 'Test property for lease agreement'
        );
        insert property;

        Tenant__c tenant = new Tenant__c(
            Name = 'Test Tenant',
            Email__c = 'tenant@example.com',
            Phone_Number__c = '9876543210'
        );
        insert tenant;
    }

    @IsTest
    static void testGetTenantOptions() {
        Test.startTest();
        List<Tenant__c> tenants =
            LeaseAgreementController.getTenantOptions('Test Tenant');
        Test.stopTest();

        System.assertEquals(1, tenants.size());
        System.assertEquals('Test Tenant', tenants[0].Name);
    }

    @IsTest
    static void testGetPropertyOptions() {
        Test.startTest();
        List<Property__c> properties =
            LeaseAgreementController.getPropertyOptions('Test Available');
        Test.stopTest();

        System.assertEquals(1, properties.size());
        System.assertEquals('Test Available Property', properties[0].Name);
    }

    @IsTest
    static void testCreateLeaseAgreement() {
        Tenant__c tenant = [
            SELECT Id FROM Tenant__c WHERE Name = 'Test Tenant' LIMIT 1
        ];

        Property__c property = [
            SELECT Id FROM Property__c
            WHERE Name = 'Test Available Property' LIMIT 1
        ];

        Date startDate = Date.today();
        Date endDate = startDate.addMonths(12);

        Test.startTest();
        Id leaseId = LeaseAgreementController.createLeaseAgreement(
            tenant.Id,
            property.Id,
            25000,
            startDate,
            endDate,
            'Test lease terms',
            'Draft'
        );
        Test.stopTest();

        Lease_Agreement__c savedLease = [
            SELECT Tenant__c, Property__c, Agreed_Monthly_Rent__c,
                   Start_Date__c, End_Date__c, Terms__c, Status__c
            FROM Lease_Agreement__c
            WHERE Id = :leaseId
        ];

        System.assertEquals(tenant.Id, savedLease.Tenant__c);
        System.assertEquals(property.Id, savedLease.Property__c);
        System.assertEquals(25000, savedLease.Agreed_Monthly_Rent__c);
        System.assertEquals('Draft', savedLease.Status__c);
        System.assertEquals('Test lease terms', savedLease.Terms__c);
    }

    @IsTest
    static void testGetLeaseAgreements() {
        Tenant__c tenant = [
            SELECT Id FROM Tenant__c WHERE Name = 'Test Tenant' LIMIT 1
        ];

        Property__c property = [
            SELECT Id FROM Property__c
            WHERE Name = 'Test Available Property' LIMIT 1
        ];

        Lease_Agreement__c lease = new Lease_Agreement__c(
            Tenant__c = tenant.Id,
            Property__c = property.Id,
            Agreed_Monthly_Rent__c = 25000,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(12),
            Terms__c = 'Test lease terms',
            Status__c = 'Draft'
        );
        insert lease;

        Test.startTest();
        LeaseAgreementController.LeaseResult result =
            LeaseAgreementController.getLeaseAgreements('', 'Draft');
        Test.stopTest();

        System.assertEquals(1, result.totalRecords);
        System.assertEquals(lease.Id, result.records[0].Id);
    }
}