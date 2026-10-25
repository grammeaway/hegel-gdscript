use crate::collection::HegelNativeCollection;
use crate::state_machine::HegelNativeStateMachine;
use crate::string_generator::HegelNativeStringGenerator;
use crate::{Outcome, call, hstr, out_of_range, string_from};
use godot::prelude::*;
use hegel_c as c;
use std::ptr;

/// A handle onto one test case of a run.
#[derive(GodotClass)]
#[class(no_init, base=RefCounted)]
pub struct HegelNativeTestCase {
    raw: *mut c::HegelTestCase,
    #[var(no_set)]
    last_result: i64,
    #[var(no_set)]
    last_error: GString,
}

impl Drop for HegelNativeTestCase {
    fn drop(&mut self) {
        // SAFETY: raw came from hegel_next_test_case and is freed once.
        call(|ctx| unsafe { c::hegel_test_case_free(ctx, self.raw) });
    }
}

impl HegelNativeTestCase {
    pub(crate) fn wrap(raw: *mut c::HegelTestCase) -> Gd<Self> {
        Gd::from_object(Self {
            raw,
            last_result: 0,
            last_error: GString::new(),
        })
    }

    fn record(&mut self, (result, error): Outcome) -> i64 {
        self.last_result = result;
        self.last_error = error;
        result
    }
}

#[godot_api]
impl HegelNativeTestCase {
    #[constant]
    const STATUS_VALID: i64 = c::hegel_status_t::HEGEL_STATUS_VALID as i64;
    #[constant]
    const STATUS_INVALID: i64 = c::hegel_status_t::HEGEL_STATUS_INVALID as i64;
    #[constant]
    const STATUS_OVERRUN: i64 = c::hegel_status_t::HEGEL_STATUS_OVERRUN as i64;
    #[constant]
    const STATUS_INTERESTING: i64 = c::hegel_status_t::HEGEL_STATUS_INTERESTING as i64;

    /// An integer in `[min_value, max_value]`, or 0 on failure.
    #[func]
    fn generate_integer(&mut self, min_value: i64, max_value: i64) -> i64 {
        let tc = self.raw;
        let mut out = 0i64;
        self.record(call(|ctx| unsafe {
            c::hegel_generate_integer(ctx, tc, min_value, max_value, &mut out)
        }));
        out
    }

    /// A 64-bit float, as GDScript's are, with no limit on small nonzero
    /// magnitudes; 0.0 on failure.
    #[func]
    fn generate_float(
        &mut self,
        min_value: f64,
        max_value: f64,
        allow_nan: bool,
        allow_infinity: bool,
        exclude_min: bool,
        exclude_max: bool,
    ) -> f64 {
        let tc = self.raw;
        let mut out = 0.0f64;
        self.record(call(|ctx| unsafe {
            c::hegel_generate_float(
                ctx,
                tc,
                64,
                min_value,
                max_value,
                allow_nan,
                allow_infinity,
                exclude_min,
                exclude_max,
                f64::from_bits(1),
                &mut out,
            )
        }));
        out
    }

    /// `true` with probability `p`, unforced; false on failure.
    #[func]
    fn generate_boolean(&mut self, p: f64) -> bool {
        let tc = self.raw;
        let mut out = false;
        self.record(call(|ctx| unsafe {
            c::hegel_generate_boolean(ctx, tc, p, false, false, &mut out)
        }));
        out
    }

    /// A string from `generator`, or "" on failure. A U+0000 in it is kept
    /// only as far as Godot's String keeps it.
    #[func]
    fn generate_string(&mut self, generator: Gd<HegelNativeStringGenerator>) -> GString {
        let (tc, generator) = (self.raw, generator.bind().raw);
        let mut out = c::hegel_string_t::default();
        self.record(call(|ctx| unsafe {
            c::hegel_generate_string(ctx, tc, generator, &mut out)
        }));
        let value = string_from(out);
        // SAFETY: out is null or the engine's own allocation, freed once.
        call(|ctx| unsafe { c::hegel_owned_string_free(ctx, &mut out) });
        GString::from(&value)
    }

    /// A collection of `min_size` to `max_size` elements, or null on
    /// failure. A negative `max_size` means no upper bound.
    #[func]
    fn new_collection(
        &mut self,
        min_size: i64,
        max_size: i64,
    ) -> Option<Gd<HegelNativeCollection>> {
        let Ok(min) = u64::try_from(min_size) else {
            self.record(out_of_range("min_size", min_size));
            return None;
        };
        let max = u64::try_from(max_size).unwrap_or(u64::MAX);
        let tc = self.raw;
        let mut raw = ptr::null_mut();
        self.record(call(|ctx| unsafe {
            c::hegel_new_collection(ctx, tc, min, max, &mut raw)
        }));
        (!raw.is_null()).then(|| Gd::from_object(HegelNativeCollection { raw }))
    }

    /// Whether the engine wants another element; false on failure.
    #[func]
    fn collection_more(&mut self, collection: Gd<HegelNativeCollection>) -> bool {
        let (tc, collection) = (self.raw, collection.bind().raw);
        let mut out = false;
        self.record(call(|ctx| unsafe {
            c::hegel_collection_more(ctx, tc, collection, &mut out)
        }));
        out
    }

