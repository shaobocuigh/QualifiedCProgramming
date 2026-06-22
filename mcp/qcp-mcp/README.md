# qcp-mcp

`qcp-mcp` is the MCP wrapper for the repository's QCP binary. It starts the
underlying `mcp` executable, keeps a session alive, and exposes tools such as
`load_target_file`, `check`, `step`, `symbolic`, `proof`, and `close`.

## Prerequisites

- Python 3.12+
- The repository `mcp` binary
  - Linux / WSL: `linux-binary/mcp`
  - Windows: `win-binary/mcp.exe`

## Configuration

`qcp-mcp` finds the backend `mcp` binary in two tiers:

1. **`QCP_MCP_BIN`** (environment variable) — if set, its value is used directly
   as the binary path. This is the recommended approach and is what every
   MCP-client example below uses.
2. **A `CONFIGURE` file** — only consulted when `QCP_MCP_BIN` is unset. The path
   to this file comes from `QCP_MCP_CONFIG`; if that is also unset, it defaults to
   the bundled location `src/qcp_mcp/CONFIGURE` (next to `session.py`).

`QCP_MCP_CONFIG` and `CONFIGURE` are therefore *not* two separate sources —
`QCP_MCP_CONFIG` only says *where* the `CONFIGURE` file lives.

The `CONFIGURE` file is not shipped with the repo; you create it. It needs a
single `QCP_MCP_BIN=` line, for example:

```ini
QCP_MCP_BIN=/absolute/path/to/qcp-binary-democases/linux-binary/mcp
```

or, on Windows:

```ini
QCP_MCP_BIN=D:/absolute/path/to/qcp-binary-democases/win-binary/mcp.exe
```

If `QCP_MCP_BIN` is set in the environment, you do not need a `CONFIGURE` file at
all.

## Linux / WSL Setup

```bash
cd mcp/qcp-mcp
uv venv .venv
uv sync
```

Optional fallback, only if you are *not* setting `QCP_MCP_BIN` — create a
`CONFIGURE` file at the default `src/qcp_mcp/CONFIGURE`, or anywhere you like and
point `QCP_MCP_CONFIG` at it, containing:

```ini
QCP_MCP_BIN=/absolute/path/to/qcp-binary-democases/linux-binary/mcp
```

## Windows / PowerShell Setup

```powershell
Set-Location mcp\qcp-mcp
py -3 -m venv .venv-win
.\.venv-win\Scripts\python.exe -m pip install -e .
Set-Location ..\..
. .\scripts\setup-windows-mcp-env.ps1
```

The PowerShell setup script exports:

- `QCP_MCP_BIN`
- `QCP_MCP_PYTHON`
- `QCP_MCP_CONFIG`
- `COQC_EXE`
- `COQTOP_EXE`

Recommended Windows usage:

- Keep a `CONFIGURE` file available for Linux / WSL if needed (default location
  `src/qcp_mcp/CONFIGURE`, or wherever `QCP_MCP_CONFIG` points).
- Use `QCP_MCP_BIN` from `setup-windows-mcp-env.ps1` for PowerShell.

## Smoke Test

Linux / WSL:

```bash
PYTHONPATH=$PWD/src QCP_MCP_BIN=/absolute/path/to/qcp-binary-democases/linux-binary/mcp \
  .venv/bin/python -m qcp_mcp.server
```

Windows:

```powershell
$env:QCP_MCP_BIN = 'D:\absolute\path\to\qcp-binary-democases\win-binary\mcp.exe'
.\.venv-win\Scripts\python.exe -m qcp_mcp.server
```

To test actual tool behavior on Windows:

```powershell
@'
import asyncio, json
from qcp_mcp.server import initialize, check, symbolic, close

TARGET = r"D:\absolute\path\to\qcp-binary-democases\QCP_examples\QCP_demos_LLM\simple_arith\add.c"

async def main():
    await initialize(TARGET)
    chk = json.loads(await check(10))
    sym = json.loads(await symbolic(57))
    print("check:", chk["result"], chk["functionName"])
    print("symbolic:", sym["result"], sym["functionName"])
    print(await close())

asyncio.run(main())
'@ | .\mcp\qcp-mcp\.venv-win\Scripts\python.exe -
```

## MCP Client Configuration

### VS Code Copilot

Linux / WSL:

```json
{
  "servers": {
    "qcp": {
      "type": "stdio",
      "command": "/absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/.venv/bin/python",
      "args": [
        "-m",
        "qcp_mcp.server"
      ],
      "env": {
        "PYTHONPATH": "/absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/src",
        "QCP_MCP_BIN": "/absolute/path/to/qcp-binary-democases/linux-binary/mcp"
      }
    }
  }
}
```

Windows:

```json
{
  "servers": {
    "qcp": {
      "type": "stdio",
      "command": "D:/absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/.venv-win/Scripts/python.exe",
      "args": [
        "-m",
        "qcp_mcp.server"
      ],
      "env": {
        "PYTHONPATH": "D:/absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/src",
        "QCP_MCP_BIN": "D:/absolute/path/to/qcp-binary-democases/win-binary/mcp.exe"
      }
    }
  }
}
```

### Claude Code

Linux / WSL:

```bash
claude mcp add -s project qcp --env QCP_MCP_BIN=/absolute/path/to/qcp-binary-democases/linux-binary/mcp -- /absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/.venv/bin/python -m qcp_mcp.server
```

Windows:

```powershell
claude mcp add -s project qcp --env QCP_MCP_BIN=D:/absolute/path/to/qcp-binary-democases/win-binary/mcp.exe -- D:/absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/.venv-win/Scripts/python.exe -m qcp_mcp.server
```

### Codex

Linux / WSL:

```bash
codex mcp add qcp --env PYTHONPATH=/absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/src --env QCP_MCP_BIN=/absolute/path/to/qcp-binary-democases/linux-binary/mcp -- /absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/.venv/bin/python -m qcp_mcp.server
```

Windows:

```powershell
codex mcp add qcp --env PYTHONPATH=D:/absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/src --env QCP_MCP_BIN=D:/absolute/path/to/qcp-binary-democases/win-binary/mcp.exe -- D:/absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/.venv-win/Scripts/python.exe -m qcp_mcp.server
```
