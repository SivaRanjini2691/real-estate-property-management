# Testing Strategy

## Goals

- Prove expected business behavior, not merely execute lines.
- Validate input checks, error paths, bulk processing and related-record behavior.
- Measure coverage per Apex class using Salesforce test results.
- Keep UI Jest tests separate from Apex tests.

## Apex test categories

### Controller tests
For each controller, cover:
- Successful queries and DML.
- Empty result sets.
- Null/blank/invalid inputs.
- Invalid status or picklist values.
- Record relationships and field values.
- Expected handled exceptions.
- Permission-sensitive behavior where feasible.

### Trigger/service tests
For maintenance vendor assignment:
- Single request with no explicit vendor.
- Request with an explicitly chosen vendor.
- Multiple requests in one insert.
- Inactive-vendor/no-vendor scenarios.
- Existing workload and status behavior.
- Confirm all inserted records have expected assignments.

For lease reminders:
- No eligible leases.
- One-month and one-day expiry boundaries.
- Missing tenant email.
- Existing reminder log / duplicate key.
- Email success/failure handling.
- Scheduler registration and batch execution.

### PDF controller tests
- Valid lease details returned with tenant/property relationships.
- Null and unknown lease IDs.
- Missing tenant email.
- Blank and invalid Base64 payload.
- Attachment-size validation.
- Email invocation behavior using `Limits.getEmailInvocations()` where applicable.

## Run Apex tests

```powershell
sf apex run test `
  --target-org RealEstateDev `
  --test-level RunLocalTests `
  --code-coverage `
  --result-format human `
  --wait 30
```

Review:
- `TEST RESULTS` for failed methods and exception messages.
- `APEX CODE COVERAGE BY CLASS` for each class.
- `TEST SUMMARY` for total pass/fail counts.
- Org-wide coverage as a separate metric from per-class quality.

A coverage target above 80% per class is a project goal, not a claim of achieved coverage. Confirm with actual Salesforce output.

## Diagnose failures

For each failure:
1. Read the first exception line.
2. Identify whether it originates from test data, metadata/picklist configuration, required fields, validation rules, permissions, or application logic.
3. Correct the cause rather than weakening assertions.
4. Re-run the failing test class.
5. Re-run the full local test suite before merging.

## Test data practices

- Create isolated test data; do not depend on existing org records.
- Use `@TestSetup` for shared data when appropriate.
- Avoid hard-coded record IDs.
- Set all required fields and valid restricted picklist values.
- Use `Test.startTest()` and `Test.stopTest()` around asynchronous execution.
- Assert exact outcomes and side effects.
- Include bulk tests for trigger-driven logic.

## LWC tests

Jest tests are present under each component's `__tests__` directory. Verify loading, user interactions, Apex mock responses, success messages and error handling. Run the project's configured npm test command if package scripts and dependencies are present; consult `package.json` rather than assuming a command.
