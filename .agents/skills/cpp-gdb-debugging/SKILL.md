---
name: "cpp-gdb-debugging"
description: "Workflow for debugging C++ segmentation faults and compilation errors using GDB, LLDB, and Clang/GCC output."
---

# C++ Debugging & Compilation Troubleshooting

This skill defines the workflow for analyzing build failures and runtime crashes (segfaults, SIGILL, etc.) in the Source Engine C++ codebase.

## 1. Compilation Errors (GCC/Clang/Icecc)
- **Always read the first error:** C++ template errors and macro expansions can produce thousands of lines of output. Always scroll to the very first `error:` in the compiler output.
- **Distributed Build Context:** When using `icecc -j 32`, errors from different translation units interleave. Grep for `error:` and identify the exact `.cpp` and line number before attempting a fix.
- **AVX/SIMD Errors:** If `_mm256_*` functions fail to compile, verify that the `-mavx2` flag is present in the `CMakeLists.txt` or `Makefile` for that specific translation unit.

## 2. Runtime Crashes (GDB / LLDB)
- **Automated Backtrace:** When a compiled tool (like `vrad` or `hammer`) crashes, do not guess the cause. Run it through GDB in batch mode:
  ```bash
  gdb --batch -ex "run" -ex "bt full" --args ./vrad -someflag mymap.vmf
  ```
- **Analyze Frames:** Inspect the `bt full` output to see local variables at the time of the crash.
- **Memory Corruption (Segfaults):** If the crash is deep inside `malloc` or `free`, it is a heap corruption. Use `valgrind --leak-check=full ./vrad` (if execution time permits) or `ASAN` (AddressSanitizer) by adding `-fsanitize=address` to the compiler flags.

## 3. AVX2 Specific Debugging
- **Alignment Faults:** `SIGSEGV` when using `_mm256_load_ps` or `_mm256_store_ps` usually means the pointer is not 32-byte aligned. Switch to `_mm256_loadu_ps` (unaligned) temporarily to confirm, then fix the memory allocator (`_aligned_malloc` or `posix_memalign`) to ensure 32-byte alignment.
- **Illegal Instruction (SIGILL):** Ensure the CPU actually supports AVX2 (`cat /proc/cpuinfo | grep avx2`). 
