# DexLoom Architecture

## Module Hierarchy

```
+=========================================================================+
|                         iOS Application                                  |
|                                                                          |
|  +---------------------------+    +----------------------------------+   |
|  |       SwiftUI Shell       |    |         Swift Bridge             |   |
|  |  Home | Runtime | Logs    |<-->|  RuntimeBridge.swift             |   |
|  |  (DexLoomApp.swift)       |    |  DxNetworkCallback (URLSession)  |   |
|  +---------------------------+    +----------------------------------+   |
|              ^                                  |                        |
|              | DxRenderModel                    | C function calls       |
|              | (UI snapshot)                    v                        |
+=========================================================================+
|                                                                          |
|                         C Runtime Core                                   |
|                                                                          |
|  +-------------------------------+                                       |
|  |         dx_context            |  Top-level lifecycle                  |
|  |  create / load_apk / run     |  Owns VM, DEX, APK, UI state         |
|  +-------------------------------+                                       |
|         |            |          |                                        |
|         v            v          v                                        |
|  +-----------+ +-----------+ +-------------------+                       |
|  | APK Parser| |DEX Parser | | Resource Parser   |                       |
|  | dx_apk.c  | | dx_dex.c  | | dx_resources.c    |                       |
|  | ZIP/DEFLATE| | Headers,  | | resources.arsc,   |                       |
|  | mmap, CRC | | tables,   | | string pools,     |                       |
|  | v2/v3 sig | | code items| | qualifier match   |                       |
|  +-----------+ +-----------+ +-------------------+                       |
|                     |                                                    |
|                     v                                                    |
|  +--------------------------------------------------------------+       |
|  |                  Virtual Machine (DxVM)                       |       |
|  |                                                               |       |
|  |  +------------------+  +------------------+  +-----------+   |       |
|  |  |   Interpreter    |  |  Class Loader    |  |    GC     |   |       |
|  |  |  computed goto   |  |  DEX + framework |  | mark-sweep|   |       |
|  |  |  256 opcodes     |  |  FNV-1a hash     |  | 64K heap  |   |       |
|  |  |  frame pooling   |  |  vtable + itable |  |           |   |       |
|  |  +------------------+  +------------------+  +-----------+   |       |
|  |                                                               |       |
|  |  +------------------+  +------------------+                   |       |
|  |  |  Bytecode        |  |  JNI Bridge      |                   |       |
|  |  |  Verifier        |  |  dx_jni.c        |                   |       |
|  |  |  two-pass        |  |  232-slot table   |                   |       |
|  |  +------------------+  +------------------+                   |       |
|  +--------------------------------------------------------------+       |
|                     |                                                    |
|                     v                                                    |
|  +--------------------------------------------------------------+       |
|  |            Android Framework (dx_android_framework.c)         |       |
|  |                                                               |       |
|  |  450+ classes: Activity, Fragment, View, TextView, Button,    |       |
|  |  RecyclerView, Intent, Bundle, SharedPreferences, LiveData,   |       |
|  |  ViewModel, Room, RxJava3, OkHttp3, Retrofit2, Glide,        |       |
|  |  String, HashMap, ArrayList, Collections, SQLiteDatabase ...  |       |
|  +--------------------------------------------------------------+       |
|                     |                                                    |
|                     v                                                    |
|  +--------------------------------------------------------------+       |
|  |              UI Bridge (dx_view.c / dx_layout.c)              |       |
|  |                                                               |       |
|  |  DxUINode tree <-- layout XML parsing (AXML)                  |       |
|  |  DxRenderModel --> serialized snapshot for Swift               |       |
|  |  30+ view types, ConstraintLayout, vector drawables,          |       |
|  |  Canvas draw commands, touch events, WebView                  |       |
|  +--------------------------------------------------------------+       |
|                                                                          |
+==========================================================================+
```

## Data Flow

