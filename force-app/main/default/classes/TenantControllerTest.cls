@IsTest
private class TenantControllerTest {

    @TestSetup
    static void createTestData() {
        insert new List<Tenant__c>{
            new Tenant__c(
                Name = 'Test Tenant Alpha',
                Email__c = 'alpha@example.com',
                Phone_Number__c = '9876543210'
            ),
            new Tenant__c(
                Name = 'Test Tenant Beta',
                Email__c = 'beta@example.com',
                Phone_Number__c = '9876543211'
            )
        };
    }

    @IsTest
    static void testGetTenants() {
        Test.startTest();
        List<Tenant__c> tenants =
            TenantController.getTenants('');
        Test.stopTest();

        System.assertEquals(2, tenants.size());
    }

    @IsTest
    static void testSearchTenants() {
        Test.startTest();
        List<Tenant__c> tenants =
            TenantController.getTenants('Alpha');
        Test.stopTest();

        System.assertEquals(1, tenants.size());
        System.assertEquals(
            'Test Tenant Alpha',
            tenants[0].Name
        );
    }

    @IsTest
    static void testCreateTenant() {
        Test.startTest();
        Id tenantId = TenantController.createTenant(
            'New Test Tenant',
            '9876543212',
            'newtenant@example.com'
        );
        Test.stopTest();

        Tenant__c tenant = [
            SELECT Name, Phone_Number__c, Email__c
            FROM Tenant__c
            WHERE Id = :tenantId
        ];

        System.assertEquals('New Test Tenant', tenant.Name);
        System.assertEquals(
            '9876543212',
            tenant.Phone_Number__c
        );
        System.assertEquals(
            'newtenant@example.com',
            tenant.Email__c
        );
    }
    @IsTest
static void testSearchTenantsByEmail() {
    List<Tenant__c> tenants =
        TenantController.getTenants('alpha@example.com');

    System.assertEquals(1, tenants.size());
    System.assertEquals('Test Tenant Alpha', tenants[0].Name);
}

@IsTest
static void testCreateTenantRejectsBlankName() {
    try {
        TenantController.createTenant(
            '   ',
            '9876543212',
            'newtenant@example.com'
        );
        System.assert(false, 'Expected validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testCreateTenantRejectsBlankEmail() {
    try {
        TenantController.createTenant(
            'New Test Tenant',
            '9876543212',
            '   '
        );
        System.assert(false, 'Expected validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}
@IsTest
static void testCreateLeaseRejectsMissingTenant() {
    Property__c propertyRecord = [
        SELECT Id FROM Property__c LIMIT 1
    ];

    try {
        LeaseAgreementController.createLeaseAgreement(
            null,
            propertyRecord.Id,
            15000,
            Date.today(),
            Date.today().addMonths(12),
            'Standard residential lease terms',
            'Draft'
        );
        System.assert(false, 'Expected tenant validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testCreateLeaseRejectsMissingProperty() {
    Tenant__c tenant = [
        SELECT Id FROM Tenant__c LIMIT 1
    ];

    try {
        LeaseAgreementController.createLeaseAgreement(
            tenant.Id,
            null,
            15000,
            Date.today(),
            Date.today().addMonths(12),
            'Standard residential lease terms',
            'Draft'
        );
        System.assert(false, 'Expected property validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testCreateLeaseRejectsInvalidRent() {
    Tenant__c tenant = [SELECT Id FROM Tenant__c LIMIT 1];
    Property__c propertyRecord = [SELECT Id FROM Property__c LIMIT 1];

    try {
        LeaseAgreementController.createLeaseAgreement(
            tenant.Id,
            propertyRecord.Id,
            0,
            Date.today(),
            Date.today().addMonths(12),
            'Standard residential lease terms',
            'Draft'
        );
        System.assert(false, 'Expected rent validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testCreateLeaseRejectsInvalidDates() {
    Tenant__c tenant = [SELECT Id FROM Tenant__c LIMIT 1];
    Property__c propertyRecord = [SELECT Id FROM Property__c LIMIT 1];
    Date startDate = Date.today();

    try {
        LeaseAgreementController.createLeaseAgreement(
            tenant.Id,
            propertyRecord.Id,
            15000,
            startDate,
            startDate,
            'Standard residential lease terms',
            'Draft'
        );
        System.assert(false, 'Expected date validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testCreateLeaseRejectsMissingTerms() {
    Tenant__c tenant = [SELECT Id FROM Tenant__c LIMIT 1];
    Property__c propertyRecord = [SELECT Id FROM Property__c LIMIT 1];

    try {
        LeaseAgreementController.createLeaseAgreement(
            tenant.Id,
            propertyRecord.Id,
            15000,
            Date.today(),
            Date.today().addMonths(12),
            '   ',
            'Draft'
        );
        System.assert(false, 'Expected terms validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testGetLeaseAgreementsWithStatusFilter() {
    List<Lease_Agreement__c> existingLeases = [
        SELECT Id, Status__c
        FROM Lease_Agreement__c
        LIMIT 1
    ];

    if (!existingLeases.isEmpty()) {
        List<LeaseAgreementController.LeaseResult> results =
            new List<LeaseAgreementController.LeaseResult>();

        Test.startTest();
        LeaseAgreementController.LeaseResult result =
            LeaseAgreementController.getLeaseAgreements(
                '',
                existingLeases[0].Status__c
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.records);
    }
}
@IsTest
static void testCreateLeaseRejectsMissingTenant() {
    Property__c propertyRecord = [
        SELECT Id FROM Property__c LIMIT 1
    ];

    try {
        LeaseAgreementController.createLeaseAgreement(
            null,
            propertyRecord.Id,
            15000,
            Date.today(),
            Date.today().addMonths(12),
            'Standard residential lease terms',
            'Draft'
        );
        System.assert(false, 'Expected tenant validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testCreateLeaseRejectsMissingProperty() {
    Tenant__c tenant = [
        SELECT Id FROM Tenant__c LIMIT 1
    ];

    try {
        LeaseAgreementController.createLeaseAgreement(
            tenant.Id,
            null,
            15000,
            Date.today(),
            Date.today().addMonths(12),
            'Standard residential lease terms',
            'Draft'
        );
        System.assert(false, 'Expected property validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testCreateLeaseRejectsInvalidRent() {
    Tenant__c tenant = [SELECT Id FROM Tenant__c LIMIT 1];
    Property__c propertyRecord = [SELECT Id FROM Property__c LIMIT 1];

    try {
        LeaseAgreementController.createLeaseAgreement(
            tenant.Id,
            propertyRecord.Id,
            0,
            Date.today(),
            Date.today().addMonths(12),
            'Standard residential lease terms',
            'Draft'
        );
        System.assert(false, 'Expected rent validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testCreateLeaseRejectsInvalidDates() {
    Tenant__c tenant = [SELECT Id FROM Tenant__c LIMIT 1];
    Property__c propertyRecord = [SELECT Id FROM Property__c LIMIT 1];
    Date startDate = Date.today();

    try {
        LeaseAgreementController.createLeaseAgreement(
            tenant.Id,
            propertyRecord.Id,
            15000,
            startDate,
            startDate,
            'Standard residential lease terms',
            'Draft'
        );
        System.assert(false, 'Expected date validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testCreateLeaseRejectsMissingTerms() {
    Tenant__c tenant = [SELECT Id FROM Tenant__c LIMIT 1];
    Property__c propertyRecord = [SELECT Id FROM Property__c LIMIT 1];

    try {
        LeaseAgreementController.createLeaseAgreement(
            tenant.Id,
            propertyRecord.Id,
            15000,
            Date.today(),
            Date.today().addMonths(12),
            '   ',
            'Draft'
        );
        System.assert(false, 'Expected terms validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testCreateLeaseRejectsInvalidStatus() {
    Tenant__c tenant = [SELECT Id FROM Tenant__c LIMIT 1];
    Property__c propertyRecord = [SELECT Id FROM Property__c LIMIT 1];

    try {
        LeaseAgreementController.createLeaseAgreement(
            tenant.Id,
            propertyRecord.Id,
            15000,
            Date.today(),
            Date.today().addMonths(12),
            'Standard residential lease terms',
            'InvalidStatus'
        );
        System.assert(false, 'Expected status validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testGetLeaseAgreementsWithStatusFilter() {
    Tenant__c tenant = [SELECT Id FROM Tenant__c LIMIT 1];
    Property__c propertyRecord = [SELECT Id FROM Property__c LIMIT 1];

    // Create a lease in this test so the status-filter path is exercised.
    LeaseAgreementController.createLeaseAgreement(
        tenant.Id,
        propertyRecord.Id,
        15000,
        Date.today(),
        Date.today().addMonths(12),
        'Standard residential lease terms',
        'Draft'
    );

    Test.startTest();
    LeaseAgreementController.LeaseResult result =
        LeaseAgreementController.getLeaseAgreements('', 'Draft');
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertNotEquals(null, result.records);
    System.assert(result.totalRecords > 0, 'Expected at least one Draft lease.');
}
}