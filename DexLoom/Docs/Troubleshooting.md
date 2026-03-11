# DexLoom Troubleshooting Guide

This document covers common APK failure patterns, their root causes, and how to
diagnose issues using DexLoom's built-in tracing and diagnostics.

---

## Common Error Patterns

### "Class not found" (DX_ERR_CLASS_NOT_FOUND)

**Symptom:** The log shows a message like `Class not found: Lcom/example/SomeClass;`
and execution stops.

**Cause:** The VM's class loader could not find the requested class. This happens
when:

1. **Missing framework class registration.** The APK uses an Android framework
   class that DexLoom has not implemented. DexLoom provides 450+ framework class
   stubs, but niche classes may be missing.
2. **Multi-DEX class not loaded.** The class is in `classes2.dex` or later, and
   the additional DEX files were not loaded. DexLoom supports up to 8 DEX files
   per VM.
3. **Obfuscated or renamed class.** ProGuard/R8 may have renamed the class. The
   descriptor in the error message will show the obfuscated name (e.g.,
   `La/b/c;`).
4. **Class hash table miss.** If a framework class was added to the `classes[]`
   array but `dx_vm_class_hash_insert(vm, cls)` was not called after, it will
   be invisible to `dx_vm_find_class` (which uses the FNV-1a hash table, not a
   linear scan).

**Resolution:**
- Check the Logs tab for the exact class descriptor that was not found.
- Search the framework registration code (`dx_android_framework.c`) for the
  class. If missing, it needs to be added with `reg_class()` followed by the
  required hash table insert.
- Enable class load tracing to see which classes load successfully (see Debug
  Tracing below).

---

### "Method not found" (DX_ERR_METHOD_NOT_FOUND)

**Symptom:** Log shows `Method not found: Lcom/example/Foo;.someMethod` and
execution stops.

**Cause:** The class was found, but the specific method was not resolved. This
happens when:

1. **Unimplemented native method.** The framework class stub exists but does not
   define the particular method. For example, a framework stub for `Activity`
   might lack a less-common method like `getCallingActivity()`.
2. **Signature mismatch.** Method resolution uses name matching (and optionally
   shorty matching). If the DEX method has a different shorty than the framework
   stub, it will not match.
3. **Interface method not in itable.** For `invoke-interface`, the method is
   looked up in the itable. If the class does not declare that it implements the
   interface, the itable lookup fails.

**Resolution:**
- Check which class owns the method and whether the framework stub defines it.
- Enable method call tracing to see the resolution path.
- If the method is missing from a framework class, add a native method
  implementation to `dx_android_framework.c`.

---

### "Null pointer" / NullPointerException

**Symptom:** A `NullPointerException` is thrown during execution, or the
interpreter encounters a null object reference where one was not expected.

**Cause:** Common scenarios include:

1. **Uninitialized fields.** A constructor (`<init>`) did not set a field, or
   the constructor was not called at all. Framework stub constructors may not
   initialize all fields that the DEX code expects.
2. **Missing constructor dispatch.** `new-instance` allocates the object, but if
   the subsequent `invoke-direct <init>` fails (e.g., because the constructor is
   not found), the object's fields remain zeroed.
3. **Framework method returning null.** A framework stub method returns NULL
   where the real Android implementation would return a valid object (e.g.,
   `getSystemService` for an unimplemented service).
4. **Unboxing null.** Code like `Integer.intValue()` on a null reference.

**Resolution:**
- Check the crash report (see Reading the Crash Report below) for the exact
  instruction and register state.
- Look at the register that held the null reference and trace backward to find
  where it was assigned.
- If a framework method is returning null unexpectedly, add or fix its native
  implementation.

---

### "Stack overflow" (DX_ERR_STACK_OVERFLOW)

**Symptom:** Execution aborts with `DX_ERR_STACK_OVERFLOW` after reaching 128
frames deep.

**Cause:**

1. **Infinite recursion.** A method calls itself (directly or indirectly)
   without a base case, or the base case is never reached due to incorrect
   framework behavior.
2. **Mutual recursion.** Two or more methods call each other in a cycle (e.g.,
   `toString()` calling `valueOf()` calling `toString()`).
3. **Deep but legitimate call chains.** Some Android patterns (e.g., deep View
   hierarchy inflation) can produce long call chains. The 128-frame limit is
   intentionally conservative.

**Resolution:**
- Enable method call tracing to see the call chain leading to the overflow.
- Look for repeated method names in the stack trace to identify the recursive
  cycle.
- If the recursion is caused by a framework stub calling back into itself, fix
  the stub to break the cycle.

---

### "Instruction budget exceeded" (DX_ERR_BUDGET_EXHAUSTED)

**Symptom:** Execution stops with `DX_ERR_BUDGET_EXHAUSTED` after running for
500,000 instructions or exceeding the wall-clock timeout (default 10 seconds).

**Cause:**

1. **Infinite loop.** A `while(true)` or `for(;;)` loop without a reachable
   exit condition. Common in event-loop patterns that expect to be broken by an
   external signal.
2. **Very long computation.** Legitimate but expensive operations (e.g., large
   collection sorting, complex string processing) can exceed the budget.
