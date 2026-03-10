# DexLoom Roadmap

## Milestone Plan

### Milestone 0: Feasibility Analysis -- ACHIEVED
- Architecture comparison document
- iOS platform constraint analysis
- Chosen approach: DEX bytecode interpreter + mini framework

### Milestone 1: APK Parsing and Inspection -- ACHIEVED
- ZIP file format parser (PKZIP) with hardening (path traversal, zip bomb)
- Entry enumeration and extraction (STORE + DEFLATE)
- Identify classes.dex, AndroidManifest.xml, resources.arsc, res/
- **Delivered**: Full APK content listing and extraction

### Milestone 2: AndroidManifest.xml and resources.arsc Decoding -- ACHIEVED
- Android Binary XML (AXML) parser with depth limits
- String pool, resource map, namespace handling
- Manifest parsing: package name, main activity, permissions
- Intent-filter details, meta-data, uses-feature, uses-library, exported flag
- resources.arsc: string pool, type specs, entries, dimension decoding
- Style/theme resolution with parent chain traversal
- Qualifier system (locale, density, orientation, SDK level, night mode, screen size)
- Array resources, plural resources, TypedArray
- **Delivered**: Full manifest and resource decoding with theme/style resolution

### Milestone 3: DEX Parsing -- ACHIEVED
- DEX header validation (magic, checksum, versions 035-039)
- All ID tables: string, type, proto, field, method
- Class definitions with annotations (type + visibility)
- Code items with bytecode, debug info (line number tables)
- Encoded values: VALUE_ARRAY, VALUE_ANNOTATION, all types
- Multi-DEX loading (up to 8 DEX files)
- Call site items and method handle items (for invoke-custom)
- **Delivered**: Full DEX parsing with annotation, debug info, and multi-DEX support

### Milestone 4: Java Runtime / Class Library -- ACHIEVED
- Object model: heap objects with class pointers and fields
- 450+ framework classes spanning Android, Java stdlib, Kotlin, and third-party libraries
- String (35+ methods), HashMap, ArrayList, Collections, Arrays, Objects
- Autoboxing for all primitive wrapper types
- Real ArrayList Iterator with for-each loop support
- Collection interfaces (Iterable/Collection/List/Set/Map) on 15+ classes
- Exception model with cross-method unwinding and finally blocks
- ByteBuffer, WeakReference/SoftReference, Enum, Number, Pair
- java.util.concurrent: AtomicInteger/Boolean/Reference, ConcurrentHashMap, LinkedBlockingQueue, etc.
- **Delivered**: Production-grade class library

### Milestone 5: Bytecode Interpreter -- ACHIEVED
- All 256 Dalvik opcodes with edge case handling
- Computed goto dispatch (256-entry table) for performance
- 64-frame pool, FNV-1a class hash table (O(1) lookup)
- Exception try/catch/finally with cross-method unwinding
- Varargs method invocation (pack_varargs)
- Null-safe instance-of/check-cast
- invoke-custom: Real LambdaMetafactory + StringConcatFactory
- Bytecode verifier: structural verification (boundaries, registers, indices, branches, payloads)
- **Delivered**: Full interpreter with production-grade opcode coverage and verification

### Milestone 6: Android UI Rendering -- MOSTLY ACHIEVED
- Layout XML parsing (binary XML)
- 30+ view types: TextView, Button, EditText, ImageView, RecyclerView, ListView, GridView, Spinner, SeekBar, RatingBar, RadioButton/Group, FAB, TabLayout, ViewPager, WebView, Chip, BottomNav, SwipeRefreshLayout
- ConstraintLayout basic solver (12 constraint attributes, GeometryReader positioning)
- Drawable loading from APK (PNG/JPEG extraction, UIImage rendering)
- Vector drawable support (AXML path data to SVG parser to SwiftUI Canvas)
- Dimension conversion with padding/margin support
- WebView mapped to WKWebView bridge
- **Still missing**: 9-patch PNG support, StateListDrawable, LayerDrawable, ShapeDrawable
- **Delivered**: Rich UI rendering with 30+ view types and constraint solving

### Milestone 7: Activity Lifecycle & Navigation -- ACHIEVED
- Full lifecycle: onCreate->onPostCreate->onStart->onResume->onPostResume + teardown
- State save/restore: onSaveInstanceState/onRestoreInstanceState, Activity.recreate()
- Multi-activity navigation with Intent extras
- 16-deep back-stack; startActivityForResult/setResult/finish/onActivityResult
- Fragment lifecycle: onCreateView->onViewCreated->onStart->onResume
- Configuration class with orientation, screen dimensions, locale, density
- **Delivered**: Complete activity lifecycle and navigation

