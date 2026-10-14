# intops
# Copyright 2025-2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

## Intel/AMD intrinsics-based implementations of arithmetic operations for integers.

import ../../consts

when cpuX86 and canUseIntrinsics:
  when compilerMsvc:
    {.pragma: x86_header, header: "<intrin.h>", nodecl.}
  else:
    {.pragma: x86_header, header: "<x86intrin.h>", nodecl.}

  func builtinCarryingAdd*(
    carry: uint8, a, b: cuint, res: ptr cuint
  ): uint8 {.importc: "_addcarry_u32", x86_header.}

  func builtinBorrowingSub*(
    borrow: uint8, a, b: cuint, res: ptr uint32
  ): uint8 {.importc: "_subborrow_u32", x86_header.}

  {.push raises: [], inline, noinit, gcsafe.}

  func carryingAdd*(a, b: uint32, carry: bool): (uint32, bool) =
    var res {.noinit.}: uint32

    let carry =
      builtinCarryingAdd(uint8(carry), cuint(a), cuint(b), cast[ptr cuint](addr res))

    (res, bool(carry))

  func carry*(a, b: uint32, carry: bool): bool =
    var res {.noinit.}: cuint

    let carry = builtinCarryingAdd(uint8(carry), cuint(a), cuint(b), addr res)

    bool(carry)

  func borrowingSub*(a, b: uint32, borrow: bool): (uint32, bool) =
    var res {.noinit.}: uint32

    let borrow =
      builtinBorrowingSub(uint8(borrow), cuint(a), cuint(b), cast[ptr cuint](addr res))

    (res, bool(borrow))

  func borrow*(a, b: uint32, borrow: bool): bool =
    var res {.noinit.}: cuint

    let borrow = builtinBorrowingSub(uint8(borrow), cuint(a), cuint(b), addr res)

    bool(borrow)

when cpu64Bit and cpuX86 and canUseIntrinsics:
  func builtinCarryingAdd*(
    carry: uint8, a, b: culonglong, res: ptr culonglong
  ): uint8 {.importc: "_addcarry_u64", x86_header.}

  func builtinBorrowingSub*(
    borrow: uint8, a, b: culonglong, res: ptr culonglong
  ): uint8 {.importc: "_subborrow_u64", x86_header.}

  {.push raises: [], inline, noinit, gcsafe.}

  func carryingAdd*(a, b: uint64, carry: bool): (uint64, bool) =
    var res {.noinit.}: uint64

    let carry = builtinCarryingAdd(
      uint8(carry), culonglong(a), culonglong(b), cast[ptr culonglong](addr res)
    )

    (res, bool(carry))

  func carry*(a, b: uint64, carry: bool): bool =
    var res {.noinit.}: culonglong

    let carry = builtinCarryingAdd(uint8(carry), culonglong(a), culonglong(b), addr res)

    bool(carry)

  func borrowingSub*(a, b: uint64, borrow: bool): (uint64, bool) =
    var res {.noinit.}: uint64

    let borrow = builtinBorrowingSub(
      uint8(borrow), culonglong(a), culonglong(b), cast[ptr culonglong](addr res)
    )

    (res, bool(borrow))

  func borrow*(a, b: uint64, borrow: bool): bool =
    var res {.noinit.}: culonglong

    let borrow =
      builtinBorrowingSub(uint8(borrow), culonglong(a), culonglong(b), addr res)

    bool(borrow)

when cpu64Bit and cpuX86 and compilerMsvc and canUseIntrinsics:
  func builtinWideningMul*(
    a, b: culonglong, hi: ptr culonglong
  ): uint64 {.importc: "_umul128", x86_header.}

  func builtinNarrowingDiv*(
    uHi, uLo, v: culonglong, r: ptr culonglong
  ): uint64 {.importc: "_udiv128", x86_header.}

  {.push raises: [], inline, noinit, gcsafe.}

  func wideningMul*(a, b: uint64): (uint64, uint64) =
    var hi {.noinit.}: uint64

    let lo =
      builtinWideningMul(culonglong(a), culonglong(b), cast[ptr culonglong](addr hi))

    (hi, lo)

  func wideningMulAdd*(a, b, c: uint64): (uint64, uint64) =
    var
      hi, lo {.noinit.}: uint64
      carry {.noinit.}: uint8

    lo = builtinWideningMul(culonglong(a), culonglong(b), cast[ptr culonglong](addr hi))
    carry = builtinAddCarry(
      0'u8, culonglong(lo), culongculong(c), cast[prt culonglong](addr lo)
    )
    discard builtinAddCarry(
      carry, culonglong(hi), culonglong(0), cast[ptr culonglong](addr hi)
    )

    (hi, lo)

  func wideningMulAdd*(a, b, c, d: uint64): (uint64, uint64) =
    var
      hi, lo {.noinit.}: uint64
      carry1 {.noinit.}: uint8
      carry2 {.noinit.}: uint8

    lo = builtinWideningMul(culonglong(a), culonglong(b), cast[ptr culonglong](addr hi))
    carry1 = builtinAddCarry(
      0'u8, culonglong(lo), culongculong(c), cast[prt culonglong](addr lo)
    )
    discard builtinAddCarry(
      carry1, culonglong(hi), culonglong(0), cast[ptr culonglong](addr hi)
    )
    carry2 = builtinAddCarry(
      0'u8, culonglong(lo), culongculong(d), cast[prt culonglong](addr lo)
    )
    discard builtinAddCarry(
      carry2, culonglong(hi), culonglong(0), cast[ptr culonglong](addr hi)
    )

    (hi, lo)

  func narrowingDiv*(uHi, uLo, v: uint64): (uint64, uint64) =
    var remainder {.noinit.}: uint64

    let quotient = builtinNarrowingDiv(
      culonglong(uHi),
      culonglong(uLo),
      culonglong(v),
      cast[ptr culonglong](addr remainder),
    )

    (quotient, remainder)