```
  APK file (.apk)
       |
       v
  +------------------+
  | ZIP Extraction   |  dx_apk_open / dx_apk_open_file (mmap)
  | STORE + DEFLATE  |  ZIP bomb detection, path traversal check
  | CRC32 validation |  APK Signature v2/v3 detection
  +------------------+
       |
       +---> AndroidManifest.xml (binary XML) --> package name, main Activity
       +---> classes.dex (+ classes2.dex ...) --> DEX bytecode
       +---> resources.arsc                   --> string/layout resource tables
       +---> res/ (layouts, drawables)        --> binary XML, PNG, vectors
       |
       v
  +------------------+
  | DEX Parsing      |  dx_dex_parse
  | Header, string   |  Validates magic, checksum, offset bounds
  | IDs, type IDs,   |  Builds string pool, type/proto/field/method tables
  | proto IDs, field |  Extracts code items (registers, insns, try/catch)
  | IDs, method IDs, |  Parses debug_info_item for line number tables
  | class defs, code |
  +------------------+
       |
       v
  +------------------+
  | Class Loading    |  dx_vm_load_class / dx_vm_find_class
  | FNV-1a hash      |  Resolves superclass chain, interfaces
  | table (4096)     |  Computes vtable (inherited + own virtuals)
  | vtable + itable  |  Builds itable for interface dispatch
  +------------------+
       |
       v
  +------------------+
  | Bytecode         |  dx_vm_execute_method
  | Execution        |  Computed goto dispatch (256-entry label table)
  |                  |  Frame pooling (64-frame pool, no malloc per call)
  |                  |  Instruction budget watchdog (500K per invocation)
  |                  |  Wall-clock watchdog (10s default)
  +------------------+
       |
       v
  +------------------+
  | Framework Calls  |  Native method dispatch via DxNativeMethodFn
  | Activity life-   |  onCreate -> onStart -> onResume lifecycle
  | cycle, View ops, |  setContentView -> layout XML inflate -> UI tree
  | String/HashMap/  |  View.setText, onClick -> UI node update
  | networking ...   |  OkHttp/HttpURLConnection -> URLSession bridge
  +------------------+
       |
       v
  +------------------+
  | UI Rendering     |  dx_render_model_create
  | DxUINode tree -> |  Serializes UI tree to DxRenderModel snapshot
  | DxRenderModel -> |  Passed to Swift via on_ui_update callback
  | SwiftUI views    |  SwiftUI reads RenderNode tree, builds native views
  +------------------+
```

## Key Data Structures

### DxContext

Top-level runtime container. Created once per APK session.

- Owns `DxVM`, `DxDexFile`, `DxApkFile`, `DxUINode` root, `DxRenderModel`
- Stores parsed resources, layout buffers, string resources
- Holds the `on_ui_update` callback for Swift bridge communication
- Tracks device configuration for resource qualifier matching
- Manages application theme resolution

Defined in: `DexLoom/Core/Include/dx_context.h`

### DxVM

Virtual machine state. One instance per context.

- **Class table:** Up to 2048 classes in `classes[]` array, with FNV-1a hash
  table (`class_hash[4096]`) for O(1) lookup via `dx_vm_find_class`
- **Heap:** Fixed-size array of 64K `DxObject*` pointers, managed by mark-sweep GC
- **Call stack:** Linked list of `DxFrame` via `caller` pointers, depth limit 128
- **Frame pool:** 64 pre-allocated frames to avoid malloc/free per method call
- **String intern table:** 8192-slot table for string deduplication
- **Activity back-stack:** 16-deep stack for `startActivityForResult` / `finish`
- **Debug/diagnostics:** Bytecode tracing, class load tracing, method call
  tracing, register snapshots on error, formatted stack traces

Defined in: `DexLoom/Core/Include/dx_vm.h`

### DxDexFile

Parsed DEX file. Multiple DEX files supported (up to 8 per VM).

- Raw byte buffer, header, and parsed index tables (string IDs, type IDs,
  proto IDs, field IDs, method IDs, class defs)
- Decoded string pool for fast lookup
- Code items with register counts, instruction arrays, try/catch handlers
- Line number tables parsed from `debug_info_item`

Defined in: `DexLoom/Core/Include/dx_dex.h`

### DxClass

Runtime class representation loaded from DEX or registered by framework.

- Descriptor string (e.g., `"Lcom/example/Main;"`)
- Superclass pointer, interface list
- Field definitions with precomputed slot indices, static field value array
- Direct methods (static + constructors) and virtual methods
- Flattened vtable for virtual dispatch, itable for interface dispatch
- Annotations with element values
- `is_framework` flag distinguishes built-in stubs from DEX-loaded classes

Defined in: `DexLoom/Core/Include/dx_vm.h`

### DxMethod

Runtime method representation.

- Name, shorty descriptor, declaring class, access flags
- Bytecode (`DxDexCodeItem`) for interpreted methods
- Native function pointer (`DxNativeMethodFn`) for framework stubs
- Verification flag (set after bytecode passes structural verification)
- VTable index for virtual dispatch (-1 if not virtual)
- Annotations

Defined in: `DexLoom/Core/Include/dx_vm.h`

### DxObject

Runtime object instance on the VM heap.

- Class pointer (`klass`)
- Instance field values array (`fields[]`)
- GC metadata: `gc_mark` flag, `heap_idx`
- Optional array storage: `is_array`, `array_length`, `array_elements[]`
- Optional UI node link for View objects

