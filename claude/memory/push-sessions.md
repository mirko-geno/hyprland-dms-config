---
name: push-sessions
description: "When committing in hyprland-dms-config, run ./backup.sh first and include claude/ sessions + memory in the commit"
metadata:
  node_type: memory
  type: feedback
  originSessionId: eeed0d7f-4d25-444e-9548-ec2388dbeae4
  modified: 2026-11-24T10:02:31.310Z
---

When the user asks to commit/push in ~/hyprland-dms-config, run `./backup.sh` first and commit the `claude/` sessions (*.jsonl) and memory too, not only the files I changed.

**Why:** user said (2026-11-24) "se supone que la session siempre debería pushearse"; I had committed only restore.sh/README and left the sessions out.

**How to apply:** `./backup.sh && git add -A` before committing; tell the user about any other unrelated diffs it brings in (e.g. DMS-generated files). Related: [[hyprland-dms-setup]].
