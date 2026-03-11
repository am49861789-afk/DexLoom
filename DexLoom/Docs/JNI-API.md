# DexLoom JNI Bridge API Reference

## Overview

DexLoom provides a fake `JNIEnv` function table that maps standard JNI calls to
DexLoom's internal VM operations. When DEX bytecode invokes a native method, the
method receives a real-looking `JNIEnv*` pointer backed by this bridge. This
allows many JNI-using code paths to work without modification, even though no
actual `.so` libraries are loaded.

### Design Principles

- **Direct pointer casting.** `jobject` and `DxObject*` are the same pointer
  (cast via `dx_jni_wrap_object` / `dx_jni_unwrap_object`). No indirection
  table, no handle tracking.
- **Single-threaded.** The bridge stores `DxVM*` in a file-static global
  (`g_vm`). This is safe because DexLoom runs on a single cooperative thread.
- **No reference tracking.** Local/global/weak references are identity
  pass-throughs. `NewGlobalRef` returns its argument unchanged. This is correct
  for a single-threaded, non-compacting GC.
- **JNI 1.6 compatible.** `GetVersion` returns `0x00010006`. The full 232-slot
  function table is populated.

### Initialization

```c
// Called during VM startup
DxResult dx_jni_init(DxVM *vm);

// Get the JNIEnv* to pass to native methods
JNIEnv *dx_jni_get_env(DxVM *vm);

// Called during VM teardown
void dx_jni_destroy(DxVM *vm);
```

### Object/Class Wrapping

```c
jobject   dx_jni_wrap_object(DxObject *obj);    // DxObject* -> jobject
DxObject *dx_jni_unwrap_object(jobject ref);    // jobject -> DxObject*

jclass    dx_jni_wrap_class(DxClass *cls);      // DxClass* -> jclass
DxClass  *dx_jni_unwrap_class(jclass ref);      // jclass -> DxClass*
```

---

## JNI Function Reference

Each entry shows the JNI function table slot, implementation status, and
behavior. Functions are grouped by category.

**Status key:**
- **FULL** -- Fully implemented, backed by VM operations.
- **PASSTHROUGH** -- Returns argument unchanged or returns a fixed value; correct
  for DexLoom's single-threaded, non-compacting model.
- **STUB** -- Returns a default value (NULL/0/false). Not wired to any VM logic.

---

### Version

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 4 | `jint GetVersion(JNIEnv*)` | FULL | Returns `0x00010006` (JNI 1.6) |

### Class Operations

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 5 | `jclass DefineClass(JNIEnv*, const char*, jobject, const jbyte*, jsize)` | STUB | Logs warning, returns NULL |
| 6 | `jclass FindClass(JNIEnv*, const char*)` | FULL | Converts JNI name to descriptor, calls `dx_vm_load_class` |
| 10 | `jclass GetSuperclass(JNIEnv*, jclass)` | FULL | Returns `cls->super_class` |
| 11 | `jboolean IsAssignableFrom(JNIEnv*, jclass, jclass)` | FULL | Walks superclass chain |

### Reflection

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 7 | `jmethodID FromReflectedMethod(JNIEnv*, jobject)` | STUB | Returns NULL |
| 8 | `jfieldID FromReflectedField(JNIEnv*, jobject)` | STUB | Returns NULL |
| 9 | `jobject ToReflectedMethod(JNIEnv*, jclass, jmethodID, jboolean)` | STUB | Returns NULL |
| 12 | `jobject ToReflectedField(JNIEnv*, jclass, jfieldID, jboolean)` | STUB | Returns NULL |

### Exception Handling

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 13 | `jint Throw(JNIEnv*, jthrowable)` | FULL | Sets `vm->pending_exception` |
| 14 | `jint ThrowNew(JNIEnv*, jclass, const char*)` | FULL | Creates exception via `dx_vm_create_exception`, sets pending |
| 15 | `jthrowable ExceptionOccurred(JNIEnv*)` | FULL | Returns `vm->pending_exception` |
| 16 | `void ExceptionDescribe(JNIEnv*)` | FULL | Logs pending exception class descriptor |
| 17 | `void ExceptionClear(JNIEnv*)` | FULL | Clears `vm->pending_exception` |
| 18 | `void FatalError(JNIEnv*, const char*)` | FULL | Logs error message (does not abort) |
| 228 | `jboolean ExceptionCheck(JNIEnv*)` | FULL | Returns JNI_TRUE if pending exception exists |

