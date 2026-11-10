# ADR 0001: Local-first is the default

Status: accepted.

## Decision

New apps default to local-first: data on the user’s machine, BYOK AI providers,
local/offline fallback, no telemetry, no mandatory account.

A server is added only when collaboration, institutional hosting, or shared data
is a real requirement. When added, keep a local mode where practical.

## Consequences

- Privacy and offline use are product features.
- Distribution and signing become the operational burden instead of servers.
- Data format and export paths must be documented.
- Collaboration cannot be bolted on without a migration plan; design the data
  layer so sync remains possible.