3. **Busy-wait pattern.** Code that polls a condition in a tight loop (e.g.,
   `Thread.sleep` is a no-op in DexLoom, so busy-waits never yield).

**Resolution:**
- Enable bytecode tracing (filtered to the suspected method) to see which
  instructions are executing repeatedly.
- Check for loops whose exit condition depends on threading (which DexLoom does
  not support) or system state that is not simulated.
- The instruction budget can be adjusted via `vm->insn_limit` if the computation
  is legitimate.

---

### "Unsupported opcode" (DX_ERR_UNSUPPORTED_OPCODE)

**Symptom:** Log shows `Unsupported opcode 0xNN`.

**Cause:** This error should not occur in normal operation. DexLoom implements
all 256 Dalvik opcodes. If it appears:

1. **Corrupt DEX data.** The bytecode stream is damaged, causing the interpreter
   to read a data word as an opcode.
2. **Misaligned program counter.** A bug in branch target calculation caused the
   PC to land in the middle of an instruction.
3. **Invalid DEX version.** A future DEX format version might introduce new
   opcodes.

**Resolution:**
- Check the DEX file version in the header (supported: 035, 037, 038, 039).
- Enable bytecode tracing to see the instruction stream leading up to the error.
- Verify the DEX file is not corrupted (check CRC32 and SHA-1 signature).

---

### "JNI: Cannot load .so" / Native Library Errors

**Symptom:** The app attempts to call `System.loadLibrary()` or load a native
`.so` file from the APK.

**Cause:** DexLoom cannot execute native ARM/ARM64 code from `.so` files. iOS
does not allow `dlopen` of arbitrary shared libraries. The JNI bridge provides
a `JNIEnv` for DEX-side JNI calls, but the native library itself cannot be
loaded.

**Impact:** Any functionality implemented in native code (C/C++ via NDK) will
not work. This includes:

- Performance-critical code compiled to native
- Crypto/media libraries
- Game engines (Unity, Unreal native layers)
- SQLCipher or similar native database extensions

**Resolution:**
- This is a fundamental limitation. The `System.loadLibrary` call is intercepted
  and logged as a warning but does not crash execution.
- If the app has a fallback Java implementation, it may still work.
- Check the Missing Features report (Logs tab) to see which libraries were
  requested.

---

### "Compose app detected" / Jetpack Compose Not Supported

**Symptom:** The app's DEX code references `androidx.compose.*` classes and
fails during class loading or method invocation.

**Cause:** Jetpack Compose requires the Compose compiler plugin and runtime,
which transform `@Composable` functions into a state-driven rendering tree at
compile time. DexLoom cannot replicate this transformation:

- Compose uses a custom slot table and recomposition system
- The compiler plugin generates synthetic code that depends on the Compose
  runtime internals
- Compose UI does not use `View` / `ViewGroup` at all

**Impact:** Compose-only apps will fail entirely. Apps that mix Compose and
traditional Views will fail on Compose screens but may work on View-based
screens.

**Resolution:**
- This is a fundamental limitation. There is no workaround.
- DexLoom reports Compose detection in the Missing Features list.
- Only traditional View-based Android apps are supported.

---

### "Verification failed" (DX_ERR_VERIFICATION_FAILED)

**Symptom:** A method fails the bytecode verifier before execution begins.

**Cause:** The two-pass structural verifier detected an issue:

1. **Instruction boundary violation.** An instruction's encoded width extends
   past the end of the code array, or a branch target lands in the middle of an
   instruction.
2. **Invalid register index.** An instruction references a register number
   greater than or equal to the method's `registers_size`.
3. **Invalid table index.** A string, type, field, or method index exceeds the
   DEX file's table size.
4. **Unreachable code after unconditional branch.** While not always an error,
   certain patterns indicate corruption.

**Resolution:**
- Check the error detail in `vm->error_msg` for the specific verification
  failure.
- The method name and bytecode offset are included in the diagnostic info.
- Verification failures usually indicate a malformed or deliberately obfuscated
  DEX file.

---

### "Signal recovered" (DX_ERR_SIGNAL)

**Symptom:** The log shows `Recovered from signal N (SIGSEGV/SIGBUS)`.

**Cause:** DexLoom's crash isolation handlers caught a fatal signal during
execution. The `sigsetjmp`/`siglongjmp` mechanism recovered to a safe point
instead of crashing the app.

**Common triggers:**
- Dereferencing a wild pointer in framework native code
- Array bounds violation in C-level array access
- Stack corruption from deep recursion

**Resolution:**
- The crash report (see below) contains the signal number and the method that
  was executing when the signal occurred.
- This is a safety net, not normal behavior. It typically indicates a bug in
  DexLoom's C code rather than in the APK.

---

## Debug Tracing

DexLoom provides three tracing modes, configurable via the VM's debug struct
or the `dx_vm_set_trace` API:

### Bytecode Trace

```c
dx_vm_set_trace(vm, true, false, false);  // bytecode only
```

Logs every instruction as it executes:

