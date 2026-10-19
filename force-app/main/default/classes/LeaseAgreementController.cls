public with sharing class LeaseAgreementController {

    public class LeaseResult {
        @AuraEnabled public List<Lease_Agreement__c> records { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
    }

    // =====================================================
    // GET LEASE AGREEMENTS
    // =====================================================

    @AuraEnabled(cacheable=true)
    public static LeaseResult getLeaseAgreements(
        String searchKey,
        String leaseStatus
    ) {
        String searchTerm = '%' +
            (String.isBlank(searchKey) ? '' : searchKey.trim()) + '%';

        LeaseResult result = new LeaseResult();

        String queryString =
            'SELECT Id, Name, Tenant__c, Tenant__r.Name, ' +
            'Property__c, Property__r.Name, ' +
            'Agreed_Monthly_Rent__c, Start_Date__c, End_Date__c, ' +
            'Status__c, Terms__c ' +
            'FROM Lease_Agreement__c ' +
            'WHERE Name LIKE :searchTerm';

        if (!String.isBlank(leaseStatus)) {
            queryString += ' AND Status__c = :leaseStatus';
        }

        queryString += ' ORDER BY CreatedDate DESC LIMIT 200';

        result.records = (List<Lease_Agreement__c>) Database.queryWithBinds(
            queryString,
            new Map<String, Object>{
                'searchTerm' => searchTerm,
                'leaseStatus' => leaseStatus
            },
            AccessLevel.USER_MODE
        );

        result.totalRecords = result.records.size();

        return result;
    }

    // =====================================================
    // CREATE LEASE AGREEMENT
    // =====================================================

    @AuraEnabled
    public static Id createLeaseAgreement(
        Id tenantId,
        Id propertyId,
        Decimal agreedMonthlyRent,
        Date startDate,
        Date endDate,
        String leaseTerms,
        String leaseStatus
    ) {
        if (tenantId == null) {
            throw new AuraHandledException('Please select a tenant.');
        }

        if (propertyId == null) {
            throw new AuraHandledException('Please select a property.');
        }

        if (agreedMonthlyRent == null || agreedMonthlyRent <= 0) {
            throw new AuraHandledException(
                'Agreed monthly rent must be greater than zero.'
            );
        }

        if (startDate == null || endDate == null) {
            throw new AuraHandledException(
                'Lease start date and end date are required.'
            );
        }

        if (endDate <= startDate) {
            throw new AuraHandledException(
                'Lease end date must be later than the start date.'
            );
        }

        if (String.isBlank(leaseTerms)) {
            throw new AuraHandledException(
                'Please enter the lease terms.'
            );
        }

        String statusToUse = String.isBlank(leaseStatus)
            ? 'Draft'
            : leaseStatus;

        Set<String> allowedStatuses = new Set<String>{
            'Draft', 'Active', 'Expired', 'Terminated'
        };

        if (!allowedStatuses.contains(statusToUse)) {
            throw new AuraHandledException('Invalid lease status.');
        }

        Lease_Agreement__c lease = new Lease_Agreement__c(
            Tenant__c = tenantId,
            Property__c = propertyId,
            Agreed_Monthly_Rent__c = agreedMonthlyRent,
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Terms__c = leaseTerms,
            Status__c = statusToUse
        );

        insert as user lease;

        return lease.Id;
    }

    // =====================================================
    // SEARCH TENANTS
    // =====================================================

    @AuraEnabled(cacheable=true)
    public static List<Tenant__c> getTenantOptions(String searchKey) {

        String searchTerm = '%' +
            (String.isBlank(searchKey) ? '' : searchKey.trim()) + '%';

        try {
            return [
                SELECT Id, Name, Email__c
                FROM Tenant__c
                WHERE Name LIKE :searchTerm
                WITH USER_MODE
                ORDER BY Name
                LIMIT 50
            ];
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to search tenants. Check object and field permissions.'
            );
        }
    }

    // =====================================================
    // SEARCH PROPERTIES
    // =====================================================

    @AuraEnabled(cacheable=true)
    public static List<Property__c> getPropertyOptions(String searchKey) {

        String searchTerm = '%' +
            (String.isBlank(searchKey) ? '' : searchKey.trim()) + '%';

        try {
            return [
                SELECT Id, Name, City__c, Rent__c, Status__c
                FROM Property__c
                WHERE Name LIKE :searchTerm
                WITH USER_MODE
                ORDER BY Name
                LIMIT 50
            ];
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to search properties. Check object and field permissions.'
            );
        }
    }
}