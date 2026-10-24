# First release (2026-10-24)

**Goal:** a property-based testing addon for GDScript, built on Hegel, good enough to publish as FOSS and to use in Nomu. A user writes `Hegel.run(func(tc): ...)` in a gdUnit4 test or a plain headless script. They draw values from generators (integers, floats, booleans, text, `sampled_from`, `one_of`, lists, tuples, dictionaries, `map` / `filter` / `flat_map`, `composite`) and fail a case with `tc.check`. Runtime errors in the code under test fail it too. They get a shrunk failure report with a replay blob, and can run stateful tests as rules plus invariants. The native library is built and tested for Linux, Windows and macOS.

**Must not regress:** the native layer stays thin: one method per `hegel_*` call, with no policy in it. Every test runs against the real engine. Each pass ends with the whole suite green.

**Inputs:** `PLAN.md` (2026-10-23); the Hegel monorepo at `5195b0b` (libhegel 0.48.0, read from `/tmp/hegel` during planning); two spikes run during planning (below); the owner's answers in conversation (2026-10-24).

**Baseline:** `53dfbb1` (a placeholder README only); origin `git@github.com:grammeaway/hegel-gdscript.git`.

## Spikes run during planning

- **Native:** a gdext 0.5.5 crate depending on `hegeltest-c = "=0.48.0"` (as an rlib, so it links statically) built in 55 s. It loaded in Godot 4.7.2 headless, ran `x in [0, 1e6]` with the property `x < 1000`, shrank to exactly `1000`, and gave the same case count for the same seed. A debug build of the `.so` is 150 MB, so we ship release builds. A fresh `--import` segfaults on exit with *any* gdext library, even one without hegel (F1).
- **Logger:** in Godot 4.7.2 headless, a `Logger` added with `OS.add_logger` receives script errors (type 2) and `push_error` (type 0) with a `ScriptBacktrace` giving file:line. A runtime error aborts only the innermost function, which returns `null`, and its caller carries on. `get_stack()` works headless. `Engine.print_error_messages = false` silences loggers too, so error output can't be muted while it is still being captured (F2).

## Verdicts

