# P5: Text from an alphabet

## Finding

`Gs.text()` draws from the whole Unicode range. The engine's distribution rarely lands on a given ASCII character: in the planning probe, 19% of 1000 draws held any ASCII punctuation and 0.7% held `=`. A parser of config-like syntax, where `=`, `[`, `]`, `"`, `;` and `#` matter, hardly ever sees them. That distribution is the engine's, so the fix is an alphabet, not a reweighting. The source project built `lists(sampled_from(chars)).map(join)`, which loses `text`'s label and string shrinking.

libhegel's `hegel_string_generator_text` takes categories, exclude-categories and include/exclude characters (`hegel.h`, near line 2297). `HegelNativeStringGenerator.text` (`rust/src/string_generator.rs:40`) passes NULL and empty for all of them (P6.1). Every upstream frontend has a fixed-alphabet option with the same mapping: Python `text(alphabet="…")` → `CharacterSpec(categories=[], include_characters=…)` (`frontends/python/python/hegel/generators/strings.py:168`); Rust `.alphabet(chars)` (`frontends/rust/src/generators/strings.rs:124`); C++ `TextParams::alphabet`.

## Change

D5: `Gs.text_from(alphabet: String, min_size := 0, max_size := -1) -> HegelGenerator`.

- Strings of `alphabet`'s characters only, through the same native string generator and `text`'s span label, so they shrink as `text` does.
- `max_size` -1 means `text`'s default (100, or `min_size + 100`). Sizes are validated as `text`'s are.
- Natively, extend the existing `text` binding, or add one `#[func]` beside it, so that the one `hegel_string_generator_text` call can take `include_characters` and an empty, non-NULL categories list. Keep it thin, and pick whichever reads simpler.
- An empty alphabet: copy Python's semantics (only `""`), and let the engine judge an empty alphabet with `min_size > 0`. If the engine accepts what Python rejects, or the reverse, record it under Found and ask the owner.
- Simplest mode returns what the engine shrinks to. Find it with `minimal(Gs.text_from("ba", 1, 1), …)` before writing `_Text`'s simplest value. Don't assume it is the first character.
- U+0000 can't be in a Godot `String`, so no alphabet can hold it (saga 01's Found, p6).

## Steps

1. Read upstream's alphabet handling in Python and Rust, and the header's text parameters.
2. Write the tests in `tests/generators/text_test.gd`: `assert_all_examples` (every character in the alphabet, sizes in bounds); `find_any` reaches each character of a small alphabet, and a string of every character of `"=[]"`; usage errors for bad sizes. In `tests/quality/`: the minimal value for a small alphabet, and shrinking towards shorter strings. Port any upstream quality case that uses an alphabet and name it. Watch them go red.
3. Extend the native binding; `just build`. Then the factory, and its `##` doc.
4. Docs: a row in the guide's generator table, plus one line: `one_of(Gs.text(), Gs.text_from("=[]\";#"))` mixes syntax characters into general text. Update `AGENTS.md`'s Generators bullet (the factory list) and `CHANGELOG.md`.

## Completion

- [ ] The new tests are red before and green after.
- [ ] Break it (drop `include_characters`, or pass NULL categories): the alphabet test goes red. Restore it.
- [ ] `cargo fmt --check` and `cargo clippy -- -D warnings` clean.
- [ ] `just check` green; CI green on all three platforms on push.

## Non-goals

- Categories, exclude-categories, exclude-characters, codecs, or a `characters()` factory (P6.1 still holds for them).
- Regex, email, URL or domain generators.
- Changing `text()`'s distribution.
