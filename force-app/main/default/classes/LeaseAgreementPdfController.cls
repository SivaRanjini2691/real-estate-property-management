public with sharing class LeaseAgreementPdfController {

    @AuraEnabled(cacheable=true)
    public static Lease_Agreement__c getLeaseDetails(Id leaseId) {
        if (leaseId == null) {
            throw new AuraHandledException('A Lease Agreement record is required.');
        }

        try {
            return [
                SELECT Id, Name,
                       Tenant__c, Tenant__r.Name, Tenant__r.Email__c,
                       Property__c, Property__r.Name,
                       Agreed_Monthly_Rent__c,
                       Start_Date__c, End_Date__c,
                       Status__c, Terms__c
                FROM Lease_Agreement__c
                WHERE Id = :leaseId
                WITH USER_MODE
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to retrieve the lease details. Check your record access and field permissions.'
            );
        }
    }

    @AuraEnabled
    public static void sendLeasePdfEmail(Id leaseId, String pdfBase64) {
        if (leaseId == null || String.isBlank(pdfBase64)) {
            throw new AuraHandledException(
                'The lease record and generated PDF are required.'
            );
        }

        try {
            Lease_Agreement__c lease = [
                SELECT Id, Name, Tenant__r.Name, Tenant__r.Email__c
                FROM Lease_Agreement__c
                WHERE Id = :leaseId
                WITH USER_MODE
                LIMIT 1
            ];

            String recipientEmail = lease.Tenant__r.Email__c;

            if (String.isBlank(recipientEmail)) {
                throw new AuraHandledException(
                    'The tenant does not have an email address.'
                );
            }

            Blob pdfBody;

            try {
                pdfBody = EncodingUtil.base64Decode(pdfBase64);
            } catch (Exception decodeError) {
                throw new AuraHandledException(
                    'The generated PDF data is invalid.'
                );
            }

            // Keep the attachment within a conservative email-size limit.
            if (pdfBody.size() > 4000000) {
                throw new AuraHandledException(
                    'The PDF is too large to send as an email attachment.'
                );
            }

            Messaging.EmailFileAttachment attachment =
                new Messaging.EmailFileAttachment();

            attachment.setFileName('Lease_Agreement_' + lease.Name + '.pdf');
            attachment.setContentType('application/pdf');
            attachment.setBody(pdfBody);

            Messaging.SingleEmailMessage email =
                new Messaging.SingleEmailMessage();

            email.setToAddresses(new String[] { recipientEmail });
            email.setSubject('Lease Agreement - ' + lease.Name);
            email.setPlainTextBody(
                'Dear ' + lease.Tenant__r.Name + ',\n\n' +
                'Please find your lease agreement attached as a PDF.\n\n' +
                'Regards,\nProperty Management Team'
            );
            email.setFileAttachments(
                new Messaging.EmailFileAttachment[] { attachment }
            );

            Messaging.SendEmailResult[] results =
                Messaging.sendEmail(
                    new Messaging.SingleEmailMessage[] { email }
                );

            if (results.isEmpty() || !results[0].isSuccess()) {
                throw new AuraHandledException(
                    'Salesforce could not send the lease email. Check your email configuration.'
                );
            }

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to send the lease PDF. Check record access and Salesforce email configuration.'
            );
        }
    }
}