# James State

This directory stores the live runtime state James uses between commands.

Current files:

- `runtime_state.json` — current task, task history, and completed tasks
- `brain_request.json` — outbound structured request for the planning brain
- `brain_response.json` — executable response plan returned by the planning brain

`runtime_state.json` is the source of truth for task continuity across commands.
