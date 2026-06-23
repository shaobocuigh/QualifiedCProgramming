# Installation & prerequisites

This page gets QCP working on your machine. Follow it once, end to end, and you will have a verifier that can take an annotated C file to a green build. The setup splits into two stages, and you only need the first to get your day-0 win:

- **Stage A (required) — the core verifier.** A prebuilt engine binary plus **Rocq (formerly Coq)**, so you can run `symexec` and compile the generated proofs. This is all [ch 4](../ch04-quickstart-stage-a.md) needs.
- **Stage B (optional) — the AI workflow.** `uv` plus a Python environment for the MCP servers, so an LLM agent can drive QCP. Skip it until you want the AI dial ([ch 7](../ch07-invariants-and-the-ai-dial.md)).

Pick your platform and read only its column. **Linux (including WSL) is the primary, best-tested track**; macOS has shipped binaries and follows the same core flow (Stage B is still intended-workflow); Windows works but has a known packaging gap, called out below.

> **Note:** The engine binaries are **closed, prebuilt** per platform. There is no source build of `symexec`/`StrategyCheck`/`lsp`/`mcp` — you use the one for your OS. What you *do* build from source is the Rocq proof library, and that is the same on every platform.

## What you need, at a glance

| Component | Stage | Linux / WSL | macOS | Windows |
|---|---|---|---|---|
| Engine binaries | A | `linux-binary/` | `mac-arm64-binary/` or `mac-x86-64-binary/` | `win-binary/` (`.exe`) |
| Rocq (Coq) 8.20.1 | A | via `opam` | via `opam` (Homebrew) | Coq Platform install |
| `make` | A | yes | yes | MSYS2 provides it |
| QIDE — `qide.vsix` | A (optional, recommended) | yes | yes | yes |
| Live-proof VS Code ext | A (optional) | `vsrocq` / `coq-lsp` | `vsrocq` / `coq-lsp` | `vscoq-2.2.3.vsix` |
| `uv` + `qcp-mcp` env | B (optional) | yes | yes | yes (with caveat) |
| `rocq-mcp` (`coq-lsp`) | B (optional) | yes | yes | not set up |

## Stage A: the core verifier

### 1. Pick your platform's engine binary

The repository ships four prebuilt binary directories, one per platform. Each contains the same four executables: `symexec` (runs the verification), `StrategyCheck` (emits the strategy-rule proof goals for `.strategies` rules — most close with `Qed` and are kernel-checked, with a small named `Admitted` residue that is trusted; see [ch 10](../ch10-trust-and-soundness.md)), `lsp` (powers QIDE), and `mcp` (the Stage-B backend).

| Platform | Directory | How to tell |
|---|---|---|
| Linux, or Windows under WSL | `linux-binary/` | the default track |
| Apple Silicon Mac | `mac-arm64-binary/` | `uname -m` → `arm64` |
| Intel Mac | `mac-x86-64-binary/` | `uname -m` → `x86_64` |
| Native Windows | `win-binary/` | files end in `.exe` |

Throughout the manual, command examples use `linux-binary/symexec`. On macOS substitute your `mac-*-binary/` directory; on native Windows substitute `win-binary/symexec.exe`. Nothing else in the invocation changes ([R3](INVOCATION.md) is the full flag reference).

The binaries are not on your `PATH` — they run from the repository root by relative path, which is exactly how [`run-example-linux.sh`](../../run-example-linux.sh) calls them.

### 2. Install Rocq 8.20.1

The version is **exact**: QCP's proof library is built against **Rocq 8.20.1**. A different Coq version will fail to compile the generated `.v` files. OCaml 4.14.1 is the recommended toolchain (4.14.2 also works).

**Linux / WSL** — install via `opam`:

```bash
sudo apt update
sudo apt install -y opam make
opam init
eval $(opam env)
opam install coq.8.20.1
```

**macOS** — install via `opam`, typically from Homebrew:

```bash
brew install opam
opam init -y
eval $(opam env)
opam install coq.8.20.1
```

**Windows** — use a Coq Platform style install that provides Rocq/Coq 8.20.1 (`coqc.exe`, `coqtop.exe`), then point QCP at it with a `CONFIGURE` file (next step).

After `opam install`, confirm the version is what you expect:

```bash
coqc --version    # must report 8.20.1
```

> **Note:** With an `opam`-managed Rocq on Linux/macOS you usually do **not** need a `SeparationLogic/CONFIGURE` file — the build picks up `coqc` from your environment. Create one only if `coqc` is not on your `PATH`, or on Windows where it is required.

If you do need an explicit configuration, create **both** `SeparationLogic/CONFIGURE` and `SeparationLogic/unifysl/CONFIGURE`. On Linux/macOS:

```ini
COQBIN = /absolute/path/to/coq/bin/
```

On Windows, add the executable suffix:

```ini
COQBIN = D:/path/to/Coq/bin/
SUF = .exe
```

### 3. Build the proof library

