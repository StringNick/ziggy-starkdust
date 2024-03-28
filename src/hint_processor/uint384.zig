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
    _ = allocator; // autofix
    _ = vm; // autofix
    _ = ids_data; // autofix
    _ = ap_tracking; // autofix
    // const a = Uint384::from_var_name("a", vm, ids_data, ap_tracking)?.pack();
    // const div = Uint384::from_var_name("div", vm, ids_data, ap_tracking)?.pack();

    // if div.is_zero() {
    //     return Err(MathError::DividedByZero.into());
    // }
    // let (quotient, remainder) = a.div_mod_floor(&div);

    // let quotient_split = Uint384::split(&quotient);
    // quotient_split.insert_from_var_name("quotient", vm, ids_data, ap_tracking)?;

    // let remainder_split = Uint384::split(&remainder);
    // remainder_split.insert_from_var_name("remainder", vm, ids_data, ap_tracking)
}

// Implements Hint:
//    %{
//        ids.low = ids.a & ((1<<128) - 1)
//        ids.high = ids.a >> 128
//    %}
pub fn uint384Split128(
    allocator: std.mem.Allocator,
    vm: *CairoVM,
    ids_data: std.StringHashMap(HintReference),
    ap_tracking: ApTracking,
) !void {
    const bound = Felt252.pow2Const(128);
    const a = try hint_utils.getIntegerFromVarName("a", vm, ids_data, ap_tracking);
    const high_low = try a.divRem(bound);

    try hint_utils.insertValueFromVarName(allocator, "low", high_low.r, vm, ids_data, ap_tracking);
    try hint_utils.insertValueFromVarName(allocator, "high", high_low.q, vm, ids_data, ap_tracking);
}

// /* Implements Hint:
// %{
//     sum_d0 = ids.a.d0 + ids.b.d0
//     ids.carry_d0 = 1 if sum_d0 >= ids.SHIFT else 0
//     sum_d1 = ids.a.d1 + ids.b.d1 + ids.carry_d0
//     ids.carry_d1 = 1 if sum_d1 >= ids.SHIFT else 0
//     sum_d2 = ids.a.d2 + ids.b.d2 + ids.carry_d1
//     ids.carry_d2 = 1 if sum_d2 >= ids.SHIFT else 0
// %}
//  */
// pub fn add_no_uint384_check(
//     vm: &mut VirtualMachine,
//     ids_data: &HashMap<String, HintReference>,
//     ap_tracking: &ApTracking,
//     constants: &HashMap<String, Felt252>,
// ) -> Result<(), HintError> {
//     let a = Uint384::from_var_name("a", vm, ids_data, ap_tracking)?;
//     let b = Uint384::from_var_name("b", vm, ids_data, ap_tracking)?;
//     // This hint is not from the cairo commonlib, and its lib can be found under different paths, so we cant rely on a full path name
//     let shift = get_constant_from_var_name("SHIFT", constants)?.to_biguint();

//     let sum_d0 = (a.limbs[0].as_ref().to_biguint()) + (b.limbs[0].as_ref().to_biguint());
//     let carry_d0 = BigUint::from((sum_d0 >= shift) as usize);
//     let sum_d1 =
//         (a.limbs[1].as_ref().to_biguint()) + (b.limbs[1].as_ref().to_biguint()) + &carry_d0;
//     let carry_d1 = BigUint::from((sum_d1 >= shift) as usize);
//     let sum_d2 =
//         (a.limbs[2].as_ref().to_biguint()) + (b.limbs[2].as_ref().to_biguint()) + &carry_d1;
//     let carry_d2 = Felt252::from((sum_d2 >= shift) as usize);

//     insert_value_from_var_name(
//         "carry_d0",
//         Felt252::from(&carry_d0),
//         vm,
//         ids_data,
//         ap_tracking,
//     )?;
//     insert_value_from_var_name(
//         "carry_d1",
//         Felt252::from(&carry_d1),
//         vm,
//         ids_data,
//         ap_tracking,
//     )?;
//     insert_value_from_var_name("carry_d2", carry_d2, vm, ids_data, ap_tracking)
// }

// /* Implements Hint
// %{
//     from starkware.python.math_utils import isqrt

//     def split(num: int, num_bits_shift: int, length: int):
//         a = []
//         for _ in range(length):
//             a.append( num & ((1 << num_bits_shift) - 1) )
//             num = num >> num_bits_shift
//         return tuple(a)

//     def pack(z, num_bits_shift: int) -> int:
//         limbs = (z.d0, z.d1, z.d2)
//         return sum(limb << (num_bits_shift * i) for i, limb in enumerate(limbs))

//     a = pack(ids.a, num_bits_shift=128)
//     root = isqrt(a)
//     assert 0 <= root < 2 ** 192
//     root_split = split(root, num_bits_shift=128, length=3)
//     ids.root.d0 = root_split[0]
//     ids.root.d1 = root_split[1]
//     ids.root.d2 = root_split[2]
// %}
//  */
// pub fn uint384_sqrt(
//     vm: &mut VirtualMachine,
//     ids_data: &HashMap<String, HintReference>,
//     ap_tracking: &ApTracking,
// ) -> Result<(), HintError> {
//     let a = Uint384::from_var_name("a", vm, ids_data, ap_tracking)?.pack();

//     let root = isqrt(&a)?;

