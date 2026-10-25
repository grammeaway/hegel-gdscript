use crate::call;
use godot::prelude::*;
use hegel_c as c;

/// An engine-owned sequential state machine, from
/// `HegelNativeTestCase.new_state_machine` and driven through its
/// `state_machine_*` methods, where the results land.
#[derive(GodotClass)]
#[class(no_init, base=RefCounted)]
pub struct HegelNativeStateMachine {
    pub(crate) raw: *mut c::HegelStateMachine,
}

impl Drop for HegelNativeStateMachine {
    fn drop(&mut self) {
        // SAFETY: raw came from hegel_new_state_machine and is freed once.
        call(|ctx| unsafe { c::hegel_state_machine_free(ctx, self.raw) });
    }
}
