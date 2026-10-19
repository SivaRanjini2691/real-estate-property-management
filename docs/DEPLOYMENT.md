# Deployment Guide

## Before deployment

- Confirm the correct Salesforce org alias.
- Review Git status and save all intended source files.
- Verify `sfdx-project.json` and API versions.
- Confirm required objects, fields, validation rules and static resources are included.
- Check restricted picklist values against Apex constants/strings.
- Ensure secrets and authentication artifacts are excluded from Git.

## Verify org authentication

```powershell
sf org list
sf org display --target-org RealEstateDev
```

## Deploy a specific Apex controller

```powershell
sf project deploy start `
  --source-dir force-app/main/default/classes/LeaseAgreementPdfController.cls `
  --target-org RealEstateDev `
  --wait 10
```

## Deploy a Lightning Web Component

```powershell
sf project deploy start `
  --source-dir force-app/main/default/lwc/leaseAgreementActions `
  --target-org RealEstateDev `
  --wait 10
```

## Deploy the full source tree

```powershell
sf project deploy start `
  --source-dir force-app/main/default `
  --target-org RealEstateDev `
  --wait 30
```

Use the complete-source deployment only when the source tree is intended to be deployed and dependencies are satisfied. Review errors carefully; do not repeatedly redeploy without resolving the reported issue.

## Run tests after deployment

```powershell
sf apex run test `
  --target-org RealEstateDev `
  --test-level RunLocalTests `
  --code-coverage `
  --result-format human `
  --wait 30
```

Do not promote to production until relevant tests pass, permissions and page placement are verified, and any asynchronous jobs have been checked.

## Schedule reminders

Review `LeaseExpiryReminderScheduler` and the current scheduling approach. Confirm:
- expected schedule expression/time zone;
- only one intended active job exists;
- reminder behavior is tested;
- email deliverability is configured;
- picklist values and duplicate prevention are verified.

## Rollback

Use your team's approved Salesforce deployment/release procedure. For source-controlled metadata, revert the specific Git commit and deploy the reviewed previous version. Do not use destructive changes or force-push without understanding the effect on the target org and remote repository.
