# ICA shopping lists (experimental)

This optional integration uses ICA's **unofficial** mobile shopping-list API. There is no documented consumer shopping-list API or self-service ZSWatch OAuth client. The implementation may need maintenance when ICA changes its app login or private endpoints. No BankID or personal number is required for the working path.

## Verified on 2026-11-02

- ICA's mobile OAuth authorization-code flow with PKCE offered an `icase-email` authenticator. Submitting the account email presented `/authn/authenticate/icase-email/enter-otp`; submitting the six-digit email code produced an authorization code and access/refresh tokens.
- With that access token, `GET https://apimgw-pub.ica.se/sverige/digx/mobile/shoppinglistservice/v1/shoppinglists` returned HTTP 200.
- A disposable test list was created, read, given one free-text row through `POST /{offlineId}/sync`, read again to confirm the row, and deleted. Each operation returned HTTP 200. The disposable list was removed.
- Two further disposable lists showed numeric ICA list IDs increasing in creation order, both above the existing list IDs. The list response itself kept the older test list before the newer one, including after an edit. Both test lists were deleted. The newest-list policy therefore uses the highest numeric ICA ID, not response order or `latestChange`.
- Refreshing the OAuth token with the returned refresh token also returned HTTP 200.
- The older password authenticator returned HTTP 400/500 during the same investigation; ICA's [FAQ](https://www.ica.se/kundservice/vanliga-fragor/) says it removed four-digit password login on 20 January 2026 and recommends email plus one-time code.

Raw probe scripts and responses are under gitignored `.companion-hil-runs/ica-research-2026-11-02/`. They contain session material and must never be committed. The credential file is outside this repository in `~/Documents/zswatch-integration-credentials.json`.

## App design

- Settings → Integrations → ICA shopping lists is opt-in. The app asks for an email and a one-time code, stores the resulting OAuth session in platform secure storage, then reads and writes lists directly from the phone. It never stores the email code. By default, unnamed additions go to the newest ICA list, which is resolved again immediately before confirmation and before writing. If a newer list appears during review, the write stops and asks for another review. The user can turn off this behavior and choose a fixed list; the mode and selected list ID are stored securely and cleared on disconnect. A created list is an ordinary ICA list visible in ICA's own app.
- `IcaSessionService` owns the mobile OAuth flow and serialized token refresh. `IcaShoppingListApi` owns ICA list operations. An HTTP failure during an add does not trigger a blind retry, because the first attempt may have succeeded.
- `packages/llm_integrations` owns the ICA-specific function definition and validates OpenRouter tool-call arguments against the source text. `OpenRouterClient.proposeTools` never executes a call. The app displays a proposal and requires a list selection and confirmation before an ICA write. ICA credentials, list IDs, and list contents are never sent to OpenRouter by this feature.
- The normal voice memo pipeline still uses its existing calendar/task schema. This first integration screen accepts text to exercise the full transcript → OpenRouter proposal → review → ICA write path without changing the native companion journal. Automatic voice memo detection should be a separate opt-in step once on-device behavior is tested.
- This is an in-app function-calling tool contract inspired by MCP. It is **not** an MCP server; no protocol host/client/server or remote tool transport is present. The executor stays in the app, where it can require confirmation and use phone-held credentials.

## OpenRouter experiment

`ai_testbench/bin/shopping_bench.dart` uses only OpenRouter and synthetic transcripts. Run with `--credentials-file` pointing at a JSON file containing `openrouter_api_key`; do not commit that file. The default model is the app's analysis model. The initial 38-case benchmark passed 35/38. The no-speech guard and prompt were tightened; the next full run passed 37/38, with one English memo translated to Swedish (then rejected by grounding validation). After a stronger language instruction, the 12 held-out synthetic cases passed 12/12 and a final full run passed 38/38 at about $0.00491. This is a small synthetic sample, not a guarantee of unattended accuracy. User review remains required.

## Remaining validation

- Test email-code login, token refresh and secure-storage restore on real Android and iOS devices. The sign-in protocol was confirmed in a Python session on this Mac, not on a phone.
- Verify list UI and writes in ICA's own app after a phone-side action.
- Test revoked tokens, account disconnect, interrupted writes, concurrent household edits, and the geography-specific HTTP 451 case.
- Before broad distribution, ask ICA about supported partner access. The current registration flow relies on ICA's existing mobile app client template and could change without notice.
