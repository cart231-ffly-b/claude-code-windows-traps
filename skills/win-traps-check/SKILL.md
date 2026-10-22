---
name: win-traps-check
description: Run the Windows trap reproduction script and report which silent-failure traps happen on this machine. Use when the user runs Claude Code or scripts on Windows and asks why something works by hand but fails when scheduled, redirected, piped or run unattended, or why text turns into ?? or mojibake.
---

1. Only on Windows. If `powershell.exe` is not available, say so and stop.
2. Run exactly this (use `-File`; `-Command` changes exit codes):
   `powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/repro-traps.ps1" -SkipSlow -SkipClaude`
   The script writes only under `tmp\traps` next to itself.
3. Report a table: Id, the result (REPRODUCED, NOT REPRODUCED or CANNOT CHECK), and the observed value the script printed. CANNOT CHECK means there is no real Python on PATH (or only the Microsoft Store stub): say those rows were not tested and point to python.org, instead of reading them as "not affected". On Python 3.15 or later, NOT REPRODUCED for T06 / T07 is expected (UTF-8 is the default there).
4. For each REPRODUCED trap, give the one-line fix from the "Fixes" table in `${CLAUDE_PLUGIN_ROOT}/README.md`. Do not change any files on the user's machine.
5. If the user asked about a specific symptom, say which trap matches it, or that none does.
