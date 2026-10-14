mode = ScriptMode.Verbose

# Package

version = "1.0.8"
author = "Constantine Molchanov"
description = "Core arithmetic operations for CPU-sized integers."
license = "MIT or Apache License 2.0"
srcDir = "src"

# Dependencies

requires "nim >= 1.6.16", "unittest2 >= 0.3.0"

import std/[os, sequtils, strformat, parseopt, json]

let nimc = getEnv("NIMC", "nim") # Which nim compiler to use
let lang = getEnv("NIMLANG", "c") # Which backend (c/cpp/js)
let flags = getEnv("NIMFLAGS", "") # Extra flags for the compiler
let verbose = getEnv("V", "") notin ["", "0"]
let platform = getEnv("PLATFORM", "")
let testArguments = [
  "-d:intopsNoIntrinsics",
  "-d:intopsNoInlineAsm",
  "-d:intopsNoInlineC",
  "-d:unittest2Static",
  "-d:unittest2Static -d:intopsNoIntrinsics -d:intopsNoInlineAsm -d:intopsNoInlineC",
]

let cfg =
  " --styleCheck:usages --styleCheck:error" &
  (if verbose: "" else: " --verbosity:0") &
  " --skipParentCfg --skipUserCfg --outdir:build -f " &
  quoteShell("--nimcache:build/nimcache/$projectName")

proc build(args, path: string) =
  let archFlags =
    commandLineParams().filterIt(it.startsWith("--cpu") or it.startsWith("--gcc"))
  exec nimc & " " & lang & " " & cfg & " " & flags & " " & archFlags.join(" ") &
    " " & args & " " & path

proc run(args, path: string) =
  build args & " -r", path

task test, "Run tests":
  for args in testArguments:
    run args & " --mm:refc", "tests/tintops"
    run args & " --mm:orc", "tests/tintops"

task test_asan, "Run tests with ASAN":
  if platform != "x86":
    # https://clang.llvm.org/docs/AddressSanitizer.html
    putEnv("ASAN_OPTIONS", "detect_leaks=0:detect_stack_use_after_return=1")
    # https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html
    putEnv("UBSAN_OPTIONS", "print_stacktrace=1")
    let asanArgs =
      " --mm:orc -d:useMalloc --cc:clang --debugger:native" &
      " --passC:-fsanitize=address,undefined" &
      " --passL:-fsanitize=address,undefined" &
      " --passC:-fno-sanitize-recover=undefined" &
      " --passC:-fno-sanitize-merge" &
      " --passC:-fno-omit-frame-pointer"
    for args in testArguments:
      run args & asanArgs, "tests/tintops"

task bench, "Run benchmarks":
  var
    modNames: seq[string]
    benchKind = "all"
    afterCmdName: bool

  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      if afterCmdName:
        modNames.add(key)
      if key == "bench":
        afterCmdName = true
    of cmdLongOption, cmdShortOption:
      case key
      of "kind", "k":
        benchKind = val
    of cmdEnd:
      discard

  let
    archFlags =
      commandLineParams().filterIt(it.startsWith("--cpu") or it.startsWith("--gcc"))
    archFlagStr = archFlags.join(" ")
    optFlagStr = """-d:danger --passC:"-march=native -O3""""
    flags = fmt"{archFlagStr} {optFlagStr}"

  rmFile "results.csv"
  rmFile "results.json"

  echo fmt"# Flags: {flags}"

  if benchKind in ["all", "latency"]:
    for item in walkDir("benchmarks/latency"):
      if item.kind == pcFile and item.path.splitFile().ext == ".nim" and (
        len(modNames) > 0 and item.path.splitFile().name in modNames or
        len(modNames) == 0
      ):
        selfExec fmt"r {flags} {item.path}"

  if benchKind in ["all", "throughput"]:
    for item in walkDir("benchmarks/throughput"):
      if item.kind == pcFile and item.path.splitFile().ext == ".nim" and (
        len(modNames) > 0 and item.path.splitFile().name in modNames or
        len(modNames) == 0
      ):
        selfExec fmt"r {flags} {item.path}"

task bencher, "Generate results.json in Bencher Measurement Format (BMF)":
  var entries = newJObject()

  for line in readFile("results.csv").splitLines:
    if len(line) == 0:
      continue

    let
      components = line.split(",")
      entryKind = components[0]
      entryName = components[1] & "_" & components[2]
      entryVal = parseFloat(components[3])

    if entryName notin entries:
      entries.add(entryName, %*{})

    entries[entryName].add(entryKind, %*{"value": entryVal})

  writeFile("results.json", pretty entries)

  echo "Benchmark results saved to results.json."

task book, "Generate book":
  exec "mdbook build book -d docs"

task apidocs, "Generate API docs":
  exec "nimble doc --outdir:docs/apidocs --project --index:on --git.url:https://github.com/vacp2p/nim-intops --git.commit:develop src/intops.nim"

task docs, "Generate docs":
  exec "nimble book"
  exec "nimble apidocs"
