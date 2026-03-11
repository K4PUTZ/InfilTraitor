# James Sessions

This directory stores one human-readable session summary per operator run.

Each session file currently records:

- task goal
- final status
- return app
- created and updated timestamps
- notes collected during the run
- evidence paths captured during the run

These summaries are written by `runtime_reports.write_session_summary` when a task finishes.
