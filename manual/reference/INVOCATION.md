# Reference — Invocation, flags & configuration

> The complete reference for **driving** QCP: every `symexec` / `StrategyCheck` flag, the
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
| `--coq-output-dir <dir>` | derive all generated Rocq file paths from one output folder (instead of naming each) |
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
> `.strategies` files and Rocq logical paths. Many cases need several of each, and `-slp` pairs
> nest (up to three in the deepest corpus case). **Logic-path derivation:** `SimpleC.EE.` + the
> example directory path, segment by segment (`QCP_examples/QCP_demos_human/simple_arith/` →
> `SimpleC.EE.QCP_demos_human.simple_arith`).

### Execution & proof mode
| Flag | Meaning |
|---|---|
| `--full-auto` | **fully automatic proof mode** — push automation as far as it goes before falling back to manual VCs. The flag behind the "dial it up" autopilot story ([ch 7](../ch07-invariants-and-the-ai-dial.md)). |
| `-s <0..5>` | select execution mode (advanced — controls how aggressively `symexec` runs; see `--help`) |
| `--conassertion` | use *conassertion* mode (advanced) |

### Assertion format
`symexec` can render assertions in several surface forms (relevant to the basic-vs-concise
distinction in [ch 6](../ch06-annotations-as-specs.md)):
| Flag | Format |
|---|---|
| `--user-assertion` | the user-facing form |
| `--basic-assertion` | the basic separation-logic form (every cell spelled out) |
| `--primary-assertion` | the primary form |
| `--inner-assertion` | the internal `PROP / LOCAL / SEP` form |

### Output & diagnostics
| Flag | Meaning |
|---|---|
| `--no-exec-info` | suppress intermediate symbolic-execution output (use in scripts/CI) |
| `--disable-solver-info` | suppress solver-related output |
| `--dump-smt-vc-file <file>` | dump the generated SMT verification conditions (advanced/diagnostic) |
| `--program-path <file>` | write the generated Rocq *program* to a file |
| `--soundness-proof` | generate soundness-proof artifacts — **currently dormant** (emits empty output in the shipped build); not usable today |

## `StrategyCheck` flags

`StrategyCheck` turns `.strategies` files into Rocq strategy-soundness artifacts. It shares most
`symexec` flags (inputs, `-I`, `-slp`, `--coq-logic-path`, `--gen-and-backup`, `--no-coq-gen`,
`-s`, `--conassertion`, `--strategy-file/-folder-path`, `--no-strategy-gen`, `--CRules`) and adds:
| Flag | Meaning |
|---|---|
| `--strategy-proof-logic-path <path>` | the Rocq logical path for the generated strategy proofs |

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
| `ROCQ_MEMORY_LIMIT` (≈ 4 GiB cap) | the proving scripts' `coqc` invocations | caps `coqc` memory per file; a memory-heavy proof can be killed at this limit (raise it if large proofs OOM) |
| `COQC_TRANSIENT_RETRIES` | intended `vc-proving` retry knob | *intended* to retry `coqc` after a transient (OOM) kill — **currently inert in the shipped build** (an undefined-globals bug; see [R5 Troubleshooting](TROUBLESHOOTING.md)) |
| `loop_inv_iter_times`, `unroll_flag` | engine-internal | limited loop unrolling during invariant checking (advanced; not a user-facing CLI flag) |

> **Exit codes are not a reliable success signal.** A malformed parse and a float program both
> return `0`; most other fatal errors return `1`. Scan the *output* (and compile `goal_check`),
> not just `$?`. There is no `--version` flag on any binary.

## MCP configuration (Stage B)

The MCP servers (`qcp-mcp`, `rocq-mcp`) are configured in your MCP client's `config.toml`. The
QCP server entry sets the binary and Python path:

```toml
[mcp_servers.qcp]
command = "<repo>/mcp/qcp-mcp/.venv/bin/python"
args = ["-m", "qcp_mcp.server"]
[mcp_servers.qcp.env]
PYTHONPATH = "<repo>/mcp/qcp-mcp/src"
QCP_MCP_BIN = "<repo>/linux-binary/mcp"          # which symexec/mcp binary the server drives
[mcp_servers.qcp.tools.symbolic]
approval_mode = "approve"                          # gate the symbolic-execution tool behind approval
```

`QCP_MCP_BIN` selects the platform binary; `approval_mode` controls whether a tool call needs
confirmation. See [ch 7](../ch07-invariants-and-the-ai-dial.md) for the Stage-B workflow and its
maturity caveats.

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
