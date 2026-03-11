# James Logs

This directory stores structured runtime telemetry and evidence.

Current layout:

- `actions.jsonl`
- `audio/`
- `screenshots/`

`actions.jsonl` is the primary machine-readable execution log. Each record represents one action attempt and can include:

- task id
- step id
- action type
- target
- app before and after
- screenshot paths
- verification result
- final status
- error text

Screenshots and audio artifacts are evidence files referenced by task state and session summaries.
