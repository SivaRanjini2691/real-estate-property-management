@IsTest
private class LeaseAgreementPdfControllerTest {
    @TestSetup
    static void setupData() {
        Property__c propertyRecord = new Property__c(
            Name = 'PDF Test Property',
            Address__c = '10 Test Street',
            City__c = 'Chennai',
            State__c = 'Tamil Nadu',
            Postal_Code__c = '600001',
            Country__c = 'India',
            Property_Type__c = 'Residential',
            Status__c = 'Available',
            Rent__c = 25000
        );
        insert propertyRecord;

        Tenant__c tenantRecord = new Tenant__c(
            Name = 'PDF Test Tenant',
            Email__c = 'pdf.tenant@example.com',
            Phone_Number__c = '9876543210'
        );
        insert tenantRecord;

        insert new Lease_Agreement__c(
            Tenant__c = tenantRecord.Id,
            Property__c = propertyRecord.Id,
            Agreed_Monthly_Rent__c = 25000,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(12),
            Status__c = 'Active',
            Terms__c = 'Test lease terms'
        );
    }

    @IsTest
    static void getLeaseDetailsReturnsRelatedData() {
        Lease_Agreement__c lease = [
            SELECT Id FROM Lease_Agreement__c LIMIT 1
        ];

        Test.startTest();
        Lease_Agreement__c result =
            LeaseAgreementPdfController.getLeaseDetails(lease.Id);
        Test.stopTest();

        System.assertEquals(lease.Id, result.Id);
        System.assertEquals('PDF Test Tenant', result.Tenant__r.Name);
        System.assertEquals('pdf.tenant@example.com', result.Tenant__r.Email__c);
        System.assertEquals('PDF Test Property', result.Property__r.Name);
    }

    @IsTest
    static void getLeaseDetailsRejectsNullId() {
        try {
            LeaseAgreementPdfController.getLeaseDetails(null);
            System.assert(false, 'Expected null ID to be rejected.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('record is required'));
        }
    }

    @IsTest
    static void getLeaseDetailsRejectsUnknownId() {
        try {
            LeaseAgreementPdfController.getLeaseDetails(
                'a00000000000001AAA'
            );
            System.assert(false, 'Expected missing record to be rejected.');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('Unable to retrieve'),
                'Unexpected error message: ' + e.getMessage()
            );
        }
    }

    @IsTest
    static void sendLeasePdfEmailRejectsMissingInputs() {
        try {
            LeaseAgreementPdfController.sendLeasePdfEmail(null, null);
            System.assert(false, 'Expected missing inputs to be rejected.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'));
        }

        Lease_Agreement__c lease = [
            SELECT Id FROM Lease_Agreement__c LIMIT 1
        ];
        try {
            LeaseAgreementPdfController.sendLeasePdfEmail(lease.Id, '   ');
            System.assert(false, 'Expected blank PDF to be rejected.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'));
        }
    }

    @IsTest
    static void sendLeasePdfEmailRejectsInvalidBase64() {
        Lease_Agreement__c lease = [
            SELECT Id FROM Lease_Agreement__c LIMIT 1
        ];

        Test.startTest();
        try {
            LeaseAgreementPdfController.sendLeasePdfEmail(lease.Id, '%%%not-base64%%%');
            System.assert(false, 'Expected invalid PDF data to be rejected.');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('invalid') ||
                e.getMessage().contains('Unable to send'),
                'Unexpected error message: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void sendLeasePdfEmailQueuesEmailForValidPdf() {
        Lease_Agreement__c lease = [
            SELECT Id FROM Lease_Agreement__c LIMIT 1
        ];
        String tinyPdfBase64 = EncodingUtil.base64Encode(
            Blob.valueOf('%PDF-1.4 test content')
        );

        Test.startTest();
        LeaseAgreementPdfController.sendLeasePdfEmail(
            lease.Id,
            tinyPdfBase64
        );
        System.assertEquals(
            1,
            Limits.getEmailInvocations(),
            'The controller should invoke the email service once.'
        );
        Test.stopTest();
    }
}