| # | Source item (`PLAN.md`) | Verdict | Plan |
|---|---|---|---|
| 1 | gdext crate over `hegeltest-c`, linked statically | **Confirmed** by the native spike. gdext is now 0.5.5 and `hegeltest-c` 0.48.0 is on crates.io; we compile against API 4.5 (D7) | p1 |
| 2 | Native layer exposes the handles, with no logic; GDScript owns everything user-facing | **Confirmed:** same split as `frontends/python/src/lib.rs` ("deliberately thin") | p1–p7 |
| 3 | Python frontend as the blueprint | **Partly:** Python for API and report semantics. The C++ frontend (`frontends/cpp`, in-process C ABI) is the closer blueprint for the draw path, the stateful loop and the test layout | shared rules |
| 4 | Pin a Hegel version | **Confirmed:** `hegeltest-c = "=0.48.0"` (D7) | p1 |
| 5 | Fail through `tc.check(cond, msg) -> bool` and an early return | **Confirmed**, extended: `tc.assume` returns a bool too, and the first terminal event of a case wins (D8) | p2 |
| 6 | Runtime errors count as failures, through a `Logger` | **Confirmed** by the Logger spike | p4 |
| 7 | `_log_error` is called from any thread, so it needs a Mutex. It isn't called when the debugger breaks | **Confirmed.** The debugger break matters when tests run from the editor (owner check in p8) | p4, p8 |
| 8 | On stop-test, `draw()` sets an aborted flag and returns a dummy value | **Partly:** the stand-in is the generator's *simplest* value, produced by the primitives in simplest mode (D8). Badly typed dummies would cause script errors, which can't be muted (F2) | p2 |
| 9 | Determinism: randomness comes from `tc`, not `randi()` | **Confirmed;** documented | p8 |
| 10 | MVP 1: the crate loads in Godot 4.7.2 headless | **Confirmed,** except the fresh-import crash (F1) | p1 |
| 11 | MVP 2: `Hegel.run(body, settings)`: test cases, seed, database in `user://` | **Confirmed** | p2, p3 |
| 12 | MVP 3: generators with spans | **Confirmed,** split across two plans. Adds `just`, `tuples` and `composite` (F9), plus `text` and `dictionaries` (D3) | p5, p6 |
| 13 | MVP 4: `assume`, `note`, `check`, Logger, stop-test / overrun | **Confirmed** | p2, p4 |
| 14 | MVP 5: failure report, replay blob, `Hegel.replay(blob, body)` | **Confirmed.** Replay goes through `hegel_run_start_blob`, which the header recommends over `hegel_test_case_from_blob` | p3 |
| 15 | MVP 6: single-threaded state machine helper | **Confirmed:** the engine chooses the rules (`hegel_new_state_machine` with concurrency 1, 1) | p7 |
| 16 | MVP 7: port Hegel's shrink-quality tests | **Confirmed:** from `frontends/cpp/tests/shrink_quality/` and `find_quality/`, which are themselves ports of Hypothesis's quality suite (D1) | p2, p5, p6, p7 |
| 17 | MVP 8: a gdUnit4 example and a plain headless runner | **Confirmed** | p8 |
| 18 | Not in the MVP: strings, regex, grammars, dates, IPs, printer API, concurrent machines, Antithesis | **Partly:** `text` and `dictionaries` are now in (D3). The rest stays out | p6 |
| 19 | Ship as a test-only addon, excluded from game exports | **Confirmed** | p8, p9 |
| 20 | CI builds Linux first | **Partly:** Linux, Windows and macOS arm64 all in this saga (D2) | p9 |
| 21 | Publish on the Godot Asset Library | **Dropped** for this saga. `PLAN.md` itself says to wait until the MVP is stable | none |
| 22 | First steps: the two spikes | **Confirmed:** both done during planning (above) | none |
| F1 | **Found:** a fresh `godot --headless --import` segfaults on exit (exit 134) whenever a gdext library is present, even a gdext-only crate. A second import, and every script run, work | Confirmed: reproduced 3/3 with gdext 0.5.5 on API 4.5 and 4.7 and the Arch build of 4.7.2. Cause unknown | p1 |
| F2 | **Found:** script errors raised while shrinking go to stderr, each with a backtrace. They can't be muted while a Logger still captures them | Confirmed by the Logger spike. Documented as a known limitation | p4, p8 |
| F3 | **Found:** the cross-language conformance suite was deprecated with hegel-core. Upstream frontends now validate with contract, quality and snapshot tests against the real engine | Confirmed in `hegel-core/README.md` and the frontends' tests | D1 |
| F4 | **Found:** GDScript has no coverage tool, so we can't copy upstream's 100% coverage gate | Confirmed. Instead, every behaviour plan has "break it, watch it go red" checks | shared rules |
| F5 | **Found:** a Godot `String` can't hold U+0000, and libhegel's text alphabet includes it | Confirmed from the header (`hegel_generate_string`). `text()` leaves it out | p6 |
| F6 | **Found:** `const gs = HegelGenerators` doesn't parse ("isn't a constant expression"). `const gs := preload("res://…/generators.gd")` works, even when that script has a `class_name` | Confirmed by a spike | p5 (D4) |
| F7 | **Found:** gdUnit4 6.x adds its own Logger and reports script errors and `push_error` as test failures | Confirmed in `addons/gdUnit4/src/monitor/GodotGdErrorMonitor.gd` (Nomu's copy, 6.2.2) | p2, p4, p8 |
| F8 | **Found:** this directory isn't a git repository, and `just` isn't installed | Confirmed | p1 (gate) |
| F9 | **Found:** the ported quality tests need `just`, `tuples` and `composite`, and so do users composing values | Confirmed from `shrink_quality/test_flatmap.cpp` and `test_collections.cpp` | p5, p6 |

## Decisions

| # | Decision | Taken |
|---|---|---|
| D1 | We validate the frontend the way upstream does, against the real engine with no mocks: (a) **contract tests**: `assert_all_examples` for bounds and invariants, `find_any` for reachable edge values; (b) **quality tests**: `minimal(gen, predicate)` equals a known value. These are ported from the C++ frontend's `shrink_quality/` and `find_quality/`, so Hypothesis's expected minima are the source of truth; (c) **report snapshot tests**: a subject script runs in a fresh Godot process and its scrubbed output is compared with an approved file. No live differential run against Hypothesis or another client: values differ per seed, and minima are the only thing that can be compared. | 2026-10-24, owner |
| D2 | CI is GitHub Actions. This saga builds and tests linux/amd64, windows/amd64 and macOS arm64. | 2026-10-24, owner |
| D3 | Scope adds `text()` and `dictionaries()`. Godot types (Vector2, Color, Rect2, a seeded `RandomNumberGenerator`) are documented `map()` recipes, not API. | 2026-10-24, owner |
| D4 | Public names: `Hegel` (`run`, `replay`), `HegelSettings`, `HegelResult`, `HegelTestCase`, `HegelGenerator` (base class with `map`, `filter`, `flat_map`), `HegelGenerators` (static factories), `HegelStateMachine`. The docs alias the factories as `const gs := preload("res://addons/hegel/generators.gd")`, matching upstream's `gs.` (F6). Native classes are `HegelNative<Handle>`, internal and undocumented. | 2026-10-24, planner (delegated by the owner) |
| D5 | MIT license, as Hegel. | 2026-10-24, owner |
| D6 | Passes ask the owner whenever in doubt: scope, API shape, behaviour. Answers go into `progress.md`. | 2026-10-24, owner |
| D7 | Pins: `godot = "=0.5.5"` with feature `api-4-5`, and `compatibility_minimum = "4.5"` (`Logger` arrived in 4.5); `hegeltest-c = "=0.48.0"` from crates.io, linked statically. Native builds always use cargo's release profile. Each platform gets one library, under both the debug and release keys. | 2026-10-24, planner |
| D8 | Each test case has one **terminal event**: a failed `check`, a captured runtime error, a failed `assume`, or the engine's stop-test. The first one wins and sets the status: INTERESTING, INTERESTING, INVALID or OVERRUN. From then on the test case is in **simplest mode**: every primitive returns its simplest value with no engine call. Integers give 0 clamped into range, floats 0.0 clamped, booleans `false`, a collection asks for more only until `min_size`, text gives `min_size` copies of `"0"`, a state machine's next group is done. Composite generators therefore still return well-typed values, and the body unwinds through the user's own `if not tc.check(...): return`. | 2026-10-24, planner |
| D9 | The addon's own tests use gdUnit4, vendored as a dev-only addon (Nomu runs 6.2.2; take the newest 6.x patch). Report tests run subject scripts in a fresh Godot process. | 2026-10-24, planner |
| D10 | Span labels come from `hegel_label_from_name("hegel-gdscript.<kind>")`, combined with `hegel_label_combine` for composite generators, and are computed once when a generator is built. | 2026-10-24, planner |
| D11 | A runtime error during a test case fails it if it is a script error or a `push_error`; a warning doesn't. Its origin is the error type plus the file:line of the innermost script frame, never the message, since messages carry values. | 2026-10-24, planner |
| D12 | The failure database defaults to `user://hegel/`, globalized. The database key is `<script path>::<function>` of the frame calling `Hegel.run`, from `get_stack()`. If the stack is empty, there is no key. | 2026-10-24, `PLAN.md` + planner |

## Plans

| Order | Plan | What | Gate |
|---|---|---|---|
| 1 | [`p1_scaffold.md`](p1_scaffold.md) | Godot project, addon skeleton, gdext crate with the run-lifecycle bindings, `justfile`, vendored gdUnit4, `AGENTS.md`, LICENSE, the fresh-import crash | git repo initialized; `just` installed (F8) |
| 2 | [`p2_runner_core.md`](p2_runner_core.md) | `Hegel.run`, `HegelSettings`, `HegelResult`, `HegelTestCase` with simplest mode, `HegelGenerator` and `integers`, quality helpers, integer quality ports | none |
| 3 | [`p3_report_and_replay.md`](p3_report_and_replay.md) | Per-origin capture, failure report, draw names, database key, `Hegel.replay`, snapshot tests in a fresh process | none |
| 4 | [`p4_runtime_errors.md`](p4_runtime_errors.md) | The Logger capture: script errors and `push_error` fail the case, with stable origins | none |
| 5 | [`p5_scalars_and_combinators.md`](p5_scalars_and_combinators.md) | `floats`, `booleans`, `just`, `sampled_from`, `one_of`, `map` / `filter` / `flat_map`, `composite`, argument validation | none |
| 6 | [`p6_collections_and_text.md`](p6_collections_and_text.md) | `lists`, `tuples`, `dictionaries`, `text`; collection quality ports | none |
| 7 | [`p7_state_machines.md`](p7_state_machines.md) | `HegelStateMachine`: rules, invariants, step report, shortest failing sequence | none |
| 8 | [`p8_docs_and_integration.md`](p8_docs_and_integration.md) | README and user guide, gdUnit4 example, plain headless runner, Godot-type recipes | owner check in the editor |
| 9 | [`p9_ci_and_release.md`](p9_ci_and_release.md) | GitHub Actions on three platforms, a release zip of the addon | owner creates the GitHub repo and pushes |

**Why this order:** the scaffold comes first, because everything links against it. The runner core comes next: every later test drives `Hegel.run` and uses the quality helpers. The report (p3) comes before runtime errors (p4), because an error-caused failure has to show up in a report to be testable. The generators (p5, p6) come after both, so their quality tests read failures through finished machinery. Collections come after the combinators, because their quality ports need `tuples`, `map` and `flat_map`. State machines come after collections, since their rules draw from every generator. The docs come once the API has settled. CI comes last: its gate needs the owner to push, and a pass can't see CI results without them.

## Shared rules

- Each plan is its own commit. Keep plans out of each other's diffs.
- `AGENTS.md` is the single source of truth for commands, layout and architecture. A plan that settles or changes any of these updates it in the same change.
- **The native layer is thin.** Each `#[func]` maps to one `hegel_*` call, or to a fixed sequence that frees a handle. It converts arguments and stores the result code in `last_result` and the message in `last_error` for GDScript to read. Policy, retries and formatting live in GDScript. Nothing panics across the FFI boundary: no `unwrap` on fallible paths in `rust/src/`. `cargo fmt --check` and `cargo clippy -- -D warnings` stay clean.
- **The engine is the authority.** When libhegel behaves differently from upstream's frontends or from Hypothesis, don't work around it in the addon. Record it under Found and ask the owner.
- **Upstream is the reference.** Before designing a behaviour, read how `/tmp/hegel/frontends/python/python/hegel/` and `/tmp/hegel/frontends/cpp/` do it. Clone `https://github.com/hegeldev/hegel` at tag `libhegel/0.48.0` into `/tmp/hegel` if it's missing. Copy their semantics, and write the code in GDScript idioms.
- Every `.gd` file is statically typed. `project.godot` makes untyped declarations a parse error. Naming: `snake_case` files and functions, `PascalCase` for `class_name`, `UPPER_SNAKE_CASE` for constants.
- Public API carries `##` doc comments, since Godot shows them in the editor help. Other comments are one line and explain *why*. Known shortcuts get a `shortcut: <the limit>, <when to upgrade>` comment.
- Tests live under `tests/`, mirroring `addons/hegel/`. Every public function has a test, and every test runs against the real engine. There's no coverage tool (F4), so each behaviour plan's completion includes "break X, watch the test go red, restore it" checks.
- Test runs are seeded or derandomized, with the database disabled, unless the test is about the database.
- `just check` passes at the end of every pass, and no test is switched off.