    /// Discards the element just drawn, so it doesn't count towards the size.
    #[func]
    fn collection_reject(&mut self, collection: Gd<HegelNativeCollection>) -> i64 {
        let (tc, collection) = (self.raw, collection.bind().raw);
        self.record(call(|ctx| unsafe {
            c::hegel_collection_reject(ctx, tc, collection, ptr::null())
        }))
    }

    /// A sequential machine (concurrency 1, one group, equal weights, every
    /// invariant sampled) running at most `step_count` rules, or null on
    /// failure.
    #[func]
    fn new_state_machine(
        &mut self,
        rule_names: PackedStringArray,
        invariant_names: PackedStringArray,
        step_count: i64,
    ) -> Option<Gd<HegelNativeStateMachine>> {
        let rules: Vec<String> = rule_names
            .as_slice()
            .iter()
            .map(|s| s.to_string())
            .collect();
        let invariants: Vec<String> = invariant_names
            .as_slice()
            .iter()
            .map(|s| s.to_string())
            .collect();
        let rule_strs: Vec<c::hegel_string_t> = rules.iter().map(|s| hstr(s)).collect();
        let invariant_strs: Vec<c::hegel_string_t> = invariants.iter().map(|s| hstr(s)).collect();
        let groups = vec![0i64; rules.len()];
        let tc = self.raw;
        let mut raw = ptr::null_mut();
        let mut concurrency = 0i64;
        self.record(call(|ctx| unsafe {
            c::hegel_new_state_machine(
                ctx,
                tc,
                rule_strs.as_ptr(),
                groups.as_ptr(),
                ptr::null(),
                rule_strs.len(),
                invariant_strs.as_ptr(),
                ptr::null(),
                invariant_strs.len(),
                1,
                1,
                step_count,
                &mut raw,
                &mut concurrency,
            )
        }));
        (!raw.is_null()).then(|| Gd::from_object(HegelNativeStateMachine { raw }))
    }

    /// The next round's group id (always 0), or `HegelNative.STATE_MACHINE_DONE`
    /// when the machine is done or on failure.
    #[func]
    fn state_machine_next_group(&mut self, machine: Gd<HegelNativeStateMachine>) -> i64 {
        let (tc, machine) = (self.raw, machine.bind().raw);
        let mut out = c::HEGEL_STATE_MACHINE_DONE;
        self.record(call(|ctx| unsafe {
            c::hegel_state_machine_next_group(ctx, tc, machine, &mut out)
        }));
        out
    }

    /// The index of the next rule to run, or `HegelNative.STATE_MACHINE_DONE`
    /// when the round is over or on failure.
    #[func]
    fn state_machine_next_rule(&mut self, machine: Gd<HegelNativeStateMachine>) -> i64 {
        let (tc, machine) = (self.raw, machine.bind().raw);
        let mut out = c::HEGEL_STATE_MACHINE_DONE;
        self.record(call(|ctx| unsafe {
            c::hegel_state_machine_next_rule(ctx, tc, machine, 0, &mut out)
        }));
        out
    }

    /// Reports that the rule just returned stopped at a failed assumption.
    #[func]
    fn state_machine_rule_rejected(&mut self, machine: Gd<HegelNativeStateMachine>) -> i64 {
        let (tc, machine) = (self.raw, machine.bind().raw);
        self.record(call(|ctx| unsafe {
            c::hegel_state_machine_rule_rejected(ctx, tc, machine, 0)
        }))
    }

    /// Whether to check invariant `index` at this point; false on failure.
    #[func]
    fn state_machine_should_check_invariant(
        &mut self,
        machine: Gd<HegelNativeStateMachine>,
        index: i64,
    ) -> bool {
        let (tc, machine) = (self.raw, machine.bind().raw);
        let mut out = false;
        self.record(call(|ctx| unsafe {
            c::hegel_state_machine_should_check_invariant(ctx, tc, machine, index, &mut out)
        }));
        out
    }

    /// `label` is a u64 bit-cast to int, from `HegelNative.label_*`.
    #[func]
    fn start_span(&mut self, label: i64) -> i64 {
        let tc = self.raw;
        self.record(call(|ctx| unsafe {
            c::hegel_start_span(ctx, tc, label as u64)
        }))
    }

    #[func]
    fn stop_span(&mut self, discard: bool) -> i64 {
        let tc = self.raw;
        self.record(call(|ctx| unsafe { c::hegel_stop_span(ctx, tc, discard) }))
    }

    #[func]
    fn should_capture(&mut self) -> bool {
        let tc = self.raw;
        let mut out = false;
        self.record(call(|ctx| unsafe {
            c::hegel_test_case_should_capture(ctx, tc, &mut out)
        }));
        out
    }

    /// `status` is one of the `STATUS_*` constants. `origin` is passed only
    /// when non-empty; libhegel reads it only for `STATUS_INTERESTING`.
    #[func]
    fn mark_complete(&mut self, status: i64, origin: GString) -> i64 {
        let Ok(status_u32) = u32::try_from(status) else {
            return self.record(out_of_range("status", status));
        };
        let (tc, origin) = (self.raw, origin.to_string());
        let origin_str = hstr(&origin);
        let origin_ptr = if origin.is_empty() {
            ptr::null()
        } else {
            &origin_str
        };
        self.record(call(|ctx| unsafe {
            c::hegel_mark_complete(ctx, tc, status_u32, origin_ptr)
        }))
    }
}