The Rocq library under `SeparationLogic/` is what re-checks your manual proofs — without it, `symexec` can emit `.v` files but nothing compiles them to a green check. Build it once. Build its dependency `unifysl` first:

```bash
cd SeparationLogic/unifysl
make depend && make
cd ..
make depend && make
```

That second `make` compiles the **core** library plus all the generated example proofs, which is a lot. To get working faster, build only the core library — enough to verify your own code and follow [ch 4](../ch04-quickstart-stage-a.md):

```bash
cd SeparationLogic
make depend-core && make core
```

The example proofs are split into their own targets (`make depend-examples && make examples`, or per-subtree targets like `make examples-qcp-democases`) so you can compile just the slice you care about. You do not need them to verify your own files.

> **Note:** On Windows, run the same targets from PowerShell with `Set-Location` in place of `cd`. The `make` must be the one MSYS2 supplies — see the Windows notes below.

### 4. Take an example to green (the compile step)

Stage A is complete when you can turn an annotated `.c` file into a compiled, green proof. There are two steps; running only the first leaves nothing compiled:

1. **`symexec`** reads your annotated C and writes the generated `.v` files.
2. **`coqc`** (via `make`) compiles those `.v` files. The green `*_goal_check.vo` is your verified result. (What each file is → [ch 9](../ch09-goals-symexec-and-proof.md).)

> **Warning:** [`run-example-linux.sh`](../../run-example-linux.sh) runs only `symexec` and `StrategyCheck` — it **never runs `coqc` on `goal_check`**. Running the script regenerates the `.v` files but does **not** compile them, so it alone does not produce a green check. To verify a case you must compile **its** completeness target — `make <name>_goal_check.vo` (not the library-wide `make core` of step 3, which only builds the proof library). [Ch 4](../ch04-quickstart-stage-a.md) walks the full command line; [R3](INVOCATION.md) documents every flag.

"Green" is the *completeness* gate, not an end-to-end re-check of every obligation — read [ch 10](../ch10-trust-and-soundness.md) before you treat a green build as fully proven.

### 5. QIDE: the live symbolic-state view (recommended)

QIDE is QCP's VS Code extension. It is optional but worth installing early: with the cursor anywhere in an annotated C file, press **`Alt+→`** (`Alt+Rightarrow` in the README; the `qide.interpretToPoint` command) and QCP shows the **live symbolic state** at that point — what it knows about the heap and your variables. That feedback is how you write annotations without guessing.

To install:

1. In VS Code, open the command palette and run **Extensions: Install from VSIX…**, then choose `qide.vsix` from the repository root. (The extension is not in the marketplace — do not search for it.)
2. Open settings, search for `qide`, and set `qide.lspBinPath` to your platform's `lsp` binary:
   - Linux/WSL: `linux-binary/lsp`
   - macOS: `mac-arm64-binary/lsp` or `mac-x86-64-binary/lsp`
   - Windows: `win-binary/lsp.exe`
3. Leave `qide.lspArg` empty unless you need specific QCP options (it passes through to the `lsp` binary; the flags are in [R3](INVOCATION.md)).
4. `qide.assertionType` chooses which **surface form** QIDE shows for the symbolic state: `user assertion` (the default, most readable), `inner assertion` (the raw `PROP / LOCAL / SEP` form), or `basic assertion` (every memory cell spelled out). These mirror the `--user-assertion` / `--inner-assertion` / `--basic-assertion` flags ([R3](INVOCATION.md)); the basic-vs-concise trade-off is covered in [ch 6](../ch06-annotations-as-specs.md). Leave it at `user assertion` unless you want a more explicit view.

> The stepping key `Alt+→` (`qide.interpretToPoint`) is rebindable in VS Code's *Keyboard Shortcuts* if it clashes with another binding.

### 6. Reading the proofs in VS Code (optional, tier 2+)

This is a separate extension from QIDE, and you only need it when you open the generated `.v` files to read or step through a proof — never required to *annotate* C or to take an example to green.

> 🔵 **Tier 2** — When you read or fix the manual `Qed` proofs, install a Coq 8.20 proof extension: `vsrocq` (or `coq-lsp`) on Linux/macOS. On Windows the verified working setup is the repository-local `vscoq-2.2.3.vsix` with the Coq Platform's `vscoqtop.exe` — install it the same way (Install from VSIX), and disable any other Coq extensions in the workspace first.

Two `vscoq` settings matter for QCP: **`vscoq.path`** — the path to `vscoqtop` (`vscoqtop.exe` on Windows) if it is not on your `PATH` — and **`vscoq.memory.limit`** (default `4`, in GB) — raise it if large proofs get their state discarded mid-step. The rest are upstream VsCoq defaults (see the VsCoq docs). Its stepping keys are the tier-2 analogue of QIDE's: `Alt+↓` / `Alt+↑` step forward / back, `Alt+→` interprets to the cursor, `Alt+End` to the end of the file.

## Stage B: the MCP servers (optional, for the AI workflow)

