# Contributing

Thanks for helping. Bug reports and pull requests are welcome on [GitHub](https://github.com/grammeaway/hegel-gdscript).

[`AGENTS.md`](AGENTS.md) is the reference for the commands, the layout, the architecture and the code style. In short:

- You need Rust (through rustup; the toolchain is pinned in `rust-toolchain.toml`), [`just`](https://github.com/casey/just), [`uv`](https://docs.astral.sh/uv/) and Godot 4.7 as `godot` on your PATH (or set `GODOT`).
- On a fresh checkout, run `just build` and `just import`.
- `just check` runs the lints, the build, the import and every test. It must pass before a change is merged.

Every test runs against the real engine, with no mocks. A change in behaviour comes with a test that fails without it.

Behaviour follows Hegel's own frontends, especially the Python one. If libhegel seems to behave differently from them, open an issue rather than working around it here.
