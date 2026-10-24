# P6: Collections and text

## Finding

After p5, there's no way to draw a variable-sized value, and most real properties need one: a list of actions, a save dictionary, a player name. PLAN item 3 asks for lists. The owner added `dictionaries` and `text` (D3), and the quality ports need `tuples` (F9). The engine owns collection sizes (`hegel_new_collection` / `hegel_collection_more` / `hegel_collection_reject`) and text generation (`hegel_string_generator_text` + `hegel_generate_string`), so the GDScript layer stays small. A Godot `String` can't hold U+0000, and the engine's alphabet includes it (F5).

## Change

Each generator follows its Python counterpart in `frontends/python/python/hegel/generators/collections.py` and `strings.py` for parameters, defaults, validation and spans.

- `lists(elements, min_size := 0, max_size := -1, unique := false)` returns an `Array`, in a `list` span. The loop runs while `collection_more` is true, drawing one element each time. With `unique`, an element already present is pushed back with `collection_reject`. `-1` means no upper bound (`UINT64_MAX` natively).
- `tuples(...)` returns a fixed-length `Array` of one draw per generator, in a `tuple` span. Use a variadic `...generators` parameter if GDScript 4.5 supports it (check); otherwise take an `Array`, and record which.
- `dictionaries(keys, values, min_size := 0, max_size := -1)` returns a `Dictionary`, in a `dict` span. A duplicate key is rejected through the collection.
- `text(min_size := 0, max_size := -1, min_codepoint := 1, max_codepoint := 0x10FFFF)` returns a `String`. Codepoint 0 is always excluded (F5): a `min_codepoint` of 0 is raised to 1, and a docs note explains why. The native string-generator handle is built once, when the generator is built, and freed when it is released. Ask the owner whether to add more alphabet options now (`categories`, `exclude_characters`); the recommendation is no, until someone needs them.
- Native: `HegelNativeCollection` (`new`, `more`, `reject`, freed on drop) and `HegelNativeStringGenerator` (`text`, freed on drop), plus `HegelNativeTestCase.generate_string`.
- Simplest mode (D8): a collection's `more` is true only until `min_size`; text gives `"0".repeat(min_size)`.

## Steps

1. Ask the owner the text-options question, and record the answer.
2. Native bindings, then each generator test-first under `tests/generators/`. Contract tests (D1a):
   - sizes stay within bounds; empty and `max_size` are both reachable;
   - `unique` lists and dictionary keys have no duplicates;
   - `text` never contains U+0000, stays within its codepoints, and its `length()` stays within its sizes;
   - invalid sizes give usage errors.
3. Quality ports (D1b) into `tests/quality/collections_test.gd`, from `frontends/cpp/tests/shrink_quality/test_collections.cpp`, the list parts of `test_integers.cpp` and `test_mixed_types.cpp`, and `find_quality/test_collections.cpp`. Port `test_strings.cpp` for `text`, leaving out what needs the alphabet options this plan doesn't add. The `sets` tests become `lists(unique := true)`; the `map` tests become `dictionaries`.
4. PLAN item 7's headline case: `minimal(lists(integers()), sum > 100)`. Port the closest upstream test, and pin its expected value from that test.
5. A property for the addon itself: `assert_all_examples(lists(integers(0, 9), 2, 5), ...)` holds for sizes and bounds, across seeds drawn by an outer loop.

## Completion

- [ ] `just check` is green.
- [ ] `minimal(lists(booleans(), 50), xs.size() >= 70)` is 70 `false`s (`MinimizeLongList`).
- [ ] Removing the `collection_reject` call for duplicates turns the `unique` contract test red. Check this, then restore it.
- [ ] Removing the U+0000 exclusion turns the `text` contract test red. Check this, then restore it. If the engine never produces U+0000 in 1000 cases, force it with `min_codepoint = 0, max_codepoint = 0` and record what happens.
- [ ] Every ported upstream test is either present, or listed in `progress.md` with the reason it was skipped.

## Non-goals

- `sets` as a type (GDScript has none; `lists(unique := true)` covers it).
- Packed arrays (`PackedInt32Array`, …), regex, emails and URLs. Packed arrays are `map()` recipes for p8.
- Recursive generators.
