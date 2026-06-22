# Linux Setup

This guide collects the Linux-specific parts that were previously mixed into the main [README](README.md).

## Local Environment Setup

### Prerequisites

- Rocq 8.20.1 (Coq 8.20.1), recommended with OCaml 4.14.1
- `make`

Optional:

- `uv` for `qcp-mcp` / `rocq-mcp`
- `opam` + `coq-lsp` for `rocq-mcp` interactive tooling

### Rocq Installation

We recommend installing Rocq 8.20.1 via `opam`:

```bash
sudo apt update
sudo apt install -y opam
opam init
eval $(opam env)
opam install coq.8.20.1
```

With this setup:

- you usually do not need `SeparationLogic/CONFIGURE`
- you can use the VS Code `vsrocq` extension directly

If you prefer an explicit `CONFIGURE`, create both:

- `SeparationLogic/CONFIGURE`
- `SeparationLogic/unifysl/CONFIGURE`

with:

```ini
COQBIN = /absolute/path/to/coq/bin/
```

### Build Rocq Files

```bash
cd SeparationLogic/unifysl
make depend && make
cd ..
make depend && make
```

## QIDE Extension

Set:

- `qide.lspBinPath` to `linux-binary/lsp`
- `qide.lspArg` as needed for your QCP options

## QCP Command-Line Tool

Use `linux-binary/symexec` directly, or refer to:

- `run-example-linux.sh`

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

Tell `qcp-mcp` where the backend binary is. The MCP-client examples in this
guide do this by pointing `QCP_MCP_CONFIG` at a `CONFIGURE` file, so create
`mcp/qcp-mcp/CONFIGURE` (the file does not exist yet) containing:

```ini
QCP_MCP_BIN=/absolute/path/to/qcp-binary-democases/linux-binary/mcp
```

That `QCP_MCP_CONFIG` line in the VS Code and Codex examples below is what makes
this path take effect. Without `QCP_MCP_CONFIG`, `qcp-mcp` instead looks for the
file at its default location `mcp/qcp-mcp/src/qcp_mcp/CONFIGURE`. Alternatively,
skip the file entirely and set the `QCP_MCP_BIN` environment variable directly.

### Configure `rocq-mcp`

```bash
sudo apt update
sudo apt install -y opam bubblewrap
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

- `~/.config/claude/`

### Codex

```bash
codex mcp add qcp --env PYTHONPATH=/absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/src --env QCP_MCP_CONFIG=/absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/CONFIGURE -- /absolute/path/to/qcp-binary-democases/mcp/qcp-mcp/.venv/bin/python -m qcp_mcp.server
codex mcp add rocq-mcp -- rocq-mcp
```

Config file:

- `~/.codex/config.toml`
