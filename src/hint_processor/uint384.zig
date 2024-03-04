const std = @import("std");

const CoreVM = @import("../vm/core.zig");
const field_helper = @import("../math/fields/helper.zig");
const Felt252 = @import("../math/fields/starknet.zig").Felt252;
const STARKNET_PRIME = @import("../math/fields/fields.zig").STARKNET_PRIME;
const SIGNED_FELT_MAX = @import("../math/fields/fields.zig").SIGNED_FELT_MAX;
const MaybeRelocatable = @import("../vm/memory/relocatable.zig").MaybeRelocatable;
const Relocatable = @import("../vm/memory/relocatable.zig").Relocatable;
const CairoVM = CoreVM.CairoVM;
const hint_utils = @import("hint_utils.zig");
const HintProcessor = @import("hint_processor_def.zig").CairoVMHintProcessor;
const HintData = @import("hint_processor_def.zig").HintData;
const HintReference = @import("hint_processor_def.zig").HintReference;
const hint_codes = @import("builtin_hint_codes.zig");
const Allocator = std.mem.Allocator;
const ApTracking = @import("../vm/types/programjson.zig").ApTracking;
const ExecutionScopes = @import("../vm/types/execution_scopes.zig").ExecutionScopes;

const MathError = @import("../vm/error.zig").MathError;
const HintError = @import("../vm/error.zig").HintError;
const CairoVMError = @import("../vm/error.zig").CairoVMError;

// Notes: Hints in this lib use the type Uint384, which is equal to common lib's BigInt3

// %{
//     def split(num: int, num_bits_shift: int, length: int):
//         a = []
//         for _ in range(length):
//             a.append( num & ((1 << num_bits_shift) - 1) )
//             num = num >> num_bits_shift
//         return tuple(a)

//     def pack(z, num_bits_shift: int) -> int:
//         limbs = (z.d0, z.d1, z.d2)
//         return sum(limb << (num_bits_shift * i) for i, limb in enumerate(limbs))

//     a = pack(ids.a, num_bits_shift = 128)
//     div = pack(ids.div, num_bits_shift = 128)
//     quotient, remainder = divmod(a, div)

//     quotient_split = split(quotient, num_bits_shift=128, length=3)
//     assert len(quotient_split) == 3

//     ids.quotient.d0 = quotient_split[0]
//     ids.quotient.d1 = quotient_split[1]
//     ids.quotient.d2 = quotient_split[2]

//     remainder_split = split(remainder, num_bits_shift=128, length=3)
//     ids.remainder.d0 = remainder_split[0]
//     ids.remainder.d1 = remainder_split[1]
//     ids.remainder.d2 = remainder_split[2]
// %}
pub fn uint384UnsignedDivRem(
    allocator: std.mem.Allocator,
    vm: *CairoVM,
    ids_data: std.StringHashMap(HintReference),
    ap_tracking: ApTracking,
) !void {
    const a = Uint384::from_var_name("a", vm, ids_data, ap_tracking)?.pack();
    const div = Uint384::from_var_name("div", vm, ids_data, ap_tracking)?.pack();

    if div.is_zero() {
        return Err(MathError::DividedByZero.into());
    }
    let (quotient, remainder) = a.div_mod_floor(&div);

    let quotient_split = Uint384::split(&quotient);
    quotient_split.insert_from_var_name("quotient", vm, ids_data, ap_tracking)?;

    let remainder_split = Uint384::split(&remainder);
    remainder_split.insert_from_var_name("remainder", vm, ids_data, ap_tracking)
}