### Reference Management

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 19 | `jint PushLocalFrame(JNIEnv*, jint)` | PASSTHROUGH | Always returns 0 (success) |
| 20 | `jobject PopLocalFrame(JNIEnv*, jobject)` | PASSTHROUGH | Returns result argument unchanged |
| 21 | `jobject NewGlobalRef(JNIEnv*, jobject)` | PASSTHROUGH | Returns argument (no ref tracking) |
| 22 | `void DeleteGlobalRef(JNIEnv*, jobject)` | PASSTHROUGH | No-op |
| 23 | `void DeleteLocalRef(JNIEnv*, jobject)` | PASSTHROUGH | No-op |
| 24 | `jboolean IsSameObject(JNIEnv*, jobject, jobject)` | FULL | Pointer equality comparison |
| 25 | `jobject NewLocalRef(JNIEnv*, jobject)` | PASSTHROUGH | Returns argument unchanged |
| 26 | `jint EnsureLocalCapacity(JNIEnv*, jint)` | PASSTHROUGH | Always returns 0 |
| 226 | `jweak NewWeakGlobalRef(JNIEnv*, jobject)` | PASSTHROUGH | Returns argument unchanged |
| 227 | `void DeleteWeakGlobalRef(JNIEnv*, jweak)` | PASSTHROUGH | No-op |
| 232 | `jobjectRefType GetObjectRefType(JNIEnv*, jobject)` | PASSTHROUGH | Always returns `JNILocalRefType` |

### Object Operations

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 27 | `jobject AllocObject(JNIEnv*, jclass)` | FULL | Calls `dx_vm_alloc_object` (no constructor) |
| 28 | `jobject NewObject(JNIEnv*, jclass, jmethodID, ...)` | FULL | Allocates object, invokes `<init>` method |
| 29 | `jobject NewObjectV(JNIEnv*, jclass, jmethodID, va_list)` | PARTIAL | Allocates object but does not invoke constructor with args |
| 30 | `jobject NewObjectA(JNIEnv*, jclass, jmethodID, const jvalue*)` | PARTIAL | Same as NewObjectV |
| 31 | `jclass GetObjectClass(JNIEnv*, jobject)` | FULL | Returns `obj->klass` |
| 32 | `jboolean IsInstanceOf(JNIEnv*, jobject, jclass)` | FULL | Walks superclass chain from `obj->klass` |

### Instance Method Invocation

All Call\<Type\>Method families have three variants: variadic (`...`), `va_list`
(`V`), and `jvalue` array (`A`).

| # | Method Group | Status | Notes |
|---|-------------|--------|-------|
| 34-36 | `CallObjectMethod{,V,A}` | FULL | Dispatches via `dx_vm_execute_method`, returns object result |
| 37-39 | `CallBooleanMethod{,V,A}` | FULL | Dispatches, extracts int as boolean |
| 40-42 | `CallByteMethod{,V,A}` | STUB | Returns 0 |
| 43-45 | `CallCharMethod{,V,A}` | STUB | Returns 0 |
| 46-48 | `CallShortMethod{,V,A}` | STUB | Returns 0 |
| 49-51 | `CallIntMethod{,V,A}` | FULL | Dispatches, extracts int result |
| 52-54 | `CallLongMethod{,V,A}` | FULL | Dispatches, extracts long result |
| 55-57 | `CallFloatMethod{,V,A}` | STUB | Returns 0.0f |
| 58-60 | `CallDoubleMethod{,V,A}` | STUB | Returns 0.0 |
| 61-63 | `CallVoidMethod{,V,A}` | FULL | Dispatches method, ignores return |

### Non-Virtual Method Invocation

| # | Method Group | Status | Notes |
|---|-------------|--------|-------|
| 64-93 | `CallNonvirtual<Type>Method{,V,A}` (all types) | STUB | All return default values |

### Instance Method Resolution

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 33 | `jmethodID GetMethodID(JNIEnv*, jclass, const char*, const char*)` | FULL | Calls `dx_vm_find_method` by name (signature ignored) |

