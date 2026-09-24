# Quickstart

intops is a Nim library that implements multi-precision arithmetic operations for integers. Unlike Nim's stdlib, intops offers multiple flavors for each operations and multiple implementations of each flavors. On top of that, intops chooses the best implementation for each OS, CPU architecture, and C compiler combo.

intops is designed for Nim developers working on bigint-related projects, e.g. crypto libraries.

- [Repository →](https://github.com/iftech/nim-intops)
- [API Index →](apidocs/theindex.html)
- [Issues →](https://github.com/iftech/nim-intops/issues)
- [Contributor's Guide →](contrib.html)
- [Benchmark Stats →](https://bencher.dev/console/projects/nim-intops/perf)

## What's included in the package

intops implements the following operations for signed and unsigned 32- and 64-bit integers:

|             | addition             | subtraction          | multiplication     | division             | muladd             |
| ----------- | -------------------- | -------------------- | ------------------ | -------------------- | ------------------ |
| overflowing | Nim, intrinsics      | Nim, intrinsics      |                    |                      |                    |
| saturating  | Nim, intrinsics, ASM | Nim, intrinsics, ASM |                    |                      |                    |
| carrying    | Nim, intrinsics, C   |                      |                    |                      |                    |
| borrowing   |                      | Nim, intrinsics, C   |                    |                      |                    |
| widening    |                      |                      | Nim, intrinsics, C |                      | Nim, intrinsics, C |
| narrowing   |                      |                      |                    | Nim, intrinsics, ASM |                    |

_Overflowing_ operations return an explicit `didOverflow` bool flag that tells you if an overflow happened during the operation. These operations wrap for both signed and unsigned integers.

_Saturating_ operations do not return an overflow flag but silently return the highest or the lowest available value for a given type if an overflow is to occur.

_Carrying_ and _borrowing_ operations accept two operands and a flag that determines if an overflow happened earlier and should be taken into account. These operations return the new flag value along with the calculated result.

_Widening_ operations accept two single-word operands and return a two-word results, i.e. widen the resulting type compared to the input type.

_Narrowing_ operations do the opposite: accepting a two-word operand, they return a single-word result.

Additionally, intops ships with composite operations that purely combine other primitives to offer convenience operations for cryptography calculations:

- Square and accumulate (mulDoubleAdd2)
- Column accumulator for Comba multiplication (mulAcc)

## Installation

```shell
$ nimble install -y intops
```

Add intops to your .nimble file:

```nim
requires "intops"
```

## Usage

The most straightforward way to use intops is by importing `intops` and calling the operations from it:

```nim
import intops

echo carryingAdd(12'u64, 34'u64, false)
```

Output:

```nim
(res: 46, carry: false)
```

`intops.carryingAdd` is a _dispatcher_. When invoked, it calls the best implementation of this operation out of the available ones for the given environment.

Notice that we call `carryingAdd` with `uint64` type set explicitly. This is important because `int` can mean different things under different circumstances and so intops doesn't allow this kind of ambiguity.

If you try to call `carryingAdd` with an `int`, your code simply won't compile:

```nim
echo not compiles carryingAdd(12, 34, false)
```

Output:

```nim
true
```

All available dispatchers are listed in the [Imports section of the API docs for intops module](apidocs/intops.html#6).

The operations are grouped into families, each one living in a separate submodule. For example, `carryingAdd` operation mentioned above is imported from `intops/ops/add` submodule, so this is where you find its documentation: [/apidocs/intops/ops/add.html](apidocs/intops/ops/add.html#carryingAdd.t%2Cuint64%2Cuint64%2Cbool).

### Calling Specific Operations

`import intops` imports all available operations.

If you only need specific operations, you can import them individually:

```nim
import intops/ops/[add, sub]

echo compiles carryingAdd(12'u64, 34'u64, false)
echo not compiles wideningMul(12'u64, 34'u64)
```

Output:

```nim
true
true
```

### Composite Operations

On top of the primitive operations like addition and multiplication, intops offers convenience operations that combine several primitives as a single composite operation:

```nim
import intops/ops/composite

echo mulDoubleAdd2(12'u64, 34'u64, 45'u64, 78'u64, 90'u64)
```

Output:

```nim
(t2: 0, r1: 78, r0: 951)
```

Read more in the API docs for [composite module](/apidocs/intops/ops/composite.html).

### Calling Specific Implementations

You may want to override the dispatcher's choice. To do that, import a particular implementation from `intops/impl` directly and call the function from it:

```nim
import intops/impl/intrinsics

echo intrinsics.gcc.carryingAdd(12'u64, 34'u64, false)
```

Output:

```nim
(46, false)
```

Implementations are also grouped into families: pure Nim, C intrinsics, inline C, and inline Assembly. Each family can be further split into subgroups.

For example, the `carryingAdd` implementation above is based on C intrinsics that are specific to GCC/Clang. All such implementations live in [`intops/impl/intrinsics/gcc`](apidocs/intops/impl/intrinsics/gcc.html). There's also a subgroup that provides an implementation based on Intel/AMD specific C intrinsics—[`intops/impl/intrinsics/x86`](apidocs/intops/impl/intrinsics/x86.html).

To see all available implementations for a particular operation, find it in the [API index](apidocs/theindex.html#carryingAdd).

#### Caveat

When you use a dispatcher, you can be sure that your code will compile in any environment. It is the dispatcher's job to provide a code path for any case, so you don't have to worry about it.

But if you choose to call an implementation manually, it is your job to validate that this implementation is available in the environment you're using it in. If you attempt to use an implementation that is unavailable, you'll get a compile-time error.

For example, trying to use an Inline Assembly implementation with `intopsNoInlineAsm` flag (more on those in the section below) will cause a compilation error:

```nim
import intops/impl/inlineasm

echo not compiles inlineasm.x86.carryingAdd(12'u64, 34'u64, false)
```

If compiled with `-d:intopsNoInlineAsm`, this outputs:

```nim
true
```

## Compilation Flags

You can control which implementations are forbidden to be picked by dispatchers using the compilation flags:

- `intopsNoIntrinsics`
- `intopsNoInlineAsm`
- `intopsNoInlineC`

For example, to avoid using Inline Assembly implementations, compile your code with `-d:intopsNoInlineAsm`:

```shell
$ nim c -d:intopsNoInlineAsm mycode.nim
```

Of course, you can combine those flags. For example, if you want to use only pure Nim implementations, pass all three forbidding flags:

```shell
$ nim c -d:intopsNoIntrinsics -d:intopsNoInlineAsm -d:intopsNoInlineC mycode.nim
```
