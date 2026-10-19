@IsTest
private class PropertyControllerTest {

    @TestSetup
    static void createTestData() {
        List<Property__c> properties = new List<Property__c>();

        for (Integer i = 1; i <= 30; i++) {
            properties.add(new Property__c(
                Name = 'Test Property ' + i,
                Address__c = i + ' Anna Salai',
                City__c = 'Chennai',
                State__c = 'Tamil Nadu',
                Postal_Code__c = '600002',
                Country__c = 'India',
                Property_Type__c = i <= 15
                    ? 'Residential'
                    : 'Commercial',
                Furnishing_Status__c = 'Furnished',
                Status__c = i <= 20
                    ? 'Available'
                    : 'Occupied',
                Rent__c = i * 1000,
                Description__c = 'Test property description'
            ));
        }

        insert properties;
    }

    @IsTest
    static void testDefaultPagination() {
        Test.startTest();

        PropertyController.PropertyResult result =
            PropertyController.getProperties(
                null, null, null, null, null, null, null
            );

        Test.stopTest();

        System.assertEquals(30, result.totalRecords);
        System.assertEquals(25, result.pageSize);
        System.assertEquals(2, result.totalPages);
        System.assertEquals(25, result.records.size());
        System.assertEquals(1, result.pageNumber);
    }

    @IsTest
    static void testSecondPage() {
        Test.startTest();

        PropertyController.PropertyResult result =
            PropertyController.getProperties(
                2, 25, null, null, null, null, null
            );

        Test.stopTest();

        System.assertEquals(30, result.totalRecords);
        System.assertEquals(5, result.records.size());
        System.assertEquals(2, result.pageNumber);
    }

    @IsTest
    static void testFilterByPropertyType() {
        Test.startTest();

        PropertyController.PropertyResult result =
            PropertyController.getProperties(
                1, 25, 'Residential', null, null, null, null
            );

        Test.stopTest();

        System.assertEquals(15, result.totalRecords);

        for (Property__c propertyRecord : result.records) {
            System.assertEquals(
                'Residential',
                propertyRecord.Property_Type__c
            );
        }
    }

    @IsTest
    static void testFilterByAvailability() {
        Test.startTest();

        PropertyController.PropertyResult result =
            PropertyController.getProperties(
                1, 25, null, 'Available', null, null, null
            );

        Test.stopTest();

        System.assertEquals(20, result.totalRecords);
    }

    @IsTest
    static void testRentRange() {
        Test.startTest();

        PropertyController.PropertyResult result =
            PropertyController.getProperties(
                1, 25, null, null, null, 5000, 10000
            );

        Test.stopTest();

        System.assertEquals(6, result.totalRecords);

        for (Property__c propertyRecord : result.records) {
            System.assert(
                propertyRecord.Rent__c >= 5000 &&
                propertyRecord.Rent__c <= 10000
            );
        }
    }

    @IsTest
    static void testNoMatchingRecords() {
        Test.startTest();

        PropertyController.PropertyResult result =
            PropertyController.getProperties(
                1, 25, null, null, null, 1000000, 2000000
            );

        Test.stopTest();

        System.assertEquals(0, result.totalRecords);
        System.assertEquals(0, result.records.size());
        System.assertEquals(0, result.totalPages);
    }

