# P8: Docs and integration

## Gate

An owner check at the end: running a failing property from gdUnit4's inspector in the editor, where the debugger is attached. A pass prepares it and asks; the plan is done only once the owner has run it.

## Finding

After p7, the API is complete, but it is documented only in `##` comments. PLAN item 8 asks for an example of use from gdUnit4, and a plain headless runner for people who don't use gdUnit4. This is a FOSS release (D5), so the README is the front door. It has to answer: what this is, how to install it, a first property, the GDScript idioms, and the limits. Several GDScript-specific behaviours need explaining, or users will trip on them: the early-return idiom, simplest mode (D8), runtime errors as failures and the stderr noise (F2), determinism and global `randi()`, gdUnit4's own Logger (F7), the debugger breaking in-editor runs, synchronous bodies only.

## Change

- **`README.md`**: what it is, with a one-paragraph Hegel credit and link; status (beta, follows Hegel's 0.x); install (the release zip from p9, or build from source with `just build`); excluding `addons/hegel/` from game exports; a first property; links to the guide.
- **`docs/guide.md`**, one page, each section with a runnable example:
  - writing properties: `Hegel.run`, `tc.draw`, the `gs` alias, `if not tc.check(...): return`, `tc.assume`, `tc.note`;
  - generators: a table of every factory and its parameters;
  - failures: reading the report, `Hegel.replay`, the database under `user://hegel/`, `HEGEL_*` environment variables, the `ci` profile;
  - runtime errors: what counts (D11), the stderr noise (F2);
  - determinism: take randomness from `tc`; pass a seeded `RandomNumberGenerator` built with `map`;
  - state machines;
  - recipes (D3): `Vector2`/`Vector2i`, `Color`, `Rect2`, `PackedInt32Array`, a seeded `RandomNumberGenerator`, a save-roundtrip property;
  - limitations: synchronous bodies, single thread, the debugger in-editor, no nested runs.
- **gdUnit4 integration**: `examples/gdunit4/` with a passing and a failing property, using whatever p3 settled for reporting. If p3 chose `push_error`, show that the failure lands in gdUnit4 with the report.
- **Plain runner**: `addons/hegel/cli/run.gd`, a `SceneTree` script. `godot --headless --path . -s res://addons/hegel/cli/run.gd -- res://tests/properties/` finds `*.gd` files under the given directories and calls each `test_*` method. It prints a summary and quits with 1 if any `Hegel.run` in them failed. Follow the `godot-gdscript-headless-testing` skill's runner pattern. `examples/plain/` uses it. Ask the owner whether it ships in the addon; the recommendation is yes, so users don't copy it.
- **`CHANGELOG.md`** with an `Unreleased` section listing the first release's features, and a short `CONTRIBUTING.md` that points to `AGENTS.md` for commands.

## Steps

1. Ask the owner the plain-runner question.
2. Build the plain runner test-first, as fresh-process subjects: an all-passing directory exits 0, one failing property exits 1 with its report, an empty directory exits 0 and says so.
3. Write the examples. Make every snippet in README and guide a test: `tests/docs/` holds each snippet as a file, the docs include them verbatim, and a test runs each one. If including verbatim is impractical, a test runs every fenced GDScript block extracted from the Markdown; pick the simpler of the two and record it.
4. Write README, guide, CHANGELOG and CONTRIBUTING (the `writing-shape` and `writing-fragments` skills help with prose).
5. Try the in-editor run, then hand the owner the check: open the project in the editor, run `examples/gdunit4/` from gdUnit4's inspector, and report what the debugger does with an error-caused failure. Document the result under limitations.

## Completion

- [ ] `just check` is green, including the docs-snippet tests.
- [ ] The plain runner exits 1 on `examples/plain/` with one failing example, and 0 once it is fixed.
- [ ] Breaking a guide snippet (renaming `gs.integers` to `gs.ints`) turns a test red. Check this, then restore it.
- [ ] Owner check passed, and its finding is in the guide.

## Non-goals

- A docs website, or generated API reference beyond Godot's built-in help.
- Asset Library submission (verdict 21).
- Migrating Nomu's tests. Nomu's own saga does that.
