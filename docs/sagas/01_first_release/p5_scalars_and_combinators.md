# P5: Scalars and combinators

## Finding

After p4, the only generator is `integers`. PLAN item 3 lists floats, booleans, `sampled_from`, `one_of` and `map` / `filter` / `flat_map`. The ported quality tests also need `just` and `composite` (F9), and users composing values need `composite` too. Each generator's spans and draws decide how well the engine can shrink its values, so they have to match upstream's.

## Change

Each generator below follows its counterpart in `frontends/python/python/hegel/generators/` (`numeric.py`, `combinators.py`, `base.py`, `composite.py`) for defaults, validation and span structure, with the C++ `Generator Pattern` section (`frontends/cpp/AGENTS.md`) as a cross-check. Labels follow D10.

- `floats(min_value, max_value, allow_nan, allow_infinity, exclude_min, exclude_max)`: width 64, since GDScript floats are doubles. Use Python's defaults for NaN and infinity relative to the bounds. Native: `generate_float`. Simplest value: 0.0 clamped into range.
- `booleans()`: native `generate_boolean`, p = 0.5.
- `just(value)`: draws nothing.
- `sampled_from(elements: Array)`: a bare index draw, with no span (as in C++).
- `one_of(generators: Array)`: a `one_of` span and a branch index.
- `HegelGenerator.map(f)`, `.filter(predicate)`, `.flat_map(f)`, with the spans and labels from `base.py`. `filter` makes 3 attempts in `filter.attempt` spans, closing a failed one with `discard = true`, and then rejects the case (`assume(false)`). Chained filters merge into one.
- `composite(fn: Callable)`: `fn.call(tc)` inside a `composite` span. The body draws with `tc.draw`, and those draws print nothing (p3's rule for nested draws).
- **Invalid arguments.** Ask the owner; the recommendation is this. At construction, `push_error` a message naming the generator and the argument, and return an invalid generator. Drawing an invalid generator ends the run with a usage error (`HegelResult.error`), not a counterexample. Cases: `min > max`, an empty `sampled_from` or `one_of`, NaN bounds, a non-generator in `one_of`, a `flat_map` function that returns a non-generator (detected at draw time).
- **The `gs` alias (F6).** Check that `const gs := preload("res://addons/hegel/generators.gd")` gives `gs.integers()` with autocomplete in the editor, and use it in every test from now on.

## Steps

1. Ask the owner the invalid-argument question, and record the answer.
2. Native: `generate_float`, `generate_boolean`. Simplest mode covers both (D8).
3. Each generator test-first, one test file per family under `tests/generators/`: contract tests (D1a: bounds held, every branch or element reachable through `find_any`, `exclude_min` excludes) and validation tests.
4. Quality ports (D1b) into `tests/quality/`, from `frontends/cpp/tests/shrink_quality/` and `find_quality/`: `test_floats.cpp`, `test_flatmap.cpp`, `test_one_of.cpp`, and the parts of `test_mixed_types.cpp` that need no collections. Keep each upstream test's name in a comment, so the port can be traced.
5. Bound properties across many parameter sets. A nested `Hegel.run` is a usage error (p2), so draw `(a, b)` pairs from a seeded `RandomNumberGenerator` in a plain loop, and run `assert_all_examples` for `integers(a, b)`, `floats(a, b)` and `integers(a, b).map(f).filter(g)` on each pair.
6. Document the generators with `##` comments, and record the API in `AGENTS.md`.

## Completion

- [x] `just check` is green.
- [x] `minimal(floats(), x > 1.0)` returns `2.0` and `minimal(floats(), x > 0.0)` returns `1.0`, as in `ShrinkFloats.ShrinksToSimpleFloatAbove1` / `Above0`. If the engine shrinks elsewhere, that's an engine divergence: record it under Found and ask.
- [x] Dropping the `filter.attempt` span's `discard = true` turns a filter quality test red. Check this, then restore it. If no ported test notices, record that. (No test notices: recorded under Found.)
- [x] Making `one_of` draw its index without a span turns a quality or contract test red, or a recorded note explains why upstream's tests don't pin it. (Not pinned: recorded under Found.)
- [x] Every generator has a validation test that ends in a usage error. (`booleans` and `just` take no arguments that can be invalid.)

## Non-goals

- Collections, text (p6).
- Godot types (Vector2, Color) as generators. They're `map()` recipes, documented in p8 (D3).
- `from_type`, `builds`, `recursive`, weighted `one_of`.