//     if root.is_zero() || root.bits() > 192 {
//         return Err(HintError::AssertionFailed(
//             "assert 0 <= root < 2 ** 192".to_string().into_boxed_str(),
//         ));
//     }
//     let root_split = Uint384::split(&root);
//     root_split.insert_from_var_name("root", vm, ids_data, ap_tracking)
// }

// Implements Hint:
//   memory[ap] = 1 if 0 <= (ids.a.d2 % PRIME) < 2 ** 127 else 0
pub fn uint384SignedNn(
    allocator: std.mem.Allocator,
    vm: *CairoVM,
    ids_data: std.StringHashMap(HintReference),
    ap_tracking: ApTracking,
) !void {
    const a_addr = try hint_utils.getRelocatableFromVarName("a", vm, ids_data, ap_tracking);
    const a_d2 = vm.getFelt(try a_addr.addUint(2)) catch return HintError.IdentifierHasNoMember;

    try hint_utils.insertValueIntoAp(allocator, vm, MaybeRelocatable.fromFelt(if (a_d2.numBits() <= 127) Felt252.one() else Felt252.zero()));
}

// Implements Hint:
// %{
//     def split(num: int, num_bits_shift: int, length: int):
//         a = []
//         for _ in range(length):
//         a.append( num & ((1 << num_bits_shift) - 1) )
//         num = num >> num_bits_shift
//         return tuple(a)

//     def pack(z, num_bits_shift: int) -> int:
//         limbs = (z.d0, z.d1, z.d2)
//         return sum(limb << (num_bits_shift * i) for i, limb in enumerate(limbs))

//     a = pack(ids.a, num_bits_shift = 128)
//     b = pack(ids.b, num_bits_shift = 128)
//     p = pack(ids.p, num_bits_shift = 128)

//     res = (a - b) % p

//     res_split = split(res, num_bits_shift=128, length=3)

//     ids.res.d0 = res_split[0]
//     ids.res.d1 = res_split[1]
//     ids.res.d2 = res_split[2]
// %}
pub fn subReducedAAndReducedB(
    allocator: std.mem.Allocator,
    vm: *CairoVM,
    ids_data: std.StringHashMap(HintReference),
    ap_tracking: ApTracking,
) !void {
    _ = allocator; // autofix
    _ = vm; // autofix
    _ = ids_data; // autofix
    _ = ap_tracking; // autofix
    // const a = try Uint384.fromVarName("a", vm, ids_data, ap_tracking).pack();
    // const b = try Uint384.fromVarName("b", vm, ids_data, ap_tracking).pack();
    // const p = try Uint384.fromVarName("p", vm, ids_data, ap_tracking).pack();
    // let res = if a > b {
    //     (a - b).mod_floor(&p)
    // } else {
    //     &p - (b - &a).mod_floor(&p)
    // };

    // let res_split = Uint384::split(&res);
    // res_split.insert_from_var_name("res", vm, ids_data, ap_tracking)
}


 // Implements Hint:
 //       %{
 //           def split(num: int, num_bits_shift: int, length: int):
 //               a = []
 //               for _ in range(length):
 //                   a.append( num & ((1 << num_bits_shift) - 1) )
 //                   num = num >> num_bits_shift
 //               return tuple(a)

 //           def pack(z, num_bits_shift: int) -> int:
 //               limbs = (z.d0, z.d1, z.d2)
 //               return sum(limb << (num_bits_shift * i) for i, limb in enumerate(limbs))

 //           def pack_extended(z, num_bits_shift: int) -> int:
 //               limbs = (z.d0, z.d1, z.d2, z.d3, z.d4, z.d5)
 //               return sum(limb << (num_bits_shift * i) for i, limb in enumerate(limbs))

 //           a = pack_extended(ids.a, num_bits_shift = 128)
 //           div = pack(ids.div, num_bits_shift = 128)

 //           quotient, remainder = divmod(a, div)

 //           quotient_split = split(quotient, num_bits_shift=128, length=6)

 //           ids.quotient.d0 = quotient_split[0]
 //           ids.quotient.d1 = quotient_split[1]
 //           ids.quotient.d2 = quotient_split[2]
 //           ids.quotient.d3 = quotient_split[3]
 //           ids.quotient.d4 = quotient_split[4]
 //           ids.quotient.d5 = quotient_split[5]

 //           remainder_split = split(remainder, num_bits_shift=128, length=3)
 //           ids.remainder.d0 = remainder_split[0]
 //           ids.remainder.d1 = remainder_split[1]
 //           ids.remainder.d2 = remainder_split[2]
 //       %}
pub fn unsignedDivRemUint768ByUint384(
    allocator: std.mem.Allocator,
    vm: *CairoVM,
    ids_data: std.StringHashMap(HintReference),
    ap_tracking: ApTracking,
) !void {
    const a = Uint768.fromVarName("a", vm, ids_data, ap_tracking).pack();
    const div = Uint384.fromVarName("div", vm, ids_data, ap_tracking).pack();

    if div.is_zero() {
        return Err(MathError::DividedByZero.into());
    }
    let (quotient, remainder) = a.div_mod_floor(&div);
    let quotient_split = Uint768::split(&quotient);
    quotient_split.insert_from_var_name("quotient", vm, ids_data, ap_tracking)?;
    let remainder_split = Uint384::split(&remainder);
    remainder_split.insert_from_var_name("remainder", vm, ids_data, ap_tracking)
}
