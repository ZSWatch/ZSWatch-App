# Headless benchmark summary — 2026-03-08

Benchmark scope:
- 9 GGUF models
- 6 strict structured-extraction cases
- Ranking by strict passes first, then average tokens/second

## Ranking

| Rank | Model | Strict passes | Avg tok/s | Total time |
| --- | --- | ---: | ---: | ---: |
| 1 | Qwen3.5-2B-Q4_K_M.gguf | 5/6 | 19.3 | 61.3s |
| 2 | SmolLM3-Q4_K_M.gguf | 4/6 | 16.2 | 51.5s |
| 3 | qwen2.5-1.5b-instruct-q5_k_m.gguf | 2/6 | 26.6 | 39.8s |
| 4 | qwen2.5-1.5b-instruct-q8_0.gguf | 2/6 | 23.6 | 44.2s |
| 5 | Qwen2.5-3B-Instruct-Q4_K_M.gguf | 1/6 | 17.0 | 50.8s |
| 6 | Llama-3.2-3B-Instruct-Q4_K_M.gguf | 1/6 | 16.3 | 42.9s |
| 7 | Qwen2.5-0.5B-Instruct-Q4_K_M.gguf | 0/6 | 71.0 | 13.3s |
| 8 | Qwen3-1.7B-Q4_K_M.gguf | 0/6 | 32.8 | 70.5s |
| 9 | Qwen2.5-1.5B-Instruct-Q4_K_M.gguf | 0/6 | 32.1 | 25.6s |

## Top-model notes

### Qwen3.5-2B-Q4_K_M.gguf
- Passed 5 of 6 cases.
- Passed all calendar/reminder cases except `task_de_deadline`.
- The only miss was action count on the German task case.
- Best overall model in this run.

### SmolLM3-Q4_K_M.gguf
- Passed 4 of 6 cases.
- Strong fallback model.
- Missed `calendar_en_precise` and `calendar_en_with_reminder`.

### Qwen3-1.7B-Q4_K_M.gguf
- Fast, but failed 6 of 6 cases.
- Main failure mode was invalid JSON across the board.
- Not recommended for structured extraction in the app.

## Recommendation

1. Primary recommendation: **Qwen3.5-2B-Q4_K_M.gguf**
   - Best strict accuracy by a clear margin.
   - Speed is acceptable.
   - Use this first if the target runtime remains stable.

2. Safe backup: **SmolLM3-Q4_K_M.gguf**
   - Second-best accuracy.
   - Good fallback if Qwen3.5 shows runtime-specific issues.

3. Do not promote **Qwen3-1.7B-Q4_K_M.gguf**
   - Good speed, but unusable here for strict JSON extraction.