Defined in: `DexLoom/Core/Include/dx_vm.h`

### DxUINode

Internal UI tree node representing an Android View.

- View type (30+ types: LinearLayout, TextView, Button, RecyclerView, etc.)
- Layout attributes: dimensions, weight, gravity, padding, margin, colors
- Specialized data: image bytes, vector drawable paths, WebView URLs
- ConstraintLayout constraint anchors and bias values
- Click/long-click/touch/refresh listener references
- Canvas draw command buffer
- Tree structure: parent, children array

Defined in: `DexLoom/Core/Include/dx_view.h`

### DxRenderModel

Serialized UI snapshot consumed by the Swift bridge.

- `DxRenderNode` tree mirroring `DxUINode` but with owned copies of data
- Version counter incremented on each update
- Passed to Swift via `on_ui_update` callback

Defined in: `DexLoom/Core/Include/dx_view.h`

## Threading Model

DexLoom is **single-threaded cooperative**. All execution happens on the calling
thread:

1. Swift bridge calls `dx_context_run` or `dx_runtime_dispatch_click`
2. C runtime executes bytecode synchronously in the interpreter loop
3. Framework native methods execute inline (same call stack)
4. Network requests (OkHttp, HttpURLConnection) bridge to Swift's URLSession
   via `DxNetworkCallback`, using `DispatchSemaphore` to block the calling
   thread until the response arrives
5. UI updates are batched: the render model is rebuilt and delivered via
   callback when control returns to the bridge

Monitor operations (`monitorenter`, `monitorexit`) are no-ops. The JNI
`MonitorEnter`/`MonitorExit` functions return success without locking.

### Execution Safeguards

- **Instruction budget:** 500,000 instructions per top-level invocation
  (`DX_MAX_INSTRUCTIONS`). Prevents infinite loops from freezing the app.
- **Wall-clock watchdog:** Configurable timeout (default 10 seconds) using
  `mach_absolute_time`. Triggers `DX_ERR_BUDGET_EXHAUSTED`.
- **Stack depth limit:** 128 frames (`DX_MAX_STACK_DEPTH`). Returns
  `DX_ERR_STACK_OVERFLOW` on deep recursion.
- **Crash isolation:** SIGSEGV/SIGBUS signal handlers with `sigsetjmp`/
  `siglongjmp` recover from null dereferences in native framework code.

## Memory Management

### Garbage Collection

DexLoom uses a **mark-sweep** garbage collector:

- **Heap:** Fixed 64K-slot object array (`DX_MAX_HEAP_OBJECTS = 65536`)
- **Mark phase:** Traces from roots (call stack registers, static fields,
  activity stack, string intern table, UI node references)
- **Sweep phase:** Frees unmarked objects and compacts the heap array
- **Triggered:** Automatically when heap is full, or manually via
  `dx_vm_gc_collect`

### Frame Pooling

The interpreter maintains a pool of 64 pre-allocated `DxFrame` structures
(`DX_FRAME_POOL_SIZE = 64`). `dx_vm_alloc_frame` draws from the pool;
`dx_vm_free_frame` returns frames to it. This eliminates malloc/free overhead
for the vast majority of method calls.

### String Interning

Strings created via `dx_vm_intern_string` are stored in an 8192-slot intern
table (`DX_MAX_INTERNED_STRINGS`). Duplicate strings share the same `DxObject`,
reducing heap pressure for common string values.

### APK Memory Mapping

APK files are opened via `mmap` (`dx_apk_open_file`) for zero-copy access.
Individual entries are extracted on demand, with DEFLATE decompression backed
by zlib.

## Source Layout

```
DexLoom/
  Core/
    Include/         Header files (dx_types.h, dx_vm.h, dx_apk.h, dx_dex.h, ...)
    Base/            Foundation utilities (logging, memory allocation)
    APK/             APK/ZIP parser, AXML binary XML decoder
    DEX/             DEX file parser (header, tables, code items, debug info)
    VM/              Interpreter, class loader, GC, JNI bridge, bytecode verifier
    AndroidMini/     Android framework class stubs (450+ classes)
    UIBridge/        UI tree, layout XML parser, render model serialization
    Runtime/         Top-level runtime API (init, load, run, event dispatch)
  Bridge/            Swift-to-C bridge (RuntimeBridge.swift)
  App/               SwiftUI app entry point and navigation
  UI/                SwiftUI views (Home, Runtime, Logs tabs)
  Support/           Bridging header, Info.plist
  Test_APK/          Sample APK files for testing
DexLoomTests/        Swift Testing framework tests
Docs/                Documentation
Tools/               Build and development utilities
```
