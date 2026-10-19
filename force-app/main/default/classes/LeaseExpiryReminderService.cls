global without sharing class LeaseExpiryReminderService
    implements Database.Batchable<SObject> {

    private Date oneMonthDate;
    private Date oneDayDate;

    global LeaseExpiryReminderService() {
        oneMonthDate = Date.today().addMonths(1);
        oneDayDate = Date.today().addDays(1);
    }

    global Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   End_Date__c,
                   Status__c,
                   Tenant__c,
                   Tenant__r.Name,
                   Tenant__r.Email__c,
                   Property__r.Name
            FROM Lease_Agreement__c
            WHERE Status__c = 'Active'
              AND End_Date__c != null
              AND End_Date__c IN :new Set<Date>{
                  oneMonthDate,
                  oneDayDate
              }
              AND Tenant__c != null
        ]);
    }

    global void execute(
        Database.BatchableContext context,
        List<Lease_Agreement__c> leases
    ) {
        if (leases.isEmpty()) {
            return;
        }

        Date todayDate = Date.today();

        Map<String, Lease_Reminder_Log__c> existingLogs =
            new Map<String, Lease_Reminder_Log__c>();

        Set<String> reminderKeys = new Set<String>();

        for (Lease_Agreement__c lease : leases) {
            if (lease.End_Date__c == todayDate.addMonths(1)) {
                reminderKeys.add(buildKey(lease.Id, 'ONE_MONTH'));
            }

            if (lease.End_Date__c == todayDate.addDays(1)) {
                reminderKeys.add(buildKey(lease.Id, 'ONE_DAY'));
            }
        }

        if (reminderKeys.isEmpty()) {
            return;
        }

        for (Lease_Reminder_Log__c logRecord : [
            SELECT Id, Reminder_Key__c
            FROM Lease_Reminder_Log__c
            WHERE Reminder_Key__c IN :reminderKeys
        ]) {
            existingLogs.put(logRecord.Reminder_Key__c, logRecord);
        }

        List<Messaging.SingleEmailMessage> messages =
            new List<Messaging.SingleEmailMessage>();

        List<Lease_Reminder_Log__c> pendingLogs =
            new List<Lease_Reminder_Log__c>();

        for (Lease_Agreement__c lease : leases) {
            if (String.isBlank(lease.Tenant__r.Email__c)) {
                continue;
            }

            String reminderType;
            String subject;
            String messageBody;

            if (lease.End_Date__c == todayDate.addMonths(1)) {
                reminderType = 'ONE_MONTH';
                subject = 'Lease Expiry Reminder - One Month Remaining';

                messageBody =
                    'Dear ' + lease.Tenant__r.Name + ',\n\n' +
                    'This is a reminder that your lease agreement ' +
                    lease.Name + ' is scheduled to expire on ' +
                    String.valueOf(lease.End_Date__c) + '.\n\n' +
                    'There is approximately one month remaining on your lease. ' +
                    'Please contact the property management team to discuss ' +
                    'renewal or the next steps.\n\n' +
                    'Property: ' +
                    (lease.Property__r == null
                        ? 'Not specified'
                        : lease.Property__r.Name) +
                    '\n\nRegards,\nProperty Management Team';

            } else if (lease.End_Date__c == todayDate.addDays(1)) {
                reminderType = 'ONE_DAY';
                subject = 'Urgent: Your Lease Expires Tomorrow';

                messageBody =
                    'Dear ' + lease.Tenant__r.Name + ',\n\n' +
                    'This is a reminder that your lease agreement ' +
                    lease.Name + ' is scheduled to expire tomorrow, ' +
                    String.valueOf(lease.End_Date__c) + '.\n\n' +
                    'Please contact the property management team promptly ' +
                    'regarding renewal or the next steps.\n\n' +
                    'Property: ' +
                    (lease.Property__r == null
                        ? 'Not specified'
                        : lease.Property__r.Name) +
                    '\n\nRegards,\nProperty Management Team';
            } else {
                continue;
            }

            String key = buildKey(lease.Id, reminderType);

            if (existingLogs.containsKey(key)) {
                continue;
            }

            Messaging.SingleEmailMessage email =
                new Messaging.SingleEmailMessage();

            email.setToAddresses(
                new String[] { lease.Tenant__r.Email__c }
            );
            email.setSubject(subject);
            email.setPlainTextBody(messageBody);
            email.setSaveAsActivity(false);

            messages.add(email);

            pendingLogs.add(new Lease_Reminder_Log__c(
                Lease_Agreement__c = lease.Id,
                Reminder_Type__c = reminderType,
                Reminder_Key__c = key
            ));
        }

        if (messages.isEmpty()) {
            return;
        }

        // Process the email messages in groups of no more than 10.
        Integer index = 0;

        while (index < messages.size()) {
            List<Messaging.SingleEmailMessage> emailBatch =
                new List<Messaging.SingleEmailMessage>();

            List<Lease_Reminder_Log__c> logBatch =
                new List<Lease_Reminder_Log__c>();

            for (
                Integer i = index;
                i < Math.min(index + 10, messages.size());
                i++
            ) {
                emailBatch.add(messages[i]);
                logBatch.add(pendingLogs[i]);
            }

            Messaging.SendEmailResult[] results =
                Messaging.sendEmail(emailBatch, false);

            List<Lease_Reminder_Log__c> successfulLogs =
                new List<Lease_Reminder_Log__c>();

            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    logBatch[i].Sent_Date_Time__c = System.now();
                    successfulLogs.add(logBatch[i]);
                } else {
                    for (Messaging.SendEmailError error :
                        results[i].getErrors()) {
                        System.debug(
                            LoggingLevel.ERROR,
                            'Lease reminder email failed: ' +
                            error.getMessage()
                        );
                    }
                }
            }

            if (!successfulLogs.isEmpty()) {
                Database.SaveResult[] saveResults =
                    Database.insert(successfulLogs, false);

                for (Integer i = 0; i < saveResults.size(); i++) {
                    if (!saveResults[i].isSuccess()) {
                        System.debug(
                            LoggingLevel.ERROR,
                            'Unable to log a sent lease reminder. ' +
                            'A duplicate email may be possible on a later run.'
                        );
                    }
                }
            }

            index += 10;
        }
    }

    global void finish(Database.BatchableContext context) {
        System.debug('Lease expiry reminder batch completed.');
    }

    private static String buildKey(Id leaseId, String reminderType) {
        return String.valueOf(leaseId) + '_' + reminderType;
    }
}