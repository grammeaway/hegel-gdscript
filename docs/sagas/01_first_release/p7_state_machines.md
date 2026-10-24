# P7: State machines

## Finding

Godot games are mostly state machines, and Nomu's key properties are sequences of actions: arcs never soft-lock, save → load → save is stable after any history. PLAN item 6 asks for a single-threaded state-machine helper. The engine owns rule selection, swarm testing and the step budget (`hegel_new_state_machine`, `hegel_state_machine_next_group`, `_next_rule`, `_rule_rejected`, `_should_check_invariant`). So the frontend's part is the loop, the spans and the report. In GDScript a rule's `tc.assume(false)` can't unwind the rule by itself: the rule body returns early on its own, and then the runner has to tell the engine.

## Change

- **API.** Ask the owner before building; the recommendation:

  ```gdscript
  HegelStateMachine.run(tc,
      {"add": func(tc: HegelTestCase) -> void: ..., "remove": func(tc): ...},
      {"non_negative": func(tc: HegelTestCase) -> void: tc.check(total >= 0, "negative")},
      50)  # max_steps
  ```

  Rules and invariants are `Dictionary[String, Callable]`, taking `tc`. Each invariant fails through `tc.check` or a runtime error, the same failure paths as a body, so there's one failure model. State lives in the user's closure or object. A machine with no rules, or with `max_steps < 1`, is a usage error.
- **Loop.** Copy `_run_sequential` in `frontends/python/python/hegel/stateful.py`:
  - `new_state_machine` with concurrency 1, 1, all weights equal, no invariant always-checked;
  - all invariants on the initial state;
  - then rounds: a `stateful.rule` span, `next_group`, then `next_rule` until DONE, running each rule. After the round, run the invariants the engine samples (`should_check_invariant`);
  - all invariants on the final state.
- **Rejection inside a rule.** A failed `assume` during a rule is a rejected *step*, not a rejected case. The runner sees the rejection after the rule returns, calls `rule_rejected`, clears the case-level rejection, notes "Rule stopped early due to violated assumption", and closes the round's span with `discard = true`. Simplest mode was on only for the rest of that rule; it ends with the rejection. Any other terminal event (a failed check, an error, a stop-test) ends the machine, and the case keeps that status.
- **Report.** Step lines as in the C++ approval `test_stateful.Stateful.StatePrintingIsOnByDefault`, minus the state lines. A rule's draws are indented under its step:

  ```
    Checking invariants on the initial state.
    Step 1: add {
      var amount = 3
    }
    Step 2: add {
      var amount = 9
    }
    Invariant non_negative failed:
  ```

- Native: `HegelNativeStateMachine`, freed on drop. In simplest mode, `next_group` is DONE (D8).

## Steps

1. Ask the owner the API question, and whether to print state through an optional `describe: Callable`. The recommendation is no: notes cover it.
2. Native bindings, then the loop, test-first in `tests/state_machine_test.gd`, porting `frontends/cpp/tests/test_stateful.cpp`'s sequential tests:
   - `BasicRun`, `EmptyRulesThrows` (as a usage error), `InvariantViolationReported`, `StepCountCapsStepsPerCase`, `StepCountBelowOneThrows`;
   - `InvariantsAreSampledRatherThanRunAfterEveryRule`, `PersistentViolationsAreAlwaysCaughtDespiteSampling`.
3. Quality, PLAN item 7: "finds the shortest failing action sequence". A counter with rules `inc` (+1) and `reset` (back to 0), and the invariant `count < 3`, shrinks to exactly three `inc` steps and no `reset`. Port the `Counter` overflow machine from `test_stateful.cpp` too, pinning its upstream expectation.
4. Rejection: a rule that `assume(false)`s half the time still lets the machine reach states that need several accepted rules. For a machine whose every rule rejects, find what upstream's sequential runner and its tests (`frontends/python/tests/test_stateful.py`) expect, and match it.
5. Snapshot subject for a stateful failure report (p3's mechanism).
6. Runtime errors inside a rule fail the machine with the rule's step in the report (uses p4).

## Completion

- [ ] `just check` is green.
- [ ] The inc/reset machine's report has exactly three `Step` lines, all `inc`.
- [ ] Skipping `rule_rejected` after a rejected rule turns a test red. Check this, then restore it.
- [ ] Skipping the unconditional final invariant check turns `PersistentViolationsAreAlwaysCaughtDespiteSampling` red. Check this, then restore it.

## Non-goals

- Concurrent machines, variable pools (`hegel_new_pool`), bundles, rule weights.
- Async rules or rules that wait for frames. Bodies are synchronous in this saga.
