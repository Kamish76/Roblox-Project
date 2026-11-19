# Stage 2: Plan Contract
- **Inputs:** `.icm/01_spec/output/spec.md` and target source files in `roblox-project`.
- **Process:** Draft exact file changes, state updates, and verification tests.
  - **Branch-First Gate:** Always branch off default branches (`main`, `master`, `dev`) into a dedicated feature branch (`git checkout -b <type>/<short-task-slug>`) before coding begins.
- **Output:** Write `.icm/02_plan/output/plan.md` with `STATUS: PENDING` and `CONVERSATION_ID: <current-conversation-id>`, **and** emit an Antigravity Plan Artifact (`UserFacing: true`, `RequestFeedback: true`) for review. Only set `STATUS: APPROVED` once the user approves (via **Proceed** or chat).
