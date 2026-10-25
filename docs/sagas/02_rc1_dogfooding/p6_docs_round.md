# P6: Docs round

## Finding

Four items whose fix is documentation:

- **Typed arrays (item 3, D3).** `var xs: Array[String] = tc.draw(Gs.lists(...))` is a script error, so it becomes a counterexample that blames the body. Statically typed projects write this first. The planning probe found two forms that work: `ys.assign(tc.draw(...))`, and `.map(func(a: Array) -> Array[String]: return Array(a, TYPE_STRING, &"", null))`.
- **Scaling test counts (item 6, D6).** A field set in code wins over `HEGEL_TEST_CASES` (the engine's precedence, as upstream). `settings.test_cases *= n` keeps the profile's or environment's value as the base. A `hegel.toml` profile selected with `HEGEL_DEFAULT_PROFILE` sets that base for a nightly run (`hegel.h`, `hegel_settings_new`).
- **gdUnit4 noise (item 8).** A failing run's one-line `push_error` makes Godot print a GDScript backtrace about 20 frames deep through gdUnit4, after the report. The `push_error` stays: P3.1 and P8.2 rely on it.
- **Upstream reference (F1).** `AGENTS.md` says to clone at tag `libhegel/0.48.0` and read `frontends/cpp/`, which that tag doesn't have.

## Change

- Guide, Writing properties or Generators: typed arrays, with an example of each working form. Add a Limitations line.
- Guide, Failures, under "Settings from the environment": scale with `*=`, and a nightly profile through `hegel.toml` + `HEGEL_DEFAULT_PROFILE`.
- Guide, Running the tests, gdUnit4: one line saying the backtrace after the report is Godot's, for the error the run pushes, and that the report above it is the part to read.
- `AGENTS.md`: the upstream reference reads "check out `5195b0b`, whose `libhegel/` matches tag `libhegel/0.48.0`".

## Steps

1. Verify the profile recipe before writing it. Write a `hegel.toml` with a `nightly` profile (`test_cases = 1000`) in a scratch project, or in this one and then remove it. Run a property with `HEGEL_DEFAULT_PROFILE=nightly` and confirm that `HegelSettings.new().test_cases` is 1000, and that `*= 2` gives 2000. Find where `hegel.toml` is looked up when Godot runs headless with `--path`: the process's working directory, per the header. Record the result in `progress.md`, and write the guide from what was observed.
2. Write the typed-array snippets as runnable guide blocks, so `tests/docs_test.gd` runs them. Add a `fails` block for the broken form only if it reads clearly; a prose sentence is enough.
3. Write the rest of the guide changes, the `AGENTS.md` line, and `CHANGELOG.md` if a user-visible line is warranted. A docs-only change usually isn't one.

## Completion

- [x] The profile recipe was run, and `progress.md` records what was seen.
- [x] Break a typed-array snippet (assign directly): `tests/docs_test.gd` goes red. Restore it.
- [x] `just check` green.

## Non-goals

- A test-case multiplier, a typed `lists` option, or dropping the failure's `push_error`.
- Documenting `tc.expect_errors` (p4 does) or `text_from` (p5 does).
