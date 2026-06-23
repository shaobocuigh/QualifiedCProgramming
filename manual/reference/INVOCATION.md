# Reference — Invocation, flags & configuration

> The complete reference for **driving** QCP: every `symexec` / `StrategyCheck` flag that affects how you use it, the
> environment and build knobs, and the MCP configuration. For *what the pipeline does* see
> [ch 9](../ch09-goals-symexec-and-proof.md); for a first run see [ch 4](../ch04-quickstart-stage-a.md).
> Flag descriptions are the tool's own (`symexec --help`); behaviours marked **advanced** are
> exposed but not needed for ordinary use. Verify against `--help` on your build — flags can change
> between releases.

## The canonical command

The minimal "run QCP on one C file" (Linux; Windows uses `win-binary\symexec.exe`):

```bash
linux-binary/symexec \
  --input-file=QCP_examples/QCP_demos_human/simple_arith/gcd.c \
  --goal-file=SeparationLogic/examples/QCP_demos_human/simple_arith/gcd_goal.v \
  --proof-auto-file=SeparationLogic/examples/QCP_demos_human/simple_arith/gcd_proof_auto.v \
  --proof-manual-file=SeparationLogic/examples/QCP_demos_human/simple_arith/gcd_proof_manual.v \
  --coq-logic-path=SimpleC.EE.QCP_demos_human.simple_arith \
  -slp QCP_examples/QCP_demos_human/ SimpleC.EE.QCP_demos_human \
  --no-exec-info
```

Then compile to a green `goal_check` with `make <name>_goal_check.vo` (or `coqc`) — `symexec`
itself never runs `coqc` (see [ch 4](../ch04-quickstart-stage-a.md)).

## `symexec` flags

### Inputs & generated files
| Flag | Meaning |
|---|---|
| `--input-file <file>` | the annotated C source (required) |
| `--input-file-name <name>` | override the displayed input file name (cosmetic) |
| `-I<path>` | add a **C header** search path (resolves `#include`); repeatable |
| `--goal-file <file>` | write the generated VC goals (`<name>_goal.v`) |
| `--proof-auto-file <file>` | write the auto-solved proofs (`<name>_proof_auto.v`) |
| `--proof-manual-file <file>` | write the manual-proof stubs (`<name>_proof_manual.v`; not overwritten if present) |
| `--coq-output-dir <dir>` | derive all generated Rocq (formerly Coq) file paths from one output folder (instead of naming each) |
| `--gen-and-backup` | back up existing generated files before overwriting (otherwise only the manual file is preserved) |
| `--no-coq-gen` | disable all Rocq file generation (parse/check only) |

