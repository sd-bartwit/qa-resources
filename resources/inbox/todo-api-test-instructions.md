# Inbox To-do: API change and test instructions

## What changed

[User story 1382078](https://sdworx.visualstudio.com/Digital%20Channels/_workitems/edit/1382078) introduces support for MAPI's `todo` message tag. In [PR 212067](https://sdworx.visualstudio.com/Digital%20Channels/_git/Channels.ApiGateway/pullrequest/212067), merged as [commit 9d2946c5](https://sdworx.visualstudio.com/Digital%20Channels/_git/Channels.ApiGateway/commit/9d2946c5ad91fa7061d4280219c02cbcd20e75b6), the app BFF:

- Adds `includeTag` and `excludeTag` query parameters to the **v2 list** endpoint and forwards them to CAPI for filtering. It also forwards new `isReadFilter` and `professionalProfileIds` parameters.
- Removes the `todo` tag from every returned message's `tags` array, case-insensitively, **after** receiving the CAPI response. Other tags remain. This applies to both list and single-message responses, including the deprecated v1 endpoints that use the same service.
- Does **not** add an opt-in to return the `todo` tag or a new Boolean property indicating To-do status.

**Important:** filtering by `includeTag=todo` can select To-do messages even though `todo` is absent from their returned `tags`. Do not use the absence of `todo` in the BFF response as proof that an item is not a To-do.

[App story 1411604](https://sdworx.visualstudio.com/Digital%20Channels/_workitems/edit/1411604) describes client-side detection using `tags` containing `todo`. That cannot work with the behavior above unless another change exposes the tag. Confirm the intended contract with the API/app team before treating this PR as sufficient for that app story.

## Prerequisites

- Confirm the target environment has a deployment containing the merge commit. A merged PR or the story's `ACC` tag alone does not prove deployment.
- Sign in with an acceptance test account and use a current bearer token. Prepare at least one independently confirmed To-do message and one non-To-do message, preferably with stable IDs. Establish their classification from an accessible upstream CAPI/MAPI response or controlled test data; the BFF response cannot supply this evidence.
- The examples use the acceptance app gateway. Reuse any other headers required by a successful app request captured in HTTP Toolkit. Never save a bearer token in the test document.

## API requests and response files

Send these authenticated `GET` requests with the same account and other filters, close together while the inbox is unchanged. Defaults are `page=1`, `pageSize=10`, and `isVisibleOnHomeScreen=false`; these examples specify them explicitly.

Save each response body in its corresponding file. The linked files hold captured acceptance responses for QA test messages; overwrite them when re-running. If a group fits on one page (`result.hasMore` is `false`), save the response object as-is. Otherwise increment `page` until all pages are captured, and save them as a JSON array of complete page responses in the same file. Do this separately for each group. Never save bearer tokens or real employee data in version control.

### Group A: all messages

No tag filter. Save to [group-a-all.json](group-a-all.json).

```http
GET https://api.acc.sdworx.com/mysdworxappgateway/api/2.0/me/newsfeeditems?page=1&pageSize=10&isVisibleOnHomeScreen=false
Authorization: Bearer <token>
```

### Group B: exclude To-do

Save to [group-b-exclude-todo.json](group-b-exclude-todo.json).

```http
GET https://api.acc.sdworx.com/mysdworxappgateway/api/2.0/me/newsfeeditems?page=1&pageSize=10&isVisibleOnHomeScreen=false&excludeTag=todo
Authorization: Bearer <token>
```

### Group C: only To-do

Save to [group-c-include-todo.json](group-c-include-todo.json).

```http
GET https://api.acc.sdworx.com/mysdworxappgateway/api/2.0/me/newsfeeditems?page=1&pageSize=10&isVisibleOnHomeScreen=false&includeTag=todo
Authorization: Bearer <token>
```

The app-facing filter parameters are passed to CAPI's `api/v2/messages/me/newsfeeditems`. The PR proves forwarding, not the upstream matching rules or deployment state; verify filtering end to end using known data.

## What to check

0. **Prepare test data:** Make sure the acceptance test account has at least one published message tagged `todo` and one without it. Record their IDs and confirm they are available to the account before testing. Without such data, the To-do filtering results are inconclusive.
1. **Group A:** Call without `includeTag` or `excludeTag` and save all messages.
2. **Include To-do (group C):** Call with `includeTag=todo`. Check all returned `newsfeedId` values also appear in A.
3. **Exclude To-do (group B):** Call with `excludeTag=todo`. Check all returned IDs also appear in A, none appear in C, and B and C together contain all IDs in A. The BFF removes `todo` from `tags` in all three responses.
4. **Repeat for an expense-related tag:** Find the exact tag in `tags` on a recognisable expense message in A. Call with `includeTag=<expense-tag>` and `excludeTag=<expense-tag>`, replacing the placeholder with that exact value. Compare their IDs with A using the same checks as above; confirm recognisable expense messages are in the included group and not the excluded group.

Check HTTP `200` and `state: "Success"` for every page, and compare **all pages**. If possible, also confirm a known To-do ID is in C and a known non-To-do ID is in B: a clean split alone does not prove correct classification. An empty group is inconclusive without suitable test data.

If the sets differ, first check pagination, access, profile, other filters and whether messages changed between requests. The PR's integration tests cover removing `TODO` in list and detail responses using CAPI fixtures; they do not establish that filtering works against a live upstream service.

## App/UI test limitation

To test the separate app story before the API contract is aligned, a manually configured HTTP Toolkit Modify rule can supply a BFF **response** containing both `tags: ["todo"]` and an item without that tag. This tests UI behavior only, not whether the real BFF exposes the tag. The AI's HTTP Toolkit integration cannot create the rule; configure it in the UI and reset the mock afterward.

The group files contain live acceptance responses captured for QA test messages published on 2026-11-26. Deployment of the merge commit was not separately verified.
