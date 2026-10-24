# hegel-gdscript

Property-based testing for GDScript, built on [Hegel](https://hegel.dev), the engine for property-based testing from the Hypothesis team.

**Pre-release.** Nothing here is usable yet. The aim is a Godot addon: `Hegel.run(func(tc): ...)` draws values from generators, shrinks failures to a minimal counterexample, reports them with a replay blob, counts runtime errors as failures, and runs stateful tests built from rules and invariants.

Building from source needs Rust (through rustup), [`just`](https://github.com/casey/just), [`uv`](https://docs.astral.sh/uv/) and Godot 4.7. The addon itself will support Godot 4.5 and newer. Run `just check`; see `AGENTS.md` for the commands and layout.

MIT licensed.
