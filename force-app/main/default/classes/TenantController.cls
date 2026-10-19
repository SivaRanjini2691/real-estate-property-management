public with sharing class TenantController {

    @AuraEnabled(cacheable=true)
    public static List<Tenant__c> getTenants(String searchKey) {

        String searchTerm = '%' +
            (String.isBlank(searchKey) ? '' : searchKey.trim()) +
            '%';

        return [
            SELECT Id,
                   Name,
                   Phone_Number__c,
                   Email__c,
                   CreatedDate
            FROM Tenant__c
            WHERE Name LIKE :searchTerm
               OR Email__c LIKE :searchTerm
               OR Phone_Number__c LIKE :searchTerm
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static Id createTenant(
        String tenantName,
        String phoneNumber,
        String emailAddress
    ) {

        if (String.isBlank(tenantName)) {
            throw new AuraHandledException(
                'Tenant name is required.'
            );
        }

        if (String.isBlank(emailAddress)) {
            throw new AuraHandledException(
                'Tenant email is required.'
            );
        }

        Tenant__c tenant = new Tenant__c(
            Name = tenantName.trim(),
            Phone_Number__c = phoneNumber,
            Email__c = emailAddress.trim()
        );

        insert as user tenant;

        return tenant.Id;
    }
}