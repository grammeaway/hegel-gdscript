Your task is to implement the next plan in ./docs/sagas/02_rc1_dogfooding/. Read its README.md and progress.md first, then the plan file. Keep a high degree of engineering rigor, and keep progress.md up to date, including any deviations from the plan.

Bug fixes are test-first: the regression test goes red on the old code before the fix turns it green. When a test fails, presume the code is wrong before the test; if a test was wrong, fix it and say why in progress.md.

Ask the owner whenever you are in doubt: about scope, public API shape, or behaviour a user would notice. Record each answer in progress.md under Decisions. Decide internal details yourself and log them there as agent decisions. The saga's source is a dogfooding pass on a game project; refer to it that way, without naming the project, in code, docs and commit messages.

This is published as FOSS. Hold the code to that standard: small, readable, statically typed GDScript, a thin native layer, and concise comments that explain why, only where the code can't. Public API gets `##` doc comments.

Godot 4.7.2 is on PATH as `godot`; run everything headless. Hegel's upstream monorepo is the reference: if /tmp/hegel is missing, clone https://github.com/hegeldev/hegel and check out `5195b0b`. Ask before installing tools, and before creating anything on GitHub or any cloud. Keep test and build commands on short timeouts, and check on progress rather than waiting on one long run.

The end goal is the next release candidate with every confirmed finding from the rc.1 dogfooding fixed or documented, and nothing that worked in rc.1 broken.
