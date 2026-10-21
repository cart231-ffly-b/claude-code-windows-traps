# cc-win-traps

A script that deliberately triggers 14 traps where Claude Code automation on Windows **breaks without an error**, and prints which ones happen on your machine. Read-only except for files under `tmp\traps`.

## Usage

Needs Windows PowerShell 5.1 and Python (T14 also calls `claude`).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\repro-traps.ps1
```

- `-SkipSlow` skips T13 (watching the size of a file being written, a few seconds)
- `-SkipClaude` skips T14 (calls `claude`)

`REPRODUCED` means the trap happened on your machine. **Run it with `-File`**: calling it through `-Command` steps on T01 itself.

## The 14 traps

| Id | What breaks | Author's machine |
| --- | --- | --- |
| T01 | `exit 2` becomes `1` through `-Command` | `-File=2 -Command=1` |
| T02 | `-File` with `-Path a b` silently drops `b` | `count=1`, exit 0 |
| T03 | `-File` with `-Path a,b` gives one string | `first=a,b` |
| T04 | non-ASCII piped to a native program arrives as `?` | bytes `3f3f` |
| T05 | UTF-8 output read with the default code page is mojibake | 2 characters became 4 others |
| T06 | Python crashes only when redirected | UnicodeEncodeError, exit 1 |
| T07 | `python -I` ignores `PYTHONIOENCODING` | 1 with `-I`, 0 without |
| T08 | a non-ASCII `.ps1` without BOM | output differs from source |
| T09 | a `.cmd` with LF line endings runs its comments | `cp932=broken cp65001=ok` |
| T10 | a one-liner: the caller expands `$i` first | syntax error, exit 1 |
| T11 | `-Include` is ignored with `-LiteralPath` | the `.md` came back too |
| T12 | backticks inside `"..."` become newlines or tabs | a newline appeared |
| T13 | a file being written shows 0 bytes (under AppData) | listed 0, actual 5,000,000 |
| T14 | `claude -p --allowedTools X "prompt"` swallows the prompt | `Input must be provided ...` |

Author's machine: Windows 11 / Windows PowerShell 5.1.26100 / Python 3.13.7 / Claude Code 2.1.304, Japanese Windows (code page 932), checked 2026-10-20/21.

**Results differ on English Windows (1252 / 437).** T09 did not break there. T05, T06 and T09 test with your machine's own default code page.

## Fixes

Symptoms, checks and fixes are in a free article (Japanese): https://note.com/sodateru_ai/n/na7d9ee2a36fa

## License

MIT ([LICENSE](LICENSE)).
