# macOS Setup

This guide collects the macOS-specific parts that were previously mixed into the main [README](README.md).

## Local Environment Setup

### Prerequisites

- Rocq 8.20.1 (Coq 8.20.1)
- `make`

Optional:

- `uv` for `qcp-mcp` / `rocq-mcp`
- `opam` + `coq-lsp` for `rocq-mcp` interactive tooling

### Choose the Correct QCP Binary Directory

- Apple Silicon: `mac-arm64-binary/`
- Intel Mac: `mac-x86-64-binary/`

You can check with:

```bash
uname -m
```

### Configure Rocq

If you prefer an explicit `CONFIGURE`, create both:

- `SeparationLogic/CONFIGURE`
- `SeparationLogic/unifysl/CONFIGURE`

with:

```ini
COQBIN = /absolute/path/to/coq/bin/
```

### Rocq Installation

Homebrew example:

```bash
brew install opam
opam init -y
eval $(opam env)
opam install coq.8.20.1
```

### Build Rocq Files

```bash
cd SeparationLogic/unifysl
make depend && make
cd ..
make depend && make
```

## QIDE Extension

Set `qide.lspBinPath` to:

- `mac-arm64-binary/lsp` on Apple Silicon
- `mac-x86-64-binary/lsp` on Intel Mac

## QCP Command-Line Tool

Use the matching `symexec` binary from your macOS directory.

## MCP Setup

### Install `uv`

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Configure `qcp-mcp`

```bash
cd mcp/qcp-mcp
uv venv .venv
uv sync
```

Tell `qcp-mcp` where the backend binary is. The MCP-client example in this guide
does this by pointing `QCP_MCP_CONFIG` at a `CONFIGURE` file, so create
`mcp/qcp-mcp/CONFIGURE` (the file does not exist yet) with one of:

```ini
QCP_MCP_BIN=/absolute/path/to/qcp-binary-democases/mac-arm64-binary/mcp
```

or:

```ini
QCP_MCP_BIN=/absolute/path/to/qcp-binary-democases/mac-x86-64-binary/mcp
```

That `QCP_MCP_CONFIG` line in the VS Code example below is what makes this path
take effect. Without `QCP_MCP_CONFIG`, `qcp-mcp` instead looks for the file at
its default location `mcp/qcp-mcp/src/qcp_mcp/CONFIGURE`. Alternatively, skip the
file entirely and set the `QCP_MCP_BIN` environment variable directly.

### Configure `rocq-mcp`

```bash
brew install opam
opam init -y
eval $(opam env)
opam repo add coq-released https://coq.inria.fr/opam/released
opam install -y coq-lsp
pet --version
```

Then install the MCP package:

```bash
cd mcp/rocq-mcp
uv tool install ".[interactive]"
```

### VS Code Copilot MCP Example

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
        "QCP_MCP_CONFIG": "/absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/CONFIGURE"
      }
    },
    "rocq-mcp": {
      "type": "stdio",
      "command": "rocq-mcp",
      "env": {
        "ROCQ_WORKSPACE": "${workspaceFolder}"
      }
    }
  }
}
```

### Claude Code

```bash
claude mcp add -s project qcp -- /absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/.venv/bin/python /absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/server.py
claude mcp add -s project rocq-mcp -- rocq-mcp
```

Config directory:

- `~/Library/Application Support/Claude/`