### Logic & strategy paths
| Flag | Meaning |
|---|---|
| `-slp <folder> <logic-path>` | **s**trategy/**l**ogic **p**ath: map an example folder to its Rocq logical path; repeatable and **nests** (one per dependency dir) |
| `--coq-logic-path <path>` | the Rocq logical path for the generated files (e.g. `SimpleC.EE.QCP_demos_human.simple_arith`) |
| `--no-logic-path` | don't assign a logical path |
| `--strategy-folder-path <path>` | base folder used to resolve `.strategies` files |
| `--strategy-file <file>` | load strategy configuration from a specific file |
| `--no-strategy-gen` | skip strategy-soundness goal generation |
| `--CRules <module>` / `--no-CRules` | import (or don't) the given/default CRules module |

> **`-I` ≠ `-slp`.** `-I<dir>` resolves C `#include`s; `-slp <dir> <Rocq.Path>` resolves
> `.strategies` files and Rocq logical paths. Richer cases stack several of each (count the `-slp`
> pairs in a given command with `rg -n -- "-slp" run-example-linux.sh`). **Logic-path derivation:** `SimpleC.EE.` + the
> example directory path, segment by segment (`QCP_examples/QCP_demos_human/simple_arith/` →
> `SimpleC.EE.QCP_demos_human.simple_arith`).

### Execution & proof mode
| Flag | Meaning |
|---|---|
| `--full-auto` | **fully automatic proof mode** — push automation as far as it goes before falling back to manual VCs. The flag behind the "dial it up" autopilot story ([ch 7](../ch07-invariants-and-the-ai-dial.md)). Trust split: VCs it closes automatically land in `*_proof_auto.v` as trusted (`Admitted`) results, *not* kernel-re-checked ([ch 10](../ch10-trust-and-soundness.md)). |
| `-s <0..5>` | **debug-output verbosity — almost always leave unset.** It changes only what `symexec` prints to stdout; the generated `.v` files are byte-identical at every setting (verified by `diff`), so it never affects verification. `0` (the default, used by every shipped command) runs quietly; `1` dumps the parsed program, `2` the parsed statement list, `3` a GraphViz tree of the parse — all useful only for inspecting how `symexec` read your code. `4` / `5` behave like `0`. |

### Assertion format
`symexec` can render assertions in several surface forms (relevant to the basic-vs-concise
distinction in [ch 6](../ch06-annotations-as-specs.md)):
| Flag | Format |
|---|---|
| `--user-assertion` | the user-facing form |
| `--basic-assertion` | the basic separation-logic form (every cell spelled out) |
| `--primary-assertion` | the primary form |
| `--inner-assertion` | the internal `PROP / LOCAL / SEP` form |

In QIDE, the same choice is the `qide.assertionType` setting (`user` / `inner` / `basic assertion`) — see [R6 — Installation](INSTALLATION.md).

### Output & diagnostics
| Flag | Meaning |
|---|---|
| `--no-exec-info` | suppress intermediate symbolic-execution output (use in scripts/CI) |
| `--disable-solver-info` | suppress solver-related output |
| `--dump-smt-vc-file <file>` | dump the generated low-level verification conditions to a file (advanced/diagnostic) |
| `--program-path <file>` | write the generated Rocq *program* to a file |

## `StrategyCheck` flags

`StrategyCheck` turns `.strategies` files into Rocq strategy-soundness artifacts. It accepts the
same input/path/generation/mode/assertion-format/output flags as `symexec` above —
`--input-file`, `-I`, `--goal-file`, `--proof-auto-file`, `--proof-manual-file`,
`--coq-output-dir`, `--no-coq-gen`, `-slp`, `--coq-logic-path`, `--no-logic-path`,
`--CRules`/`--no-CRules`, `--strategy-file`, `--no-strategy-gen`, `--strategy-folder-path`,
`-s`, `--full-auto`, the four `--*-assertion` formats, and `--no-exec-info` —
plus one of its own:
| Flag | Meaning |
|---|---|
| `--strategy-proof-logic-path <path>` | the Rocq logical path for the generated strategy proofs |

It does **not** have the symexec-only `--program-path` or `--dump-smt-vc-file`.

Typical use (validates a `.strategies` file):

```bash
linux-binary/StrategyCheck \
  --strategy-folder-path=SeparationLogic/examples/QCP_demos_human/ \
  --coq-logic-path=SimpleC.EE.QCP_demos_human \
  --input-file=QCP_examples/QCP_demos_human/common.strategies \
  --no-exec-info
```

## Environment & build knobs

| Knob | Where | Effect |
|---|---|---|
| `ROCQ_MEMORY_LIMIT_BYTES` (= 4 GiB) | a **hard-coded constant** in the proving scripts | caps `coqc` memory per worker; a memory-heavy proof can be killed at this limit. It is **not a shipped environment knob** — raising it means editing the script. |

There is no shipped CLI or environment knob for loop-unrolling or `coqc`-retry behaviour. (The
`vc-proving` skill *intends* a `coqc`-retry knob but it is currently broken — see
[R5 Troubleshooting](TROUBLESHOOTING.md).)

> **Exit codes are not a reliable success signal.** A malformed parse and a float program both
> return `0`; most other fatal errors return `1`. Scan the *output* (and compile `goal_check`),
> not just `$?`. There is no `--version` flag on any binary.

## MCP configuration (Stage B)

The two MCP servers (`qcp`, `rocq-mcp`) are declared in an `.mcp.json` entry — the repo ships
`mcp/qcp-mcp/.mcp.json`:

```json
{
  "mcpServers": {
    "qcp": {
      "type": "stdio",
      "command": "<repo>/mcp/qcp-mcp/.venv/bin/python",
      "args": ["-m", "qcp_mcp.server"],
      "env": { "QCP_MCP_BIN": "<repo>/linux-binary/mcp" }
    },
    "rocq-mcp": { "type": "stdio", "command": "rocq-mcp", "args": [], "env": {} }
  }
}
```

`QCP_MCP_BIN` points the server at the platform `mcp` binary it drives. The server resolves that
binary in precedence order: the `QCP_MCP_BIN` env var, then a `CONFIGURE` file named by
`QCP_MCP_CONFIG`, then the `CONFIGURE` packaged beside the server. The remaining `qcp-mcp` env vars
are diagnostics knobs, all optional:

| Env var | Default | Effect |
|---|---|---|
| `QCP_MCP_BIN` | — | absolute path to the platform `mcp` binary (highest precedence) |
| `QCP_MCP_CONFIG` | packaged `CONFIGURE` | path to a `CONFIGURE` file giving `QCP_MCP_BIN` |
| `QCP_MCP_LOG_LEVEL` | `INFO` | server log level |
| `QCP_MCP_LOG_FILE` | _(unset)_ | write the server log to this file |
| `QCP_MCP_USE_STDBUF` | `0` | wrap the engine in `stdbuf` for line-buffered output (set `1` to debug streaming) |

The companion **`rocq-mcp`** server (interactive Rocq proof, Stage B) reads its own knobs —
`ROCQ_WORKSPACE` (the proof working dir, usually your editor's `${workspaceFolder}`),
`ROCQ_COQC_BINARY` (default `coqc`; point it at a non-`PATH` `coqc`), and timeout/memory caps
(`ROCQ_COQC_TIMEOUT`, `ROCQ_VERIFY_TIMEOUT`, `ROCQ_PET_TIMEOUT`, `ROCQ_MAX_PET_RSS_MB`, `ROCQ_MAX_STATES`).
The full list with defaults is in `mcp/rocq-mcp/README.md`.

If your MCP client uses a different config format (VS Code JSON, a CLI's own config), translate the
same `command` / `args` / `env` contract into it — the ready-to-paste per-client blocks (VS Code
Copilot, Claude Code, Codex) are in `README_LINUX.md`'s *MCP Setup* section. See
[ch 7](../ch07-invariants-and-the-ai-dial.md) for the Stage-B workflow and its maturity caveats.

## Build targets (`SeparationLogic/`)

Build the `core` library once, then only the example group you touched:
| `make` target | Builds |
|---|---|
| `core` | the proof library (build first) |
| `examples-qcp-democases` | `QCP_demos_human/` goal-checks + strategy proofs |
| `examples-llm-friendly-cases` | `QCP_demos_LLM/` |
| `examples-applications` | `Applications_human/` (production-scale cases) |
| `examples-llm-bench` | `LLM_bench/` |
| `examples` | all example groups |

(Each group has matching `depend-examples-*` and `clean-*` targets.)
