# P9: CI and release

## Gate

The owner has created the GitHub repository and pushed. Workflow results are visible only after a push, which the owner does. Ask the owner to push and to share each run's result or log, and iterate until green. Don't create anything on GitHub or in any cloud yourself.

## Finding

Nothing checks the build outside this Linux machine, and there's no artifact a user can download. The owner wants linux/amd64, windows/amd64 and macOS arm64 built and tested in this saga (D2). Nomu adds a native addon only once it has builds for all three. libhegel supports all three, and upstream publishes binaries for them. The fresh-import crash (F1) hits every CI run, since CI always imports fresh.

## Change

- **`.github/workflows/ci.yml`**, on pushes and pull requests:
  - `lint` (ubuntu): `cargo fmt --check`, `cargo clippy -- -D warnings`, `gdlint` if p1 adopted it;
  - `test`, a matrix of `ubuntu-latest`, `windows-latest` and `macos-14`: set up the Rust toolchain from `rust-toolchain.toml`, cache cargo, run `just build`, download Godot 4.7.2 for the runner from the official GitHub release (cached), run `just import` and `just test`;
  - `floor` (ubuntu): the suite on Godot 4.5.x, the declared `compatibility_minimum` (D7). It is one job, since API floor problems aren't platform-specific.
  - Every job has `timeout-minutes`. Install tools with pinned versions. Pin actions to major versions, or to SHAs if the owner prefers.
- **`.github/workflows/release.yml`**, on tags `v*`: build the three libraries in release mode and ad-hoc sign the macOS dylib (`codesign -s -`). Assemble `hegel-gdscript-<version>.zip` holding `addons/hegel/` with `bin/` filled, plus `LICENSE`, `README.md` and `CHANGELOG.md`. Attach it to a GitHub release with the CHANGELOG section as notes.
- **`justfile`**: a `package` recipe that builds the zip from whatever libraries are in `addons/hegel/bin/`, so it also runs locally.
- **Smoke test of the artifact**: a CI step unzips the package into a fresh Godot project, imports it, and runs one property through the plain runner (p8). This catches missing files and wrong library paths in `hegel.gdextension`.
- `AGENTS.md` and `README.md` gain the CI and release process.

## Steps

1. Check every tool and action version you pin against its current release. Use Godot's official download URLs for 4.7.2 and 4.5.x per OS.
2. Write `ci.yml`. Validate it locally with `actionlint` through a container or binary download, if the owner agrees, and log what you ran.
3. `just package`, and test it locally on Linux, including the artifact smoke test.
4. Write `release.yml`.
5. Gate: ask the owner to push. Fix failures per platform. Windows path separators, shell differences in the `justfile`, and the macOS library name are the likely ones. Record each fix under Deviations.
6. With the owner, make a release-candidate tag (for example `v0.1.0-rc.1`) and check the zip's contents. Whether to keep or delete that release is the owner's call.

## Completion

- [ ] `ci.yml` is green on all three platforms and the 4.5 floor job, on a pushed commit (the owner reports the run).
- [ ] Breaking a test on purpose in a throwaway branch turns CI red on every platform. The owner pushes it, then deletes the branch.
- [ ] `just package` produces a zip that, unpacked into an empty Godot project, runs a property headless (locally and in CI).
- [ ] The release workflow has produced a zip with all three libraries for a release-candidate tag.

## Non-goals

- Linux arm64, Windows arm64, Intel macOS, web or mobile builds.
- Notarizing the macOS build, and code signing beyond ad-hoc.
- Asset Library publishing (verdict 21).