Stage B lets an LLM agent drive QCP. You do not need it for Stage A, and it is partly **intended-workflow** rather than a turnkey path — expect setup friction, and note that effective use needs a frontier model today ([ch 7](../ch07-invariants-and-the-ai-dial.md), [ch 13](../ch13-honest-limits.md)).

There are two servers: **`qcp-mcp`** (interactive symbolic execution and annotation checking, wrapping the `mcp` engine binary) and **`rocq-mcp`** (interactive Rocq proof development, needing `coq-lsp`).

Install `uv`, then create the `qcp-mcp` Python environment. It needs **Python ≥ 3.12** (declared in `mcp/qcp-mcp/pyproject.toml`); `uv` fetches a matching interpreter for you, so you do not have to install Python by hand. The commands below are for **Linux / macOS / WSL**:

```bash
# install uv (Linux / macOS / WSL)
curl -LsSf https://astral.sh/uv/install.sh | sh

# build the qcp-mcp environment
cd mcp/qcp-mcp
uv venv .venv
uv sync
```

> On **Windows** the shipped flow is different: from `mcp/qcp-mcp`, create a `.venv-win` with the system Python and install in place — `py -3 -m venv .venv-win` then `.\.venv-win\Scripts\python.exe -m pip install -e .` (per `README_WINDOWS.md`). The Windows MCP client entries then point at `.venv-win\Scripts\python.exe`. Note the referenced helper `scripts/setup-windows-mcp-env.ps1` is **not shipped** (see the Windows notes); set `QCP_MCP_BIN` by hand, or use WSL and follow the Linux flow above.

`qcp-mcp` then needs to know where the engine `mcp` binary is, and your MCP client (VS Code, Claude Code, Codex) needs its own server entry. The `QCP_MCP_BIN`/`CONFIGURE` wiring and the full env-var contract are documented in [R3](INVOCATION.md); the ready-to-paste per-client server blocks (VS Code Copilot, Claude Code, Codex) live in `README_LINUX.md`'s *MCP Setup* section. `rocq-mcp` additionally requires `opam` + `coq-lsp`; see [ch 7](../ch07-invariants-and-the-ai-dial.md) for when it is worth setting up.

## Per-OS notes

### Linux / WSL (primary track)

The default, best-tested path. Use `linux-binary/` and [`run-example-linux.sh`](../../run-example-linux.sh). Under WSL, work inside the Linux filesystem and treat it exactly as native Linux.

### macOS

Identical to Linux except for the binary directory. Run `uname -m` and pick `mac-arm64-binary/` (Apple Silicon) or `mac-x86-64-binary/` (Intel). Install Rocq via Homebrew's `opam`. Everything else — the `make core` build, QIDE, MCP — is the same.

### Windows

Windows works, with two things to get right.

- **You need a shell with `make`; MSYS2 is the best choice** (it provides `bash` *and* `make` in one place). The batch driver [`run-example-windows.sh`](../../run-example-windows.sh) is a bash script, so it strictly needs a Unix-style shell. The proof build itself, though, is just `make` + `coqc` — you can drive it from any environment that has `make` and Rocq on `PATH` (PowerShell works once those are installed), so the PowerShell-incompatible part is only the convenience `.sh` driver, not the build. Use `win-binary/*.exe` for the engine, and `vscoq-2.2.3.vsix` for proof interaction (above).

- **Honest limit — the Windows setup scripts are not shipped.** `README_WINDOWS.md` tells you to run `scripts/setup-windows-env.ps1` (to export `QCP_SYMEXEC_EXE` and friends) and `scripts/setup-windows-mcp-env.ps1` (for the MCP variables). **Neither file is present in this redistributable** — `scripts/` contains only `collect_and_analyze.py`. This is a packaging gap, not a step you can fix by reinstalling. Until the scripts are restored, you can still drive the binaries and `make` directly with explicit paths: point your tooling at `win-binary/symexec.exe`, `win-binary/StrategyCheck.exe`, `win-binary/lsp.exe`, and `win-binary/mcp.exe`, and set `coqc`/`coqtop` from your `SeparationLogic/CONFIGURE` `COQBIN`. The core CLI and the Rocq build work fine without the scripts; only the convenience environment-variable export is missing. Windows remains the most caveated platform overall ([ch 13](../ch13-honest-limits.md)) — if you have the choice, Linux or WSL is the smoother path.

## Verify your install

A quick post-install smoke test that Stage A is wired up correctly:

```bash
# the engine binary runs (from the repository root)
linux-binary/symexec --help

# and re-confirm coqc --version is 8.20.1
coqc --version
```

> **Warning:** Do not trust the exit code alone as proof a `symexec` run succeeded. A `0` exit does **not** guarantee a clean verification — a malformed or truncated C file, and a `float` program, both exit `0` while the run did not do what you wanted. Scan the output, not just `$?`. The trust model and these failure modes are covered in [ch 10](../ch10-trust-and-soundness.md) and [ch 13](../ch13-honest-limits.md).

From here, [ch 4](../ch04-quickstart-stage-a.md) takes a shipped example to its first green check.
