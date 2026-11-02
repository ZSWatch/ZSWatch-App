# ICA shopping lists

Say "köp mjölk och två paket kaffe" in a voice memo and the items are added
to your ICA shopping list.

## Flow

1. **Connect** in Settings → Integrations. `IcaSessionService` runs ICA's
   email-code OAuth sign-in in Dart and hands the session to the native owner
   (`setIcaSession`). Native stores it in the Keystore / Keychain; Dart keeps
   nothing.
2. **Analysis.** When ICA is connected and the job runs on OpenRouter, native
   adds `integrations: {shopping_list: true}` to the worker request.
   `LlmService` then inserts `ShoppingIntent.section` into the normal analysis
   prompt. All products go in one `shopping` action with an `items` array.
   Local models never see the section, and shopping output from a prompt
   without it is dropped.
3. **Add.** A shopping action works like calendar actions. The watch shows the
   result with Undo. When the undo window ends, the native owner adds the items
   to the target list (`IcaShoppingList.kt` / `IOSIcaShoppingList.swift`). The
   app's action card can also add, retry or remove the items.
4. **Undo** after the add deletes exactly the rows the action wrote.

## Target list

- The default is the newest list, meaning the highest numeric `id`; ICA
  assigns these in creation order.
- If any list has no `id`, or two lists share one, nothing is added
  (`ICA_NO_LIST`).
- The user can pick a fixed list instead.

## Idempotency

Row `offlineId`s are name-based UUIDs (MD5, v3) of
`zswatch://voice-action/<job>/<index>/<n>`. Android and iOS produce the same
IDs. Before adding, the owner looks for the first row ID in every list. A
retry after a crash or timeout therefore finds the rows it already wrote
instead of adding them twice.

Failures that prove nothing changed (offline before the write, 4xx, not
connected, no list) release the action so it can be retried. Other failures
keep it in `creating` and are reported as `ICA_OUTCOME_UNKNOWN`.

## API (unofficial, mobile)

Base URL:
`https://apimgw-pub.ica.se/sverige/digx/mobile/shoppinglistservice/v1/shoppinglists`

| Call | Request |
| --- | --- |
| Lists | `GET /` → `shoppingLists[]` |
| Add | `POST /{offlineId}/sync` `{"createdRows":[{offlineId, productName, sourceId:-1, isStrikedOver:false, recipes:[]}]}` |
| Remove | `POST /{offlineId}/sync` `{"deletedRows":[rowOfflineId]}` |
| Refresh | `POST https://ims.icagruppen.se/oauth/v2/token` with `grant_type=refresh_token` and Basic `client_id:client_secret` |

Verified live on a disposable list on 2026-11-02:

- UUID row IDs and `sourceId:-1` are accepted for several rows.
- Re-syncing the same IDs adds no duplicates.
- `deletedRows` removes the rows, and repeating it succeeds.
- A new list gets the highest `id`.

ICA can change or block this API at any time.

## Benchmark

`zswatch_app/test/benchmarks/shopping_benchmark_test.dart` sends 34
synthetic memos through the production worker (`processCompanionVoiceRecording`
with a saved transcript) to OpenRouter. Each run checks the extracted items,
the other actions in the memo, and the long-memo (brain dump) path. It is
skipped in CI.

```sh
cd zswatch_app
ZSWATCH_BENCH=1 flutter test test/benchmarks/shopping_benchmark_test.dart
```

Optional settings:

- `ZSWATCH_BENCH_MODEL`, default `google/gemini-3.1-flash-lite`.
- `ZSWATCH_BENCH_RUNS`, default 3.
- `ZSWATCH_BENCH_CASES`, a comma-separated list of case names.

Reports, including the raw model replies, go to
`.companion-hil-runs/shopping-bench/`. On 2026-11-02,
gemini-3.1-flash-lite passed 102/102 cases (3 runs), with a median of about 1 s
per memo.