    @IsTest
    static void testPageSizeLimit() {
        Test.startTest();

        PropertyController.PropertyResult result =
            PropertyController.getProperties(
                1, 500, null, null, null, null, null
            );

        Test.stopTest();

        System.assertEquals(100, result.pageSize);
        System.assertEquals(30, result.records.size());
    }
    @IsTest
static void testCreateImageStaging() {
    Test.startTest();
    Id stagingId = PropertyController.createImageStaging();
    Test.stopTest();

    Property_Image_Staging__c staging = [
        SELECT Id, Upload_Owner__c, Upload_Status__c, Expiry_Time__c
        FROM Property_Image_Staging__c
        WHERE Id = :stagingId
    ];

    System.assertEquals(UserInfo.getUserId(), staging.Upload_Owner__c);
    System.assertEquals('Pending', staging.Upload_Status__c);
    System.assert(staging.Expiry_Time__c > System.now());
}

@IsTest
static void testFinalizePropertyRejectsNullProperty() {
    try {
        PropertyController.finalizeProperty(null, null);
        System.assert(false, 'Expected validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testFinalizePropertyRejectsMissingName() {
    Property__c propertyRecord = new Property__c(
        Rent__c = 10000,
        Description__c = 'Test description'
    );

    try {
        PropertyController.finalizeProperty(propertyRecord, null);
        System.assert(false, 'Expected validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testFinalizePropertyRejectsInvalidRent() {
    Property__c propertyRecord = new Property__c(
        Name = 'Invalid Rent Property',
        Rent__c = 0,
        Description__c = 'Test description'
    );

    try {
        PropertyController.finalizeProperty(propertyRecord, null);
        System.assert(false, 'Expected validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testFinalizePropertyRejectsMissingDescription() {
    Property__c propertyRecord = new Property__c(
        Name = 'Missing Description Property',
        Rent__c = 10000
    );

    try {
        PropertyController.finalizeProperty(propertyRecord, null);
        System.assert(false, 'Expected validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testFinalizePropertyRejectsMissingStagingId() {
    Property__c propertyRecord = new Property__c(
        Name = 'Missing Staging Property',
        Rent__c = 10000,
        Description__c = 'Test description'
    );

    try {
        PropertyController.finalizeProperty(propertyRecord, null);
        System.assert(false, 'Expected validation exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}
@IsTest
static void testGetPropertiesWithFurnishingFilter() {
    PropertyController.PropertyResult result =
        PropertyController.getProperties(
            1, 25, null, null, 'Furnished', null, null
        );

    System.assertEquals(30, result.totalRecords);
    System.assertEquals(25, result.records.size());
}

@IsTest
static void testGetPropertiesInvalidPaginationDefaults() {
    PropertyController.PropertyResult result =
        PropertyController.getProperties(
            0, 0, null, null, null, null, null
        );

    System.assertEquals(1, result.pageNumber);
    System.assertEquals(25, result.pageSize);
    System.assertEquals(25, result.records.size());
}

@IsTest
static void testGetPropertiesPageBeyondLastPage() {
    PropertyController.PropertyResult result =
        PropertyController.getProperties(
            10, 25, null, null, null, null, null
        );

    System.assertEquals(30, result.totalRecords);
    System.assertEquals(10, result.pageNumber);
    System.assertEquals(0, result.records.size());
}

@IsTest
static void testFinalizePropertyRejectsUnknownStagingId() {
    Property_Image_Staging__c staging =
        new Property_Image_Staging__c(
            Upload_Status__c = 'Pending',
            Expiry_Time__c = System.now().addHours(1),
            Upload_Owner__c = UserInfo.getUserId()
        );
    insert staging;
    delete staging;

    Property__c propertyRecord = buildValidProperty();

    try {
        PropertyController.finalizeProperty(
            propertyRecord, staging.Id
        );
        System.assert(false, 'Expected an exception for missing staging.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testFinalizePropertyRejectsExpiredSession() {
    Property_Image_Staging__c staging =
        new Property_Image_Staging__c(
            Upload_Status__c = 'Pending',
            Expiry_Time__c = System.now().addHours(-1),
            Upload_Owner__c = UserInfo.getUserId()
        );
    insert staging;

    try {
        PropertyController.finalizeProperty(
            buildValidProperty(), staging.Id
        );
        System.assert(false, 'Expected an expired-session exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testFinalizePropertyRejectsCompletedSession() {
    Property_Image_Staging__c staging =
        new Property_Image_Staging__c(
            Upload_Status__c = 'Completed',
            Expiry_Time__c = System.now().addHours(1),
            Upload_Owner__c = UserInfo.getUserId()
        );
    insert staging;

    try {
        PropertyController.finalizeProperty(
            buildValidProperty(), staging.Id
        );
        System.assert(false, 'Expected an inactive-session exception.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testFinalizePropertyRejectsSessionWithoutFiles() {
    Property_Image_Staging__c staging =
        new Property_Image_Staging__c(
            Upload_Status__c = 'Pending',
            Expiry_Time__c = System.now().addHours(1),
            Upload_Owner__c = UserInfo.getUserId()
        );
    insert staging;

    try {
        PropertyController.finalizeProperty(
            buildValidProperty(), staging.Id
        );
        System.assert(false, 'Expected an exception because no file exists.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

@IsTest
static void testFinalizePropertyRejectsNonImageFile() {
    Property_Image_Staging__c staging =
        new Property_Image_Staging__c(
            Upload_Status__c = 'Pending',
            Expiry_Time__c = System.now().addHours(1),
            Upload_Owner__c = UserInfo.getUserId()
        );
    insert staging;

    ContentVersion fileRecord = new ContentVersion(
        Title = 'TestDocument',
        PathOnClient = 'TestDocument.txt',
        VersionData = Blob.valueOf('Test file content'),
        FirstPublishLocationId = staging.Id
    );
    insert fileRecord;

    try {
        PropertyController.finalizeProperty(
            buildValidProperty(), staging.Id
        );
        System.assert(false, 'Expected an exception for a non-image file.');
    } catch (AuraHandledException e) {
        System.assert(true);
    }
}

private static Property__c buildValidProperty() {
    return new Property__c(
        Name = 'Coverage Test Property',
        Address__c = '10 Anna Salai',
        City__c = 'Chennai',
        State__c = 'Tamil Nadu',
        Postal_Code__c = '600002',
        Country__c = 'India',
        Property_Type__c = 'Residential',
        Furnishing_Status__c = 'Furnished',
        Status__c = 'Available',
        Rent__c = 15000,
        Description__c = 'Property created for Apex coverage testing'
    );
}
}