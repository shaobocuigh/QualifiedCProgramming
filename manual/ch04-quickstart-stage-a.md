# Quickstart: Stage A — your first green check, no AI

This chapter gets one shipped example from C source to a green `goal_check` build using **only** the command-line tools (or QIDE). No MCP server, no LLM, no AI setup. The AI dial is **off** by design here — Stage A is the day-0 win, and we do not want an AI-onboarding cliff (Stage B, [ch 7](ch07-invariants-and-the-ai-dial.md)) standing between you and your first checkmark.

You will: install the prerequisites, run `symexec` on a shipped arithmetic example, read the four files it emits, then **compile to green** with one `make` target. The whole loop takes minutes. Every command below was run as written before it shipped — paths and flags are real.

> **What you do NOT need for Stage A:** any Rocq (formerly Coq) knowledge, any LLM, `uv`, `coq-lsp`, or an MCP client. The example we use ships with its proof artifacts already filled and a green `goal_check`, so you are reproducing a green build, not authoring proofs. Writing your own spec is [ch 5](ch05-your-first-spec.md); delegating proofs to an LLM is [ch 7](ch07-invariants-and-the-ai-dial.md).

## Step 0 — install the prerequisites

For Stage A you need two things and two things only:

- **Rocq 8.20.1** (the proof assistant; its binary and command are still named `coqc`), recommended with OCaml 4.14.1.
- **`make`**.

The shipped QCP binaries (`symexec`, `StrategyCheck`, `lsp`) are prebuilt — you do not compile them. Install Rocq via `opam`; full per-OS setup (opam blocks, the `CONFIGURE` file, the Windows caveat) is in [reference/INSTALLATION](reference/INSTALLATION.md). The Linux short form:

```bash
sudo apt install -y opam make
opam init && eval $(opam env)
opam install coq.8.20.1
```

Pick the binary directory for your platform — every command in this chapter uses `linux-binary/`; substitute yours:

| Platform | Binary directory |
|---|---|
| Linux | `linux-binary/` |
| macOS, Apple Silicon | `mac-arm64-binary/` |
| macOS, Intel | `mac-x86-64-binary/` |
| Windows | `win-binary/` — **caveated**, see [ch 13](ch13-honest-limits.md) |

### Build the proof library once

`symexec`'s output `.v` files compile against the `SeparationLogic/` library. Build it once, up front, from the repo root:

```bash
cd SeparationLogic/unifysl
make depend && make
cd ..
make depend && make
```

This is the slow step (it is the whole logic library, not your example) and it is one-time — after it, each example compiles in seconds. **Kick it off now and read Steps 1–2 while it runs**, so the wait overlaps the reading rather than gating it. Run all the remaining commands **from the repo root** unless a step says otherwise.

## Step 1 — run `symexec` on a shipped example

We use `abs` — the simplest example on the ladder ([ch 12](ch12-scope-and-scaling.md)): a one-function file that returns the absolute value of an `int`. Look at the source, `QCP_examples/QCP_demos_human/simple_arith/abs.c`:

```c
/*@ Extern Coq (Zabs: Z -> Z) */

int abs(int x)
  /*@ Require
        INT_MIN < x &&
        x <= INT_MAX && emp
      Ensure
        __return == Zabs(x) && emp
   */
{
  if (x < 0) { return -x; }
  else { return x; }
}
```

The `/*@ ... @*/` block is the **spec**: a **precondition** (`Require`) and a **postcondition** (`Ensure`). The precondition `INT_MIN < x && x <= INT_MAX` is there because Rocq integers are **unbounded mathematical integers** (`Z`), so you re-impose C's `int` range by hand — the overflow tax, which [ch 5](ch05-your-first-spec.md) covers in full.

Run the **canonical command** ([R3 — Invocation](reference/INVOCATION.md)) on it:

```bash
linux-binary/symexec \
  --input-file=QCP_examples/QCP_demos_human/simple_arith/abs.c \
  --goal-file=SeparationLogic/examples/QCP_demos_human/simple_arith/abs_goal.v \
  --proof-auto-file=SeparationLogic/examples/QCP_demos_human/simple_arith/abs_proof_auto.v \
  --proof-manual-file=SeparationLogic/examples/QCP_demos_human/simple_arith/abs_proof_manual.v \
  --coq-logic-path=SimpleC.EE.QCP_demos_human.simple_arith \
  -slp QCP_examples/QCP_demos_human/ SimpleC.EE.QCP_demos_human \
  --no-exec-info
```

