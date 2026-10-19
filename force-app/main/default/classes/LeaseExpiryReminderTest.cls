@IsTest
private class LeaseExpiryReminderTest {
    private static Property__c makeProperty() {
        Property__c propertyRecord = new Property__c(
            Name = 'Reminder Test Property',
            Address__c = '40 Test Avenue',
            City__c = 'Chennai',
            State__c = 'Tamil Nadu',
            Postal_Code__c = '600004',
            Country__c = 'India',
            Property_Type__c = 'Residential',
            Status__c = 'Available',
            Rent__c = 22000
        );
        insert propertyRecord;
        return propertyRecord;
    }

    private static Tenant__c makeTenant(String emailAddress) {
        Tenant__c tenantRecord = new Tenant__c(
            Name = 'Reminder Test Tenant',
            Email__c = emailAddress,
            Phone_Number__c = '9876543210'
        );
        insert tenantRecord;
        return tenantRecord;
    }

    private static Lease_Agreement__c makeLease(
        Id tenantId, Id propertyId, Date endDate
    ) {
        Lease_Agreement__c lease = new Lease_Agreement__c(
            Tenant__c = tenantId,
            Property__c = propertyId,
            Agreed_Monthly_Rent__c = 22000,
            Start_Date__c = Date.today().addMonths(-6),
            End_Date__c = endDate,
            Status__c = 'Active',
            Terms__c = 'Reminder test terms'
        );
        insert lease;
        return lease;
    }

    @IsTest
    static void schedulerRegistersSuccessfully() {
        String cronExpression = '0 0 2 * * ?';
        Test.startTest();
        System.schedule(
            'Lease Expiry Reminder Test ' + String.valueOf(DateTime.now().getTime()),
            cronExpression,
            new LeaseExpiryReminderScheduler()
        );
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM CronTrigger WHERE CronExpression = :cronExpression],
            'Scheduler should be registered.'
        );
    }

    @IsTest
    static void batchCompletesWhenNoMatchingLeasesExist() {
        Test.startTest();
        Database.executeBatch(new LeaseExpiryReminderService(), 10);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Lease_Reminder_Log__c]);
    }

    @IsTest
    static void batchProcessesOneMonthExpiryLease() {
        Property__c propertyRecord = makeProperty();
        Tenant__c tenantRecord = makeTenant('one.month@example.com');
        makeLease(tenantRecord.Id, propertyRecord.Id, Date.today().addMonths(1));

        Test.startTest();
        Database.executeBatch(new LeaseExpiryReminderService(), 10);
        Test.stopTest();

        // The service should attempt to log a successful reminder. This assertion
        // intentionally exposes a metadata/code mismatch if Reminder_Type__c
        // does not accept the value used by the service.
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Lease_Reminder_Log__c],
            'A matching lease with an email should produce a reminder log.'
        );
    }

    @IsTest
    static void batchDoesNotSendDuplicateReminder() {
        Property__c propertyRecord = makeProperty();
        Tenant__c tenantRecord = makeTenant('duplicate@example.com');
        Lease_Agreement__c lease = makeLease(
            tenantRecord.Id, propertyRecord.Id, Date.today().addDays(1)
        );

        // Current field metadata uses the picklist value "1-Day".
        insert new Lease_Reminder_Log__c(
            Lease_Agreement__c = lease.Id,
            Reminder_Type__c = '1-Day',
            Reminder_Key__c = String.valueOf(lease.Id) + '_ONE_DAY'
        );

        Test.startTest();
        Database.executeBatch(new LeaseExpiryReminderService(), 10);
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Lease_Reminder_Log__c WHERE Lease_Agreement__c = :lease.Id],
            'An existing reminder key should prevent a duplicate log.'
        );
    }
}