### Instance Field Access

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 94 | `jfieldID GetFieldID(JNIEnv*, jclass, const char*, const char*)` | FULL | Returns strdup'd field name as fieldID |
| 95 | `jobject GetObjectField(JNIEnv*, jobject, jfieldID)` | FULL | Calls `dx_vm_get_field` by name |
| 96-103 | `Get<Boolean/Byte/Char/Short/Int/Long/Float/Double>Field` | FULL | Calls `dx_vm_get_field`, extracts typed value |
| 104 | `void SetObjectField(JNIEnv*, jobject, jfieldID, jobject)` | FULL | Calls `dx_vm_set_field` |
| 105-112 | `Set<Boolean/Byte/Char/Short/Int/Long/Float/Double>Field` | FULL | Calls `dx_vm_set_field` with typed value |

### Static Method Invocation

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 113 | `jmethodID GetStaticMethodID(JNIEnv*, jclass, const char*, const char*)` | FULL | Calls `dx_vm_find_method` by name |
| 114-143 | `CallStatic<Type>Method{,V,A}` (all types including Void) | STUB | All return default values |

### Static Field Access

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 144 | `jfieldID GetStaticFieldID(JNIEnv*, jclass, const char*, const char*)` | FULL | Iterates `field_defs[]` to find matching static field |
| 145 | `jobject GetStaticObjectField(JNIEnv*, jclass, jfieldID)` | FULL | Looks up `static_fields[]` by name match |
| 146-153 | `GetStatic<Boolean/Byte/Char/Short/Int/Long/Float/Double>Field` | STUB | Return default values |
| 154 | `void SetStaticObjectField(JNIEnv*, jclass, jfieldID, jobject)` | FULL | Writes to `static_fields[]` by name match |
| 155-162 | `SetStatic<Boolean/Byte/Char/Short/Int/Long/Float/Double>Field` | STUB | No-ops |

### String Operations

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 163 | `jstring NewString(JNIEnv*, const jchar*, jsize)` | FULL | Converts UTF-16 to UTF-8 (ASCII subset), creates DxObject string |
| 164 | `jsize GetStringLength(JNIEnv*, jstring)` | FULL | Returns UTF-16 code unit count |
| 165 | `const jchar* GetStringChars(JNIEnv*, jstring, jboolean*)` | FULL | Returns allocated UTF-16 buffer (caller must release) |
| 166 | `void ReleaseStringChars(JNIEnv*, jstring, const jchar*)` | FULL | Frees the UTF-16 buffer |
| 167 | `jstring NewStringUTF(JNIEnv*, const char*)` | FULL | Creates DxObject string from UTF-8 |
| 168 | `jsize GetStringUTFLength(JNIEnv*, jstring)` | FULL | Returns `strlen` of backing UTF-8 |
| 169 | `const char* GetStringUTFChars(JNIEnv*, jstring, jboolean*)` | FULL | Returns direct pointer to internal UTF-8 (no copy) |
| 170 | `void ReleaseStringUTFChars(JNIEnv*, jstring, const char*)` | PASSTHROUGH | No-op (no copy was made) |
| 220 | `void GetStringRegion(JNIEnv*, jstring, jsize, jsize, jchar*)` | FULL | Copies UTF-16 sub-region into caller's buffer |
| 221 | `void GetStringUTFRegion(JNIEnv*, jstring, jsize, jsize, char*)` | FULL | Copies UTF-8 sub-region into caller's buffer |
| 224 | `const jchar* GetStringCritical(JNIEnv*, jstring, jboolean*)` | STUB | Returns NULL |
| 225 | `void ReleaseStringCritical(JNIEnv*, jstring, const jchar*)` | PASSTHROUGH | No-op |

### Array Operations

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 171 | `jsize GetArrayLength(JNIEnv*, jarray)` | FULL | Returns `obj->array_length` |
| 172 | `jobjectArray NewObjectArray(JNIEnv*, jsize, jclass, jobject)` | FULL | Calls `dx_vm_alloc_array` |
| 173 | `jobject GetObjectArrayElement(JNIEnv*, jobjectArray, jsize)` | FULL | Bounds-checked access to `array_elements[]` |
| 174 | `void SetObjectArrayElement(JNIEnv*, jobjectArray, jsize, jobject)` | FULL | Bounds-checked write to `array_elements[]` |
| 175-182 | `New<Boolean/Byte/Char/Short/Int/Long/Float/Double>Array` | FULL | All call `dx_vm_alloc_array` |
| 183-190 | `Get<Type>ArrayElements` (all 8 primitive types) | STUB | Return NULL (no direct buffer access) |
| 191-198 | `Release<Type>ArrayElements` (all 8 primitive types) | PASSTHROUGH | No-ops |
| 199-214 | `Get/Set<Type>ArrayRegion` (all 8 primitive types) | STUB | No-ops |
| 222 | `void* GetPrimitiveArrayCritical(JNIEnv*, jarray, jboolean*)` | STUB | Returns NULL |
| 223 | `void ReleasePrimitiveArrayCritical(JNIEnv*, jarray, void*, jint)` | PASSTHROUGH | No-op |

