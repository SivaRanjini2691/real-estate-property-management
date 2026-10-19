global class LeaseExpiryReminderScheduler implements Schedulable {

    global void execute(SchedulableContext context) {
        Database.executeBatch(
            new LeaseExpiryReminderService(),
            10
        );
    }
}