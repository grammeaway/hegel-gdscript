Your task is to implement the next plan in ./docs/sagas/01_first_release/. Read its README.md and progress.md first, then the plan file. Keep a high degree of engineering rigor, and keep progress.md up to date, including any deviations from the plan.

Ask the owner whenever you are in doubt: about scope, public API shape, or behaviour a user would notice. Several plans name questions to ask before building; ask them first. Record each answer in progress.md under Decisions. Decide internal details yourself and log them there as agent decisions.

This will be published as FOSS. Hold the code to that standard: small, readable, statically typed GDScript, a thin native layer, and concise comments that explain why, only where the code can't. Public API gets `##` doc comments.

Godot 4.7.2 is on PATH as `godot`; run everything headless. Rust comes through rustup (the default toolchain is a nightly; the repo pins its own). Hegel's upstream monorepo is the reference: clone https://github.com/hegeldev/hegel at tag `libhegel/0.48.0` into /tmp/hegel if it isn't there. Ask before installing tools, before downloading a Rust toolchain, and before creating anything on GitHub or any cloud. Keep test and build commands on short timeouts, and check on progress rather than waiting on one long run.

The end goal is a property-based testing addon for GDScript, built on Hegel: `Hegel.run` with generators, shrinking, failure reports with replay blobs, runtime errors counted as failures, and stateful testing. It is validated like Hegel's own frontends, against the real engine, built and tested on Linux, Windows and macOS, and good enough to use in Nomu and to publish.
