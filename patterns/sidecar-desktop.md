# Desktop wrapper + local sidecar

**Reference apps:** Feed Forward Desktop (Python engine in a local venv),
Document Lens (PyInstaller sidecar), Debrief (embedded server).

## Shape

- Native shell (Electron/Tauri) owns the UI and lifecycle.
- A packaged or runtime-installed engine runs as a localhost sidecar.
- The shell authenticates to the sidecar (token/port), health-checks it, and
  shuts it down on exit.
- Data and model caches live in app-local directories.

## When to use

- The engine already exists in Python/Rust/Node and rewriting it is wasteful.
- Heavy native/model dependencies are easier to bundle separately.
- You want the desktop app to be a thin, testable client.

## Rules

- Bind the sidecar to `127.0.0.1` only.
- Use an ephemeral port and a per-launch bearer token.
- Do not trust the sidecar blindly; validate responses and surface errors.
- Ship a reproducible engine build per platform/arch.
- Document runtime prerequisites if you install rather than bundle (e.g. Python).
- Handle crash/restart and orphan processes.

## Risks

- Two runtimes to version and patch.
- Code signing must cover the shell and sidecar executables.
- Antivirus/firewall prompts on Windows.
- Sidecar startup latency and model downloads.