Three flags carry the load. The input `.c` goes to `--input-file`; the three output `.v` files have their own flags; `--coq-logic-path` is the Rocq namespace for the generated files (derived from the directory: `SimpleC.EE.` + the path, segment by segment). `-slp <dir> <Rocq.Path>` (**s**trategy/**l**ogic **p**ath) tells `symexec` where to find `.strategies` files and Rocq dependencies — it is **not** the same as `-I<dir>`, which resolves C `#include`s. `abs` needs neither extra includes nor extra `-slp` pairs; richer cases stack several of each (the complete flag reference is [R3 — Invocation](reference/INVOCATION.md)).

A successful run prints:

```text
Start to symbolic execution on program : QCP_examples/QCP_demos_human/simple_arith/abs.c
Symbolic Execution into function abs
End of symbolic execution of function abs
Successfully finished symbolic execution
```

> **Warning: exit 0 ≠ success.** `symexec` returning `0` does **not** prove the run did what you wanted. A truncated or malformed C file can still exit `0`, and a `float` program exits `0` "Successfully finished" while emitting obligations the shipped Rocq layer cannot even compile (the float "silent half-stub" is [ch 13](ch13-honest-limits.md)). The trustworthy signal is not the exit code — it is the **green `goal_check` compile** in Step 3, plus reading the output. Scan the output; don't rely on `$?` alone.

### One regeneration gotcha

`symexec` **never overwrites an existing `*_proof_manual.v`** — that file is yours to edit, and it is protected on every regen. If a manual file is already present, you will see `manual proof file not updated`; that warning is **normal**, not an error. (To force a backup-then-overwrite, pass `--gen-and-backup`.) Because `abs` ships with its manual proof already filled, your run reuses it.

## Step 2 — read the four files

`symexec` writes four `.v` files into the parallel `SeparationLogic/examples/<sub>/` tree (a *different* directory from the `QCP_examples/` C source). Know what each one is ([ch 9](ch09-goals-symexec-and-proof.md)):

| File | What it holds | Yours to edit? |
|---|---|---|
| `abs_goal.v` | One `Definition` per **verification condition** (VC) — an entailment `P \|-- Q` | No (tool-owned) |
| `abs_proof_auto.v` | Proofs `symexec`'s solver discharged automatically — each ends in `Admitted` | No (tool-owned) |
| `abs_proof_manual.v` | Stubs for VCs needing a written Rocq proof — each should end in `Qed` | **Yes** |
| `abs_goal_check.v` | A `Module VC_Correctness : VC_Correct` that `Include`s both proof files — the **completeness** gate | No (tool-owned) |

> 🟢 **Tier 1** — The "Yours to edit?" column is where your work diverges from a 🔵 reader's: only `abs_proof_manual.v` is ever hand-edited, and a 🔵 reader opens it to read or fix a proof. At 🟢 you open none of these — you run the commands and watch the build go green ([ch 10](ch10-trust-and-soundness.md)).

Open `abs_goal.v` and you will see the VCs as plain entailments. The interesting one is the **return** VC — "the value returned equals `Zabs(x)`":

```text
Definition abs_return_wit_1_split_goal_1 :=
forall (x_pre: Z) (PreH1 : (x_pre >= 0)) (PreH2 : (INT_MIN < x_pre)) (PreH3 : (x_pre <= INT_MAX)) ,
  TT && emp
|--
  “ (x_pre = (Zabs (x_pre))) ”.
```

The `|--` is the entailment ("the left side proves the right side"); the smart-quoted `“ P ”` is a **pure proposition** (Rocq's `[| P |]`, in the spelling the generated files use — the quotes above are the curly glyphs `symexec` actually emits, not ASCII). You do not have to *read* Rocq to finish Stage A — `abs` ships with its proofs already filled — but this is the shape of what gets checked. The VCs split across two pools: for `abs`, **2 auto `Admitted` in `abs_proof_auto.v` / 2 manual `Qed` in `abs_proof_manual.v`** in this checkout (re-measure: `grep -c Admitted abs_proof_auto.v` vs `grep -c Qed abs_proof_manual.v`). Those two pools earn their checkmarks differently — see the closing section below.

## Step 3 — compile to green

Here is the step the batch script does **not** do for you. `run-example-linux.sh` runs only `symexec` and `StrategyCheck` over the corpus — it **never invokes `coqc` on a `goal_check` file**. So running that script (or the `symexec` command above) is *not* the green check. You must compile the `goal_check` yourself. The build root is `SeparationLogic/`, where the Makefile maps `examples/` to the `SimpleC.EE` namespace. From `SeparationLogic/`:

```bash
make examples/QCP_demos_human/simple_arith/abs_goal_check.vo
```

The path is the generated file's path **relative to `SeparationLogic/`**, with `.v` swapped for `.vo`. `make` resolves the dependency chain and runs `coqc` on `abs_goal.v`, `abs_proof_auto.v`, `abs_proof_manual.v`, then `abs_goal_check.v`:

```text
COQC examples/QCP_demos_human/simple_arith/abs_goal.v
COQC examples/QCP_demos_human/simple_arith/abs_proof_auto.v
COQC examples/QCP_demos_human/simple_arith/abs_proof_manual.v
COQC examples/QCP_demos_human/simple_arith/abs_goal_check.v
```

No error, and an `abs_goal_check.vo` on disk, is your **green check**. (Equivalent without `make`: invoke `coqc` on the four files in that order with the library `-R` flags — but let `make` handle the flags and ordering.) If you want to build a whole subtree instead of one case, the corpus is split into `make` groups — `make examples-qcp-democases` builds the `QCP_demos_human/` goal-checks (and their strategy proofs), `make examples-llm-friendly-cases` builds the `QCP_demos_LLM/` goal-checks, and `make examples` builds all groups; `make core` (re)builds only the library. (The full target list is in [R3 — Invocation](reference/INVOCATION.md).)

## What "green" actually means here

This is the honest part, and it matters before you lean on the result. A green `abs_goal_check.vo` proves **completeness**: every VC `symexec` emitted has a proof member, exactly once — none silently dropped, none proved twice. That is genuinely useful. It is **not** the same as "every VC was re-checked by the Rocq kernel." The gate that earns the green is `abs_goal_check.v`:

```coq
From SimpleC.EE.QCP_demos_human.simple_arith Require Import abs_goal abs_proof_auto abs_proof_manual.

Module VC_Correctness : VC_Correct.
  Include abs_proof_auto.
  Include abs_proof_manual.
End VC_Correctness.
```

It accepts an `Admitted` (auto) member as readily as a `Qed` (manual) one, so green means the obligation set is *complete*, with the manual fraction kernel-checked and the auto fraction trusted to `symexec`'s solver. That two-tier split — why each pool earns its checkmark differently, and how to audit any single result in two minutes — is the whole subject of [ch 10](ch10-trust-and-soundness.md).

## Where to go next

You now have the core loop you ran: **`symexec` → read the four files → `make ..._goal_check.vo` → green.** Authoring the annotation that feeds it is ch 5's step. From here:

- **Write your own spec** — `With` / `Require` / `Ensure`, `__return`, the `Z`/overflow bound, and a first loop `Inv` — in [ch 5](ch05-your-first-spec.md). (In the same `simple_arith/` directory: `slow_add` in `add.c` is the natural loop-plus-`Inv` next example, with an `Inv` over a `while (x > 0)` loop; `gcd.c` is the recursion-by-contract step — a self-call discharged through the function's own contract, no loop or `Inv`.)
- **Turn the AI dial up (Stage B)** — onboarding the `qcp-mcp` / `rocq-mcp` servers so an LLM drafts your invariants and manual proofs — in [ch 7](ch07-invariants-and-the-ai-dial.md).
- **Go deeper on annotation syntax** — the full spec surface (`Assert`, `Inv Assert`, `which implies`, the storage predicates) — in [ch 6](ch06-annotations-as-specs.md).
- **Understand the green check** — the two-tier trust model and the self-serve audit — in [ch 10](ch10-trust-and-soundness.md).