```
[TRACE] VM: 0012: invoke-virtual {v0, v1} @method_idx=42
[TRACE] VM: 0016: move-result-object v2
[TRACE] VM: 0018: if-eqz v2, +0008
```

**Warning:** Extremely verbose. Use the trace filter to limit output to a
specific method.

### Class Load Trace

```c
dx_vm_set_trace(vm, false, true, false);  // class load only
```

Logs each class as it is loaded and initialized:

```
[TRACE] VM: Loading class: Lcom/example/MainActivity;
[TRACE] VM: Class loaded: Lcom/example/MainActivity; (super: Landroidx/appcompat/app/AppCompatActivity;)
[TRACE] VM: Initializing class: Lcom/example/MainActivity; (<clinit>)
```

### Method Call Trace

```c
dx_vm_set_trace(vm, false, false, true);  // method calls only
```

Logs method entry and exit with indentation showing call depth:

```
[TRACE] VM:   -> Lcom/example/MainActivity;.onCreate(Landroid/os/Bundle;)V
[TRACE] VM:     -> Landroidx/appcompat/app/AppCompatActivity;.onCreate(Landroid/os/Bundle;)V
[TRACE] VM:     <- Landroidx/appcompat/app/AppCompatActivity;.onCreate (void)
[TRACE] VM:     -> Lcom/example/MainActivity;.setContentView(I)V
[TRACE] VM:     <- Lcom/example/MainActivity;.setContentView (void)
[TRACE] VM:   <- Lcom/example/MainActivity;.onCreate (void)
```

### Trace Filter

To limit tracing output to methods matching a prefix:

```c
dx_vm_set_trace_filter(vm, "Lcom/example/");  // only trace app classes
dx_vm_set_trace_filter(vm, NULL);              // trace everything
```

The filter applies a prefix match on the method's `declaring_class->descriptor`.

---

## Reading the Crash Report

When an error occurs during execution, DexLoom captures diagnostic information
in `vm->diag`. This includes:

### Error Location

```
Method:  Lcom/example/MainActivity;.processData
PC:      0x002A
Opcode:  0x6E (invoke-virtual)
```

- **Method:** The fully qualified method where the error occurred.
- **PC:** The program counter (byte offset) within the method's instruction
  array, in 16-bit code units.
- **Opcode:** The instruction that triggered the error, with its human-readable
  name.

### Register Snapshot

```
Registers (first 16):
  v0 = OBJ  0x1a2b3c40 (Ljava/lang/String;)
  v1 = INT  42
  v2 = OBJ  NULL
  v3 = LONG 1000000
  ...
```

The first 16 registers are captured at the point of failure. This lets you see
what values were live when the error occurred.

### Stack Trace

```
Stack trace:
  at Lcom/example/MainActivity;.processData (PC=0x002A)
  at Lcom/example/MainActivity;.onClick (PC=0x0014)
  at Landroid/view/View;.performClick (native)
```

The full call chain from the error point back to the entry frame. Native
framework methods show `(native)` instead of a PC value.

### Accessing Diagnostics

From Swift:

```swift
if let detail = dx_vm_get_last_error_detail(vm) {
    let message = String(cString: detail)
    // Display in Logs tab
}
```

From C:

```c
if (vm->diag.has_error) {
    printf("Error in %s at PC=%u, opcode=%s\n",
           vm->diag.method_name,
           vm->diag.pc,
           vm->diag.opcode_name);
    printf("%s\n", vm->diag.stack_trace);
}
```

### Heap Statistics

To check memory pressure when diagnosing performance or OOM issues:

```c
char *stats = dx_vm_heap_stats(vm);
// Example output: "Heap: 1234/65536 objects, 45 classes, 890 interned strings"
free(stats);
```

### Missing Feature Report

When the VM encounters unsupported functionality, it records it silently rather
than crashing:

```c
const char *missing = dx_vm_get_missing_features(vm);
// Example: "System.loadLibrary(crypto), androidx.compose.runtime.Composable"
```

This is displayed in the Logs tab and helps identify why an APK is not working
correctly.

---

## Quick Diagnosis Flowchart

```
APK fails to run
       |
       v
 Check Logs tab for first error
       |
       +-- "Class not found"
       |       |
       |       +-- Framework class? --> Add to dx_android_framework.c
       |       +-- App class?       --> Check multi-DEX loading
       |
       +-- "Method not found"
       |       |
       |       +-- Enable method call trace, check framework stub
       |
       +-- NullPointerException
       |       |
       |       +-- Check crash report registers, trace backward
       |
       +-- "Stack overflow"
       |       |
       |       +-- Enable method call trace, look for recursion cycle
       |
       +-- "Budget exhausted"
       |       |
       |       +-- Enable bytecode trace with filter on suspected method
       |
       +-- "Cannot load .so"
       |       |
       |       +-- Fundamental limitation, check for Java fallback
       |
       +-- "Compose detected"
       |       |
       |       +-- Fundamental limitation, app not supported
       |
       +-- "Verification failed"
       |       |
       |       +-- Likely corrupt/obfuscated DEX, check error detail
       |
       +-- "Signal recovered"
               |
               +-- Bug in DexLoom C code, check crash report
```
