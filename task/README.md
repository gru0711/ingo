# Agentic coding task: Quartz-style day-of-month specifiers

This folder packages a coding task built on this repository's baseline: cron-parser 5.10.1, commit `5b08cdf831c94a656def5a6ab7008f1e497d21b2`, MIT. The task asks for `nW`, `LW`, `L-n` and `L-nW` support in the day-of-month field. The full specification is in [TASK.md](TASK.md).

## Contents

| Path | Purpose |
|---|---|
| `TASK.md` | Agent-facing problem statement and acceptance criteria |
| `Dockerfile`, `.dockerignore` | Offline agent environment: baseline source, locked dependencies, compiled build, `TASK.md` |
| `vendor/cron-parser-5b08cdf.bundle` | The baseline history as a `git bundle`, so the image build does not need GitHub |
| `scripts/` | Build the image, run baseline tests offline, open an agent shell, export the agent's patch, check offline operation |

Grading uses private verifiers and a reference solution, which are deliberately **not** part of this repository.

## Usage

Run from this folder in a Linux or WSL shell with Docker. Building needs network access for `npm ci`; nothing after that does.

```bash
bash scripts/build-image.sh                              # build cron-parser-w-task:baseline
bash scripts/run-baseline-tests.sh                       # build, 338 Jest tests, lint and tsd, offline
bash scripts/verify-offline.sh                           # show the container has no network
bash scripts/agent-shell.sh my-agent                     # interactive offline workspace
bash scripts/extract-patch.sh my-agent candidate.patch   # export the agent's changes
```