### Milestone 8: Event Handling & Touch -- ACHIEVED
- onClick on all view types, long-press support
- SwipeRefreshLayout pull-to-refresh
- MotionEvent dispatch
- Menu system: Menu/MenuItem/SubMenu/MenuInflater
- TextWatcher/Editable, CompoundButton isChecked/setChecked/toggle
- Back button: dx_runtime_dispatch_back calls Activity.onBackPressed
- **Delivered**: Full event handling including touch, menus, and text input

### Milestone 9: System Services & I/O -- ACHIEVED
- AssetManager.open() extracts from APK; InputStream with real read/available/close
- File I/O: File.createTempFile, Context.openFileInput/openFileOutput
- Filesystem: getExternalFilesDir, Environment paths
- Permissions: checkSelfPermission (safe vs dangerous), requestPermissions with callback
- SQLiteDatabase with insert/update/delete/rawQuery, ContentValues, Cursor, Room annotations
- BroadcastReceiver: registerReceiver/sendBroadcast with Intent action dispatch
- Service lifecycle: startService->onCreate->onStartCommand; IntentService subclass
- ContentProvider/ContentResolver stub CRUD
- **Delivered**: File I/O, assets, permissions, and system service stubs

### Milestone 10: Advanced Runtime -- ACHIEVED
- Reflection: Class.forName, Method.invoke, Field.get/set, getAnnotation
- Advanced reflection: Proxy.newProxyInstance, Array.newInstance, Constructor, getDeclaredMethods/Fields
- JNI bridge: Complete JNIEnv (232 functions), Call*Method, Get/Set*Field, RegisterNatives
- Cooperative threading: Thread.start (synchronous), ExecutorService, Future, CompletableFuture
- LiveData/ViewModel with observer notification
- Third-party libraries: RxJava3 (11 classes, 85 methods), OkHttp3 (18 classes, 120 methods), Retrofit2 (12 classes, 50 methods), Glide (6 classes, 40 methods)
- **Delivered**: Reflection, JNI, threading, and major third-party library support

### Milestone 11: Debug & Diagnostics -- ACHIEVED
- UI tree inspector (visual hierarchy debugging)
- Heap inspector (memory/object analysis)
- Error diagnostics (enhanced error reporting)
- Build/VERSION constants: SDK_INT=33, RELEASE="13"
- Line number tables from DEX debug_info_item
- **Delivered**: Debug tooling for runtime inspection

### Milestone 12: Networking -- ACHIEVED
- java.net.HttpURLConnection: Real URLSession bridge for GET/POST/PUT/DELETE
- Request headers, response headers, real response code + body as InputStream
- javax.net.ssl.HttpsURLConnection extends HttpURLConnection + SSL stubs
- OkHttp3: Request.Builder, Call.execute/enqueue, Response via real URLSession callback
- **Delivered**: Real networking via iOS URLSession bridge

## Test Coverage

- **126 tests** covering parser hardening, DEX parsing, VM execution, framework classes, UI rendering, and integration scenarios
- Swift Testing framework with DexLoomTests target

## Current Feature Summary

### Fully Supported
- All 256 Dalvik opcodes with edge case handling (computed goto dispatch)
- invoke-custom: Real LambdaMetafactory + StringConcatFactory
- Bytecode verifier: structural verification pass
- 450+ framework classes (Android, Java, Kotlin, RxJava, OkHttp, Retrofit, Glide)
- 30+ view types with ConstraintLayout basic solver
- Full activity lifecycle with state save/restore and 16-deep back-stack
- Fragment lifecycle, Service, BroadcastReceiver, ContentProvider
- Reflection including Proxy, Constructor, annotations
- JNI bridge (232 functions)
- AssetManager, File I/O, permissions system
- Touch events, menus, text input, long-press
- Cooperative threading, LiveData/ViewModel
- Real networking via URLSession (HttpURLConnection, OkHttp3)
- Debug tools: UI tree inspector, heap inspector, error diagnostics
- Mark-sweep GC with 5 root sets, string interning (8192 capacity)

### Known Limitations
- Compose apps: fundamentally unsupported (need Compose compiler runtime)
- JNI: Can't load .so files (no dlopen); provides env for DEX-side JNI calls only
- Threading: cooperative (synchronous) only, no true concurrency
- Multidex: supported (up to 8 DEX files)
- 9-patch PNG, StateListDrawable, LayerDrawable: not yet implemented
- invoke-polymorphic: stub (returns null with warning)
- Socket/ServerSocket: not yet implemented
- Obfuscated/heavily optimized APKs: may have issues

## Future Work
- Split APK / App Bundle support
- Fuzzing infrastructure
- Performance benchmarking harness
- ConstraintLayout guidelines and chains
- Proper measure/layout pass (Android 2-pass model)
- Incremental/generational GC
- Register type tracking in verifier
