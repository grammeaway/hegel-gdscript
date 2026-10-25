use crate::call;
use godot::prelude::*;
use hegel_c as c;

/// An engine-managed collection, from `HegelNativeTestCase.new_collection`
/// and driven through its `collection_*` methods, where the results land.
#[derive(GodotClass)]
#[class(no_init, base=RefCounted)]
pub struct HegelNativeCollection {
    pub(crate) raw: *mut c::HegelCollection,
}

impl Drop for HegelNativeCollection {
    fn drop(&mut self) {
        // SAFETY: raw came from hegel_new_collection and is freed once.
        call(|ctx| unsafe { c::hegel_collection_free(ctx, self.raw) });
    }
}
