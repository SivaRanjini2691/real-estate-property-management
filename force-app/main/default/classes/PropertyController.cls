public with sharing class PropertyController {

    public class PropertyResult {
        @AuraEnabled public List<Property__c> records { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer pageNumber { get; set; }
        @AuraEnabled public Integer pageSize { get; set; }
        @AuraEnabled public Integer totalPages { get; set; }
        @AuraEnabled public Map<Id, String> imageUrls { get; set; }
    }

    public class NearbyPropertyResult {
        @AuraEnabled public PropertyResult result { get; set; }
        @AuraEnabled public Map<Id, Decimal> distancesKm { get; set; }
    }

    private static final Integer MAX_PAGE_SIZE = 100;
    private static final Integer NEARBY_CANDIDATE_LIMIT = 5000;
    private static final Double EARTH_RADIUS_KM = 6371.0;

    @AuraEnabled(cacheable=true)
    public static PropertyResult getProperties(
        Integer pageNumber,
        Integer pageSize,
        String propertyType,
        String status,
        String furnishingStatus,
        Decimal minRent,
        Decimal maxRent
    ) {
        Integer currentPage = pageNumber == null || pageNumber < 1
            ? 1 : pageNumber;

        Integer recordsPerPage = pageSize == null || pageSize < 1
            ? 25 : Math.min(pageSize, MAX_PAGE_SIZE);

        List<String> conditions = buildConditions(
            propertyType, status, furnishingStatus, minRent, maxRent
        );

        String whereClause = conditions.isEmpty()
            ? ''
            : ' WHERE ' + String.join(conditions, ' AND ');

        Integer totalRecords = Database.countQuery(
            'SELECT COUNT() FROM Property__c' + whereClause
        );

        Integer totalPages = totalRecords == 0
            ? 0
            : (Integer)Math.ceil(
                Decimal.valueOf(totalRecords) / recordsPerPage
            );

        PropertyResult result = new PropertyResult();
        result.totalRecords = totalRecords;
        result.pageNumber = currentPage;
        result.pageSize = recordsPerPage;
        result.totalPages = totalPages;

        Integer offsetValue = (currentPage - 1) * recordsPerPage;

        if (totalRecords == 0 || offsetValue >= totalRecords) {
            result.records = new List<Property__c>();
            result.imageUrls = new Map<Id, String>();
            return result;
        }

        String queryString =
            'SELECT Id, Name, Address__c, City__c, State__c, ' +
            'Postal_Code__c, Country__c, Full_Address__c, ' +
            'Property_Type__c, Furnishing_Status__c, Status__c, ' +
            'Rent__c, Description__c, Latitude__c, Longitude__c ' +
            'FROM Property__c' + whereClause +
            ' ORDER BY CreatedDate DESC' +
            ' LIMIT ' + recordsPerPage +
            ' OFFSET ' + offsetValue;

        result.records = Database.query(queryString);
        addImageUrls(result);
        return result;
    }

    @AuraEnabled
    public static NearbyPropertyResult getNearbyProperties(
        Integer pageNumber,
        Integer pageSize,
        String propertyType,
        String status,
        String furnishingStatus,
        Decimal minRent,
        Decimal maxRent,
        Decimal userLatitude,
        Decimal userLongitude,
        Decimal distanceKm
    ) {
        if (userLatitude == null || userLongitude == null ||
            userLatitude < -90 || userLatitude > 90 ||
            userLongitude < -180 || userLongitude > 180) {
            throw new AuraHandledException(
                'Please provide a valid current location.'
            );
        }

        if (distanceKm == null || distanceKm <= 0 ||
            distanceKm > 500) {
            throw new AuraHandledException(
                'Distance must be greater than 0 and no more than 500 km.'
            );
        }

        Integer currentPage = pageNumber == null || pageNumber < 1
            ? 1 : pageNumber;

        Integer recordsPerPage = pageSize == null || pageSize < 1
            ? 25 : Math.min(pageSize, MAX_PAGE_SIZE);

        List<String> conditions = buildConditions(
            propertyType, status, furnishingStatus, minRent, maxRent
        );

        conditions.add('Latitude__c != null');
        conditions.add('Longitude__c != null');

        Double latitudeDelta = distanceKm.doubleValue() / 111.0;
        Double cosineLatitude = Math.abs(
            Math.cos(userLatitude.doubleValue() * Math.PI / 180.0)
        );

        Double longitudeDelta = cosineLatitude < 0.00001
            ? 180.0
            : Math.min(180.0, distanceKm.doubleValue() /
                (111.0 * cosineLatitude));

        Decimal minLatitude = Math.max(
            -90.0,
            userLatitude - Decimal.valueOf(String.valueOf(latitudeDelta))
        );

        Decimal maxLatitude = Math.min(
            90.0,
            userLatitude + Decimal.valueOf(String.valueOf(latitudeDelta))
        );

        conditions.add('Latitude__c >= :minLatitude');
        conditions.add('Latitude__c <= :maxLatitude');

        if (longitudeDelta < 180.0) {
            Decimal minLongitude = userLongitude -
                Decimal.valueOf(String.valueOf(longitudeDelta));
            Decimal maxLongitude = userLongitude +
                Decimal.valueOf(String.valueOf(longitudeDelta));

            if (minLongitude >= -180 && maxLongitude <= 180) {
                conditions.add('Longitude__c >= :minLongitude');
                conditions.add('Longitude__c <= :maxLongitude');
            } else {
                // The search crosses the international date line.
                conditions.add(
                    '(Longitude__c >= :minLongitude OR ' +
                    'Longitude__c <= :maxLongitude)'
                );
            }
        }

        String whereClause = ' WHERE ' +
            String.join(conditions, ' AND ');

        List<Property__c> candidates = Database.query(
            'SELECT Id, Name, Address__c, City__c, State__c, ' +
            'Postal_Code__c, Country__c, Full_Address__c, ' +
            'Property_Type__c, Furnishing_Status__c, Status__c, ' +
            'Rent__c, Description__c, Latitude__c, Longitude__c ' +
            'FROM Property__c' + whereClause +
            ' ORDER BY CreatedDate DESC' +
            ' LIMIT ' + NEARBY_CANDIDATE_LIMIT
        );

        Map<Id, Decimal> distanceById = new Map<Id, Decimal>();
        List<Property__c> matches = new List<Property__c>();

        for (Property__c propertyRecord : candidates) {
            Double distance = calculateDistanceKm(
                userLatitude.doubleValue(),
                userLongitude.doubleValue(),
                propertyRecord.Latitude__c.doubleValue(),
                propertyRecord.Longitude__c.doubleValue()
            );

            if (distance <= distanceKm.doubleValue()) {
                matches.add(propertyRecord);
                distanceById.put(
                    propertyRecord.Id,
                    Decimal.valueOf(String.valueOf(distance))
                );
            }
        }

        // Sort nearby matches from nearest to farthest.
        for (Integer i = 0; i < matches.size(); i++) {
            for (Integer j = i + 1; j < matches.size(); j++) {
                if (distanceById.get(matches[j].Id) <
                    distanceById.get(matches[i].Id)) {
                    Property__c temporary = matches[i];
                    matches[i] = matches[j];
                    matches[j] = temporary;
                }
            }
        }

        Integer totalRecords = matches.size();
        Integer totalPages = totalRecords == 0
            ? 0
            : (Integer)Math.ceil(
                Decimal.valueOf(totalRecords) / recordsPerPage
            );

        Integer offsetValue = (currentPage - 1) * recordsPerPage;

        PropertyResult propertyResult = new PropertyResult();
        propertyResult.totalRecords = totalRecords;
        propertyResult.pageNumber = currentPage;
        propertyResult.pageSize = recordsPerPage;
        propertyResult.totalPages = totalPages;
        propertyResult.records = new List<Property__c>();
        propertyResult.imageUrls = new Map<Id, String>();

        Map<Id, Decimal> pageDistances = new Map<Id, Decimal>();

        for (Integer i = offsetValue;
             i < Math.min(offsetValue + recordsPerPage, totalRecords);
             i++) {
            Property__c record = matches[i];
            propertyResult.records.add(record);
            pageDistances.put(record.Id, distanceById.get(record.Id));
        }

        addImageUrls(propertyResult);

        NearbyPropertyResult response = new NearbyPropertyResult();
        response.result = propertyResult;
        response.distancesKm = pageDistances;
        return response;
    }

    private static Double calculateDistanceKm(
        Double lat1,
        Double lon1,
        Double lat2,
        Double lon2
    ) {
        Double latDifference = (lat2 - lat1) * Math.PI / 180.0;
        Double lonDifference = (lon2 - lon1) * Math.PI / 180.0;

        Double a =
            Math.sin(latDifference / 2) * Math.sin(latDifference / 2) +
            Math.cos(lat1 * Math.PI / 180.0) *
            Math.cos(lat2 * Math.PI / 180.0) *
            Math.sin(lonDifference / 2) *
            Math.sin(lonDifference / 2);

        Double safeA = Math.max(0.0, Math.min(1.0, a));

        return EARTH_RADIUS_KM * 2.0 *
            Math.atan2(Math.sqrt(safeA), Math.sqrt(1.0 - safeA));
    }

    private static List<String> buildConditions(
        String propertyType,
        String status,
        String furnishingStatus,
        Decimal minRent,
        Decimal maxRent
    ) {
        List<String> conditions = new List<String>();

        if (String.isNotBlank(propertyType)) {
            conditions.add('Property_Type__c = :propertyType');
        }
        if (String.isNotBlank(status)) {
            conditions.add('Status__c = :status');
        }
        if (String.isNotBlank(furnishingStatus)) {
            conditions.add('Furnishing_Status__c = :furnishingStatus');
        }
        if (minRent != null) {
            conditions.add('Rent__c >= :minRent');
        }
        if (maxRent != null) {
            conditions.add('Rent__c <= :maxRent');
        }

        return conditions;
    }

    private static void addImageUrls(PropertyResult result) {
        result.imageUrls = new Map<Id, String>();
        Set<Id> propertyIds = new Set<Id>();

        for (Property__c record : result.records) {
            propertyIds.add(record.Id);
        }

        if (propertyIds.isEmpty()) {
            return;
        }

        Set<String> imageTypes = new Set<String>{
            'JPG', 'JPEG', 'PNG', 'GIF', 'WEBP'
        };

        for (ContentDocumentLink linkRecord : [
            SELECT LinkedEntityId, ContentDocumentId,
                   ContentDocument.FileType
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :propertyIds
            ORDER BY SystemModstamp DESC
        ]) {
            if (!result.imageUrls.containsKey(linkRecord.LinkedEntityId) &&
                imageTypes.contains(linkRecord.ContentDocument.FileType)) {
                result.imageUrls.put(
                    linkRecord.LinkedEntityId,
                    '/sfc/servlet.shepherd/document/download/' +
                    linkRecord.ContentDocumentId
                );
            }
        }
    }

    @AuraEnabled
    public static Id createImageStaging() {
        Property_Image_Staging__c staging =
            new Property_Image_Staging__c();

        staging.Upload_Owner__c = UserInfo.getUserId();
        staging.Upload_Status__c = 'Pending';
        staging.Expiry_Time__c = System.now().addHours(1);

        insert staging;
        return staging.Id;
    }

    @AuraEnabled
    public static Id finalizeProperty(
        Property__c propertyRecord,
        Id stagingId
    ) {
        if (propertyRecord == null) {
            throw new AuraHandledException(
                'Please provide property details.'
            );
        }

        if (String.isBlank(propertyRecord.Name)) {
            throw new AuraHandledException('Property Name is required.');
        }

        if (propertyRecord.Rent__c == null ||
            propertyRecord.Rent__c <= 0) {
            throw new AuraHandledException(
                'Monthly rent must be greater than zero.'
            );
        }

        if (String.isBlank(propertyRecord.Description__c)) {
            throw new AuraHandledException(
                'Property Description is required.'
            );
        }

        if (stagingId == null) {
            throw new AuraHandledException(
                'Please upload at least one property image.'
            );
        }

        List<Property_Image_Staging__c> stagingRecords = [
            SELECT Id, Upload_Owner__c, Upload_Status__c, Expiry_Time__c
            FROM Property_Image_Staging__c
            WHERE Id = :stagingId
            LIMIT 1
            FOR UPDATE
        ];

        if (stagingRecords.isEmpty()) {
            throw new AuraHandledException(
                'Upload session was not found. Please reopen the form.'
            );
        }

        Property_Image_Staging__c staging = stagingRecords[0];

        if (staging.Upload_Owner__c != UserInfo.getUserId()) {
            throw new AuraHandledException(
                'You are not authorized to use this upload session.'
            );
        }

        if (staging.Upload_Status__c != 'Pending') {
            throw new AuraHandledException(
                'This upload session is no longer active.'
            );
        }

        if (staging.Expiry_Time__c == null ||
            staging.Expiry_Time__c <= System.now()) {
            throw new AuraHandledException(
                'Your upload session has expired. Please reopen the form.'
            );
        }

        List<ContentDocumentLink> stagingLinks = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :stagingId
        ];

        if (stagingLinks.isEmpty()) {
            throw new AuraHandledException(
                'Upload at least one property image before saving.'
            );
        }

        Set<Id> documentIds = new Set<Id>();
        for (ContentDocumentLink linkRecord : stagingLinks) {
            documentIds.add(linkRecord.ContentDocumentId);
        }

        Map<Id, ContentVersion> latestVersions =
            new Map<Id, ContentVersion>();

        for (ContentVersion versionRecord : [
            SELECT Id, ContentDocumentId, FileExtension, IsLatest
            FROM ContentVersion
            WHERE ContentDocumentId IN :documentIds
            AND IsLatest = true
        ]) {
            latestVersions.put(
                versionRecord.ContentDocumentId,
                versionRecord
            );
        }

        Set<String> allowedExtensions = new Set<String>{
            'jpg', 'jpeg', 'png', 'gif', 'webp'
        };

        for (Id documentId : documentIds) {
            ContentVersion versionRecord = latestVersions.get(documentId);

            if (versionRecord == null ||
                String.isBlank(versionRecord.FileExtension) ||
                !allowedExtensions.contains(
                    versionRecord.FileExtension.toLowerCase()
                )) {
                throw new AuraHandledException(
                    'Only JPG, JPEG, PNG, GIF, and WEBP images are allowed.'
                );
            }
        }

        // Geocode before any DML in this transaction.
        geocodeProperty(propertyRecord);

        insert propertyRecord;

        List<ContentDocumentLink> propertyLinks =
            new List<ContentDocumentLink>();

        for (Id documentId : documentIds) {
            propertyLinks.add(
                new ContentDocumentLink(
                    ContentDocumentId = documentId,
                    LinkedEntityId = propertyRecord.Id,
                    ShareType = 'V',
                    Visibility = 'InternalUsers'
                )
            );
        }

        insert propertyLinks;

        staging.Upload_Status__c = 'Completed';
        staging.Final_Property__c = propertyRecord.Id;
        update staging;

        return propertyRecord.Id;
    }

    private static void geocodeProperty(Property__c propertyRecord) {
        String address = String.join(
            new List<String>{
                propertyRecord.Address__c,
                propertyRecord.City__c,
                propertyRecord.State__c,
                propertyRecord.Postal_Code__c,
                propertyRecord.Country__c
            },
            ', '
        );

        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint(
            'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&q=' +
            EncodingUtil.urlEncode(address, 'UTF-8')
        );
        request.setTimeout(10000);
        request.setHeader(
            'User-Agent',
            'RealEstatePropertyManagementDemo/1.0'
        );

        try {
            HttpResponse response = new Http().send(request);

            if (response.getStatusCode() != 200) {
                throw new AuraHandledException(
                    'Address geocoding failed. Please try again later.'
                );
            }

            List<Object> results = (List<Object>)JSON.deserializeUntyped(
                response.getBody()
            );

            if (results.isEmpty()) {
                throw new AuraHandledException(
                    'Address could not be located. Check the address, city, ' +
                    'state, postal code, and country.'
                );
            }

            Map<String, Object> firstResult =
                (Map<String, Object>)results[0];

            propertyRecord.Latitude__c = Decimal.valueOf(
                String.valueOf(firstResult.get('lat'))
            );
            propertyRecord.Longitude__c = Decimal.valueOf(
                String.valueOf(firstResult.get('lon'))
            );

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to geocode this address. Check Salesforce external ' +
                'access configuration and try again.'
            );
        }
    }
}