### Native Method Registration

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 215 | `jint RegisterNatives(JNIEnv*, jclass, const JNINativeMethod*, jint)` | FULL | Binds native function pointers to DxMethod entries |
| 216 | `jint UnregisterNatives(JNIEnv*, jclass)` | PASSTHROUGH | Returns 0 (no-op) |

### Monitor Operations

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 217 | `jint MonitorEnter(JNIEnv*, jobject)` | PASSTHROUGH | Returns 0 (single-threaded, no locking needed) |
| 218 | `jint MonitorExit(JNIEnv*, jobject)` | PASSTHROUGH | Returns 0 |

### VM Interface

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 219 | `jint GetJavaVM(JNIEnv*, JavaVM**)` | PARTIAL | Sets `*vm = NULL`, returns 0 |

### Direct Byte Buffers

| # | Function | Status | Notes |
|---|----------|--------|-------|
| 229 | `jobject NewDirectByteBuffer(JNIEnv*, void*, jlong)` | STUB | Returns NULL |
| 230 | `void* GetDirectBufferAddress(JNIEnv*, jobject)` | STUB | Returns NULL |
| 231 | `jlong GetDirectBufferCapacity(JNIEnv*, jobject)` | STUB | Returns -1 |

---

## Implementation Summary

| Category | Total Functions | Fully Implemented | Passthrough/Partial | Stub |
|----------|----------------|-------------------|---------------------|------|
| Version | 1 | 1 | 0 | 0 |
| Class Operations | 4 | 3 | 0 | 1 |
| Reflection | 4 | 0 | 0 | 4 |
| Exception Handling | 7 | 7 | 0 | 0 |
| Reference Management | 11 | 1 | 10 | 0 |
| Object Operations | 6 | 4 | 2 | 0 |
| Instance Methods | 33 | 15 | 0 | 18 |
| Non-Virtual Methods | 30 | 0 | 0 | 30 |
| Instance Fields | 19 | 19 | 0 | 0 |
| Static Methods | 31 | 2 | 0 | 29 |
| Static Fields | 19 | 3 | 0 | 16 |
| String Operations | 12 | 9 | 2 | 1 |
| Array Operations | 44 | 8 | 9 | 27 |
| Registration | 2 | 1 | 1 | 0 |
| Monitors | 2 | 0 | 2 | 0 |
| VM Interface | 1 | 0 | 1 | 0 |
| Direct Buffers | 3 | 0 | 0 | 3 |
| **Total** | **229** | **73** | **27** | **129** |

---

## Known Limitations

- **Cannot load `.so` files.** iOS does not allow `dlopen` of arbitrary shared
  libraries. The JNI bridge exists for DEX-side JNI calls only; it cannot execute
  actual ARM native code from APKs.
- **No multi-argument dispatch.** `Call<Type>Method` variants that take
  `va_list` or `jvalue[]` arguments only pass the receiver (`this`) to the VM.
  Additional arguments from variadic/va_list/jvalue are not unpacked into the
  DexLoom call frame.
- **Primitive array direct access not supported.** `Get<Type>ArrayElements`
  always returns NULL. Use `Get/SetObjectArrayElement` for object arrays, which
  work correctly.
- **Static method calls are stubs.** `CallStatic<Type>Method` families return
  default values. Static methods should be called through the DEX interpreter
  instead.
- **UTF-16 NewString is ASCII-only.** `NewString` converts UTF-16 to UTF-8 by
  masking to 7 bits. Non-ASCII code points are truncated. `GetStringChars` and
  `GetStringRegion` do full UTF-8 to UTF-16 conversion including surrogate pairs.
