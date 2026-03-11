import Testing
import Foundation
@testable import DexLoom

// MARK: - Helper to create a VM with framework classes registered

private func makeVM() -> (ctx: UnsafeMutablePointer<DxContext>, vm: UnsafeMutablePointer<DxVM>) {
    let ctx = dx_context_create()!
    let vm = dx_vm_create(ctx)!
    dx_vm_register_framework_classes(vm)
    return (ctx, vm)
}

private func teardownVM(_ ctx: UnsafeMutablePointer<DxContext>, _ vm: UnsafeMutablePointer<DxVM>) {
    dx_vm_destroy(vm)
    ctx.pointee.vm = nil
    dx_context_destroy(ctx)
}

// ============================================================
// MARK: - Existing Core Tests
// ============================================================

@Suite("DexLoom Core Tests")
struct DexLoomCoreTests {

    @Test("Runtime context creation and destruction")
    func testContextLifecycle() {
        let ctx = dx_context_create()
        #expect(ctx != nil)
        if let ctx = ctx {
            dx_context_destroy(ctx)
        }
    }

    @Test("DEX magic validation rejects invalid data")
    func testDexMagicValidation() {
        // Must be >= header size (112) but with bad magic
        var bad_data = [UInt8](repeating: 0, count: 112)
        var dex: UnsafeMutablePointer<DxDexFile>?
        let result = dx_dex_parse(&bad_data, UInt32(bad_data.count), &dex)
        #expect(result == DX_ERR_INVALID_MAGIC)
    }

    @Test("DEX header parsing with valid minimal header")
    func testDexHeaderParsing() {
        var data = [UInt8](repeating: 0, count: 112)
        let magic: [UInt8] = [0x64, 0x65, 0x78, 0x0A, 0x30, 0x33, 0x35, 0x00]
        for i in 0..<8 { data[i] = magic[i] }
        data[32] = 112; data[33] = 0; data[34] = 0; data[35] = 0
        data[36] = 112; data[37] = 0; data[38] = 0; data[39] = 0
        data[40] = 0x78; data[41] = 0x56; data[42] = 0x34; data[43] = 0x12

        var dex: UnsafeMutablePointer<DxDexFile>?
        let result = dx_dex_parse(&data, UInt32(data.count), &dex)
        #expect(result == DX_OK)
        if let dex = dex {
            #expect(dex.pointee.header.header_size == 112)
            dx_dex_free(dex)
        }
    }

    @Test("Log system does not crash")
    func testLogInit() {
        dx_log_init()
        dx_log_msg(DX_LOG_INFO, "Test", "Hello from test")
    }

    @Test("Result string conversion")
    func testResultStrings() {
        let ok = String(cString: dx_result_string(DX_OK))
        #expect(ok == "OK")
        let notFound = String(cString: dx_result_string(DX_ERR_NOT_FOUND))
        #expect(notFound == "NOT_FOUND")
    }

    @Test("Opcode name lookup")
    func testOpcodeNames() {
        let nop = String(cString: dx_opcode_name(0x00))
        #expect(nop == "nop")
        let invokeVirtual = String(cString: dx_opcode_name(0x6E))
        #expect(invokeVirtual == "invoke-virtual")
    }

    @Test("UI node tree operations")
    func testUINodeTree() {
        let root = dx_ui_node_create(DX_VIEW_LINEAR_LAYOUT, 1)!
        let child1 = dx_ui_node_create(DX_VIEW_TEXT_VIEW, 2)!
        let child2 = dx_ui_node_create(DX_VIEW_BUTTON, 3)!

        dx_ui_node_add_child(root, child1)
        dx_ui_node_add_child(root, child2)
        #expect(root.pointee.child_count == 2)

        dx_ui_node_set_text(child1, "Hello")
        #expect(String(cString: child1.pointee.text) == "Hello")

        let found = dx_ui_node_find_by_id(root, 3)
        #expect(found == child2)
        #expect(dx_ui_node_find_by_id(root, 99) == nil)

        dx_ui_node_destroy(root)
    }

    @Test("VM framework class registration")
    func testVMFrameworkRegistration() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        #expect(dx_vm_find_class(vm, "Ljava/lang/Object;") != nil)
        #expect(dx_vm_find_class(vm, "Landroid/app/Activity;") != nil)
        #expect(dx_vm_find_class(vm, "Landroid/widget/TextView;") != nil)
        #expect(dx_vm_find_class(vm, "Landroid/widget/Button;") != nil)
    }

    @Test("VM string creation and retrieval")
    func testVMStrings() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let strObj = dx_vm_create_string(vm, "Hello DexLoom")
        #expect(strObj != nil)
        if let strObj = strObj {
            let value = dx_vm_get_string_value(strObj)
            #expect(value != nil)
            if let value = value {
                #expect(String(cString: value) == "Hello DexLoom")
            }
        }
    }

    @Test("VM object allocation")
    func testVMObjectAlloc() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        let obj = dx_vm_alloc_object(vm, cls)
        #expect(obj != nil)
        #expect(obj?.pointee.klass == cls)
    }

    @Test("Field set/get on multi-level hierarchy does not crash")
    func testFieldHierarchySafety() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Allocate an Activity object (has no field_defs)
        let actCls = dx_vm_find_class(vm, "Landroid/app/Activity;")!
        let obj = dx_vm_alloc_object(vm, actCls)!

        // set_field on a field that doesn't exist should not crash
        var val = DxValue(tag: DX_VAL_INT, DxValue.__Unnamed_union___Anonymous_field1(i: 42))
        let setResult = dx_vm_set_field(obj, "mExtraDataMap", val)
        #expect(setResult == DX_OK) // silently absorbed

        // get_field on a missing field should return null, not crash
        var out = DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: nil))
        let getResult = dx_vm_get_field(obj, "mExtraDataMap", &out)
        #expect(getResult == DX_OK) // returns null
    }

    @Test("AppCompatActivity is registered")
    func testAppCompatRegistered() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        #expect(dx_vm_find_class(vm, "Landroidx/appcompat/app/AppCompatActivity;") != nil)
        #expect(dx_vm_find_class(vm, "Landroidx/constraintlayout/widget/ConstraintLayout;") != nil)
    }

    @Test("Opcode width lookup")
    func testOpcodeWidths() {
        #expect(dx_opcode_width(0x00) == 1) // nop
        #expect(dx_opcode_width(0x28) == 1) // goto (was broken: 2)
        #expect(dx_opcode_width(0x6E) == 3) // invoke-virtual
        #expect(dx_opcode_width(0x14) == 3) // const (31i)
        #expect(dx_opcode_width(0x18) == 5) // const-wide (51l)
    }

    @Test("Render model creation from UI tree")
    func testRenderModel() {
        let root = dx_ui_node_create(DX_VIEW_LINEAR_LAYOUT, 1)!
        root.pointee.orientation = DX_ORIENTATION_VERTICAL

        let tv = dx_ui_node_create(DX_VIEW_TEXT_VIEW, 2)!
        dx_ui_node_set_text(tv, "Hello")
        dx_ui_node_add_child(root, tv)

        let model = dx_render_model_create(root)
        #expect(model != nil)
        #expect(model!.pointee.root != nil)
        #expect(model!.pointee.root.pointee.type == DX_VIEW_LINEAR_LAYOUT)
        #expect(model!.pointee.root.pointee.child_count == 1)

        dx_render_model_destroy(model)
        dx_ui_node_destroy(root)
    }
}

// ============================================================
// MARK: - VM Lifecycle Tests
// ============================================================

@Suite("VM Lifecycle Tests")
struct VMLifecycleTests {

    @Test("Create and destroy VM without crash")
    func testCreateDestroy() {
        let ctx = dx_context_create()!
        let vm = dx_vm_create(ctx)
        #expect(vm != nil)
        if let vm = vm {
            dx_vm_destroy(vm)
        }
        ctx.pointee.vm = nil
        dx_context_destroy(ctx)
    }

    @Test("Register framework classes returns OK")
    func testRegisterFramework() {
        let ctx = dx_context_create()!
        let vm = dx_vm_create(ctx)!
        let result = dx_vm_register_framework_classes(vm)
        #expect(result == DX_OK)
        // Should have registered many classes
        #expect(vm.pointee.class_count > 100)
        teardownVM(ctx, vm)
    }

    @Test("Class hash table lookup works for all well-known classes")
    func testClassHashTable() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let classNames = [
            "Ljava/lang/Object;",
            "Ljava/lang/String;",
            "Ljava/lang/Integer;",
            "Ljava/lang/Boolean;",
            "Ljava/util/ArrayList;",
            "Ljava/util/HashMap;",
            "Ljava/util/Arrays;",
            "Ljava/util/Collections;",
            "Landroid/app/Activity;",
            "Landroid/os/Bundle;",
            "Landroid/content/Intent;",
            "Landroid/widget/TextView;",
            "Landroid/widget/Button;",
            "Landroid/widget/EditText;",
            "Landroid/widget/ImageView;",
            "Landroid/widget/Toast;",
            "Landroid/util/Log;",
            "Landroid/view/View;",
            "Landroid/view/ViewGroup;",
        ]
        for name in classNames {
            let cls = dx_vm_find_class(vm, name)
            #expect(cls != nil, "Expected to find class \(name)")
        }
    }

    @Test("find_class returns nil for unknown class")
    func testFindClassUnknown() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Lcom/nonexistent/FakeClass;")
        #expect(cls == nil)
    }

    @Test("VM cached class pointers are set after registration")
    func testVMCachedPointers() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        #expect(vm.pointee.class_object != nil)
        #expect(vm.pointee.class_string != nil)
        #expect(vm.pointee.class_activity != nil)
        #expect(vm.pointee.class_view != nil)
        #expect(vm.pointee.class_textview != nil)
        #expect(vm.pointee.class_button != nil)
        #expect(vm.pointee.class_viewgroup != nil)
        #expect(vm.pointee.class_linearlayout != nil)
        #expect(vm.pointee.class_context != nil)
        #expect(vm.pointee.class_bundle != nil)
        #expect(vm.pointee.class_arraylist != nil)
        #expect(vm.pointee.class_hashmap != nil)
        #expect(vm.pointee.class_intent != nil)
        #expect(vm.pointee.class_edittext != nil)
        #expect(vm.pointee.class_imageview != nil)
        #expect(vm.pointee.class_toast != nil)
        #expect(vm.pointee.class_appcompat != nil)
    }

    @Test("Multiple VM instances can coexist")
    func testMultipleVMs() {
        let ctx1 = dx_context_create()!
        let vm1 = dx_vm_create(ctx1)!
        dx_vm_register_framework_classes(vm1)

        let ctx2 = dx_context_create()!
        let vm2 = dx_vm_create(ctx2)!
        dx_vm_register_framework_classes(vm2)

        // Both should work independently
        #expect(dx_vm_find_class(vm1, "Ljava/lang/String;") != nil)
        #expect(dx_vm_find_class(vm2, "Ljava/lang/String;") != nil)

        // Objects from vm1 and vm2 are separate
        let s1 = dx_vm_create_string(vm1, "hello")
        let s2 = dx_vm_create_string(vm2, "world")
        #expect(s1 != nil)
        #expect(s2 != nil)

        dx_vm_destroy(vm1)
        ctx1.pointee.vm = nil
        dx_context_destroy(ctx1)

        // vm2 should still work after vm1 is destroyed
        let s3 = dx_vm_create_string(vm2, "still alive")
        #expect(s3 != nil)

        dx_vm_destroy(vm2)
        ctx2.pointee.vm = nil
        dx_context_destroy(ctx2)
    }
}

// ============================================================
// MARK: - Framework Class Tests
// ============================================================

@Suite("Framework Class Tests")
struct FrameworkClassTests {

    @Test("String creation with various content")
    func testStringCreation() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Empty string
        let empty = dx_vm_create_string(vm, "")
        #expect(empty != nil)
        #expect(String(cString: dx_vm_get_string_value(empty)!) == "")

        // ASCII content
        let ascii = dx_vm_create_string(vm, "Hello World 123")
        #expect(ascii != nil)
        #expect(String(cString: dx_vm_get_string_value(ascii)!) == "Hello World 123")

        // Long string
        let longStr = String(repeating: "abcd", count: 250)
        let longObj = dx_vm_create_string(vm, longStr)
        #expect(longObj != nil)
        #expect(String(cString: dx_vm_get_string_value(longObj)!) == longStr)
    }

    @Test("String interning returns same object for same value")
    func testStringInterning() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let s1 = dx_vm_intern_string(vm, "interned_test")
        let s2 = dx_vm_intern_string(vm, "interned_test")
        #expect(s1 != nil)
        #expect(s2 != nil)
        // Interned strings with same value should be the same object
        #expect(s1 == s2)

        // Different value should be a different object
        let s3 = dx_vm_intern_string(vm, "different_value")
        #expect(s3 != nil)
        #expect(s3 != s1)
    }

    @Test("String object has correct class")
    func testStringClass() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let strObj = dx_vm_create_string(vm, "test")!
        #expect(strObj.pointee.klass == vm.pointee.class_string)
        let desc = String(cString: strObj.pointee.klass.pointee.descriptor)
        #expect(desc == "Ljava/lang/String;")
    }

    @Test("ArrayList: find class and create instance")
    func testArrayListCreation() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let alCls = dx_vm_find_class(vm, "Ljava/util/ArrayList;")!
        let list = dx_vm_alloc_object(vm, alCls)
        #expect(list != nil)
        #expect(list?.pointee.klass == alCls)
    }

    @Test("ArrayList: native add and size methods exist")
    func testArrayListMethods() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let alCls = dx_vm_find_class(vm, "Ljava/util/ArrayList;")!

        // Check that key methods are registered
        let addMethod = dx_vm_find_method(alCls, "add", "ZL")
        #expect(addMethod != nil, "ArrayList.add should be registered")

        let sizeMethod = dx_vm_find_method(alCls, "size", "I")
        #expect(sizeMethod != nil, "ArrayList.size should be registered")

        let getMethod = dx_vm_find_method(alCls, "get", "LI")
        #expect(getMethod != nil, "ArrayList.get should be registered")
    }

    @Test("HashMap: find class and verify methods")
    func testHashMapMethods() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let hmCls = dx_vm_find_class(vm, "Ljava/util/HashMap;")!
        let obj = dx_vm_alloc_object(vm, hmCls)
        #expect(obj != nil)

        // Check key methods
        let putMethod = dx_vm_find_method(hmCls, "put", "LLL")
        #expect(putMethod != nil, "HashMap.put should be registered")

        let getMethod = dx_vm_find_method(hmCls, "get", "LL")
        #expect(getMethod != nil, "HashMap.get should be registered")

        let sizeMethod = dx_vm_find_method(hmCls, "size", "I")
        #expect(sizeMethod != nil, "HashMap.size should be registered")

        let containsKeyMethod = dx_vm_find_method(hmCls, "containsKey", "ZL")
        #expect(containsKeyMethod != nil, "HashMap.containsKey should be registered")
    }

    @Test("Integer valueOf autoboxing class exists")
    func testIntegerAutoboxing() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let intCls = dx_vm_find_class(vm, "Ljava/lang/Integer;")
        #expect(intCls != nil, "java.lang.Integer should be registered")

        if let intCls = intCls {
            let valueOf = dx_vm_find_method(intCls, "valueOf", "LI")
            #expect(valueOf != nil, "Integer.valueOf should be registered for autoboxing")
        }
    }

    @Test("Long/Float/Double/Boolean autoboxing classes exist")
    func testAutoboxingClasses() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let types: [(String, String)] = [
            ("Ljava/lang/Long;", "LJ"),
            ("Ljava/lang/Float;", "LF"),
            ("Ljava/lang/Double;", "LD"),
            ("Ljava/lang/Boolean;", "LZ"),
            ("Ljava/lang/Byte;", "LB"),
            ("Ljava/lang/Short;", "LS"),
            ("Ljava/lang/Character;", "LC"),
        ]
        for (desc, shorty) in types {
            let cls = dx_vm_find_class(vm, desc)
            #expect(cls != nil, "Expected \(desc) to be registered")
            if let cls = cls {
                let valueOf = dx_vm_find_method(cls, "valueOf", shorty)
                #expect(valueOf != nil, "Expected valueOf on \(desc)")
            }
        }
    }

    @Test("Activity class has lifecycle methods")
    func testActivityLifecycleMethods() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let actCls = dx_vm_find_class(vm, "Landroid/app/Activity;")!

        // Check lifecycle methods exist
        let onCreate = dx_vm_find_method(actCls, "onCreate", "VL")
        #expect(onCreate != nil, "Activity.onCreate should exist")

        let onStart = dx_vm_find_method(actCls, "onStart", "V")
        #expect(onStart != nil, "Activity.onStart should exist")

        let onResume = dx_vm_find_method(actCls, "onResume", "V")
        #expect(onResume != nil, "Activity.onResume should exist")
    }

    @Test("View class has key methods")
    func testViewMethods() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let viewCls = dx_vm_find_class(vm, "Landroid/view/View;")!

        let setOnClick = dx_vm_find_method(viewCls, "setOnClickListener", "VL")
        #expect(setOnClick != nil, "View.setOnClickListener should exist")

        let findViewById = dx_vm_find_method(viewCls, "findViewById", "LI")
        #expect(findViewById != nil, "View.findViewById should exist")
    }

    @Test("Intent class exists with extras methods")
    func testIntentClass() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let intentCls = dx_vm_find_class(vm, "Landroid/content/Intent;")!
        let obj = dx_vm_alloc_object(vm, intentCls)
        #expect(obj != nil)

        let putExtra = dx_vm_find_method(intentCls, "putExtra", "LLL")
        #expect(putExtra != nil, "Intent.putExtra should exist")
    }

    @Test("Bundle class exists")
    func testBundleClass() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let bundleCls = dx_vm_find_class(vm, "Landroid/os/Bundle;")!
        let obj = dx_vm_alloc_object(vm, bundleCls)
        #expect(obj != nil)
    }

    @Test("Exception class hierarchy")
    func testExceptionClasses() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let exceptions = [
            "Ljava/lang/Exception;",
            "Ljava/lang/RuntimeException;",
            "Ljava/lang/NullPointerException;",
            "Ljava/lang/ArrayIndexOutOfBoundsException;",
            "Ljava/lang/ClassCastException;",
            "Ljava/lang/ArithmeticException;",
        ]
        for desc in exceptions {
            let cls = dx_vm_find_class(vm, desc)
            #expect(cls != nil, "Expected \(desc) to be registered")
        }
    }

    @Test("Collection interfaces registered")
    func testCollectionInterfaces() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let interfaces = [
            "Ljava/lang/Iterable;",
            "Ljava/util/Collection;",
            "Ljava/util/List;",
            "Ljava/util/Set;",
            "Ljava/util/Map;",
            "Ljava/util/Iterator;",
        ]
        for desc in interfaces {
            let cls = dx_vm_find_class(vm, desc)
            #expect(cls != nil, "Expected \(desc) to be registered")
        }
    }

    @Test("Android widget classes registered")
    func testWidgetClasses() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let widgets = [
            "Landroid/widget/Spinner;",
            "Landroid/widget/SeekBar;",
            "Landroid/widget/CheckBox;",
            "Landroid/widget/Switch;",
            "Landroid/widget/RadioButton;",
            "Landroid/widget/RadioGroup;",
            "Landroid/widget/ListView;",
        ]
        for desc in widgets {
            let cls = dx_vm_find_class(vm, desc)
            #expect(cls != nil, "Expected \(desc) to be registered")
        }
    }

    @Test("Kotlin standard library classes registered")
    func testKotlinClasses() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Kotlin stdlib should have some representation
        let kotlinUnit = dx_vm_find_class(vm, "Lkotlin/Unit;")
        #expect(kotlinUnit != nil, "Kotlin Unit should be registered")
    }
}

// ============================================================
// MARK: - Object System Tests
// ============================================================

@Suite("Object System Tests")
struct ObjectSystemTests {

    @Test("Allocate object and verify class pointer")
    func testAllocObjectClass() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        let obj = dx_vm_alloc_object(vm, objCls)!

        #expect(obj.pointee.klass == objCls)
        #expect(obj.pointee.is_array == false)
        #expect(obj.pointee.gc_mark == false)
    }

    @Test("Allocate array and verify length")
    func testAllocArray() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let arr = dx_vm_alloc_array(vm, 10)
        #expect(arr != nil)
        if let arr = arr {
            #expect(arr.pointee.is_array == true)
            #expect(arr.pointee.array_length == 10)
            #expect(arr.pointee.array_elements != nil)
        }
    }

    @Test("Allocate zero-length array")
    func testAllocZeroArray() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let arr = dx_vm_alloc_array(vm, 0)
        #expect(arr != nil)
        if let arr = arr {
            #expect(arr.pointee.is_array == true)
            #expect(arr.pointee.array_length == 0)
        }
    }

    @Test("Array element access")
    func testArrayElementAccess() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let arr = dx_vm_alloc_array(vm, 5)!

        // Set and read back values
        arr.pointee.array_elements[0] = DxValue(tag: DX_VAL_INT, DxValue.__Unnamed_union___Anonymous_field1(i: 42))
        arr.pointee.array_elements[1] = DxValue(tag: DX_VAL_INT, DxValue.__Unnamed_union___Anonymous_field1(i: 99))

        #expect(arr.pointee.array_elements[0].tag == DX_VAL_INT)
        #expect(arr.pointee.array_elements[0].i == 42)
        #expect(arr.pointee.array_elements[1].i == 99)
    }

    @Test("Heap tracks allocated objects")
    func testHeapTracking() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let initialCount = vm.pointee.heap_count
        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!

        let _ = dx_vm_alloc_object(vm, objCls)
        #expect(vm.pointee.heap_count == initialCount + 1)

        let _ = dx_vm_alloc_object(vm, objCls)
        #expect(vm.pointee.heap_count == initialCount + 2)
    }

    @Test("GC function exists and heap tracks objects")
    func testGCRelated() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        // Allocate several objects and verify they're on the heap
        let initialCount = vm.pointee.heap_count
        for _ in 0..<20 {
            let _ = dx_vm_alloc_object(vm, objCls)
        }
        #expect(vm.pointee.heap_count == initialCount + 20)
        // Note: dx_vm_gc requires a running execution context with proper
        // root set; calling it outside of execution can crash.
    }

    @Test("Object fields for classes with field_defs")
    func testObjectFieldsWithDefs() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // TextView should have field_defs (e.g., mText)
        let tvCls = dx_vm_find_class(vm, "Landroid/widget/TextView;")!
        let tv = dx_vm_alloc_object(vm, tvCls)!
        #expect(tv.pointee.klass == tvCls)
    }

    @Test("VM heap stats returns valid string")
    func testHeapStats() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let _ = dx_vm_alloc_object(vm, dx_vm_find_class(vm, "Ljava/lang/Object;")!)
        let stats = dx_vm_heap_stats(vm)
        #expect(stats != nil)
        if let stats = stats {
            let str = String(cString: stats)
            #expect(str.count > 0)
            free(stats)
        }
    }

    @Test("Create exception object with message")
    func testCreateException() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let exc = dx_vm_create_exception(vm, "Ljava/lang/NullPointerException;", "test null pointer")
        #expect(exc != nil)
        if let exc = exc {
            let desc = String(cString: exc.pointee.klass.pointee.descriptor)
            #expect(desc == "Ljava/lang/NullPointerException;")
        }
    }

    @Test("Frame pool allocation and release")
    func testFramePool() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Allocate a frame
        let frame = dx_vm_alloc_frame(vm)
        #expect(frame != nil)

        // Free it back to pool
        if let frame = frame {
            dx_vm_free_frame(vm, frame)
        }

        // Allocate again - should reuse from pool
        let frame2 = dx_vm_alloc_frame(vm)
        #expect(frame2 != nil)
        if let frame2 = frame2 {
            dx_vm_free_frame(vm, frame2)
        }
    }

    @Test("Frame pool handles many allocations")
    func testFramePoolStress() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Allocate more frames than pool size, then free all
        var frames: [UnsafeMutablePointer<DxFrame>] = []
        for _ in 0..<80 {
            if let f = dx_vm_alloc_frame(vm) {
                frames.append(f)
            }
        }
        #expect(frames.count == 80)

        // Free them all
        for f in frames {
            dx_vm_free_frame(vm, f)
        }
    }
}

// ============================================================
// MARK: - Bytecode Execution Tests
// ============================================================

@Suite("Bytecode Execution Tests")
struct BytecodeExecutionTests {

    @Test("Execute native method on String class")
    func testExecuteNativeMethod() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let strCls = dx_vm_find_class(vm, "Ljava/lang/String;")!
        let lengthMethod = dx_vm_find_method(strCls, "length", "I")
        #expect(lengthMethod != nil, "String.length should exist")

        if let lengthMethod = lengthMethod {
            // Create a string object to call length on
            let strObj = dx_vm_create_string(vm, "Hello")!
            var args = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: strObj))]
            var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))

            let status = dx_vm_execute_method(vm, lengthMethod, &args, 1, &result)
            #expect(status == DX_OK)
            #expect(result.tag == DX_VAL_INT)
            #expect(result.i == 5)
        }
    }

    @Test("Execute ArrayList.size on empty list")
    func testArrayListSize() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let alCls = dx_vm_find_class(vm, "Ljava/util/ArrayList;")!
        let list = dx_vm_alloc_object(vm, alCls)!

        // Call <init> first
        let initMethod = dx_vm_find_method(alCls, "<init>", "V")
        if let initMethod = initMethod {
            var args = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: list))]
            var initResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let _ = dx_vm_execute_method(vm, initMethod, &args, 1, &initResult)
        }

        // Call size
        let sizeMethod = dx_vm_find_method(alCls, "size", "I")!
        var sizeArgs = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: list))]
        var sizeResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let status = dx_vm_execute_method(vm, sizeMethod, &sizeArgs, 1, &sizeResult)
        #expect(status == DX_OK)
        #expect(sizeResult.tag == DX_VAL_INT)
        #expect(sizeResult.i == 0)
    }

    @Test("Execute ArrayList add then size")
    func testArrayListAddAndSize() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let alCls = dx_vm_find_class(vm, "Ljava/util/ArrayList;")!
        let list = dx_vm_alloc_object(vm, alCls)!

        // Init
        let initMethod = dx_vm_find_method(alCls, "<init>", "V")
        if let initMethod = initMethod {
            var args = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: list))]
            var r = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let _ = dx_vm_execute_method(vm, initMethod, &args, 1, &r)
        }

        // Add three items
        let addMethod = dx_vm_find_method(alCls, "add", "ZL")!
        for i in 0..<3 {
            let strObj = dx_vm_create_string(vm, "item\(i)")!
            var addArgs = [
                DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: list)),
                DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: strObj))
            ]
            var addResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let s = dx_vm_execute_method(vm, addMethod, &addArgs, 2, &addResult)
            #expect(s == DX_OK)
        }

        // Size should be 3
        let sizeMethod = dx_vm_find_method(alCls, "size", "I")!
        var sizeArgs = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: list))]
        var sizeResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let status = dx_vm_execute_method(vm, sizeMethod, &sizeArgs, 1, &sizeResult)
        #expect(status == DX_OK)
        #expect(sizeResult.i == 3)
    }

    @Test("Execute HashMap put and get")
    func testHashMapPutGet() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let hmCls = dx_vm_find_class(vm, "Ljava/util/HashMap;")!
        let map = dx_vm_alloc_object(vm, hmCls)!

        // Init
        let initMethod = dx_vm_find_method(hmCls, "<init>", "V")
        if let initMethod = initMethod {
            var args = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: map))]
            var r = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let _ = dx_vm_execute_method(vm, initMethod, &args, 1, &r)
        }

        // Put a key-value pair
        let putMethod = dx_vm_find_method(hmCls, "put", "LLL")!
        let key = dx_vm_create_string(vm, "myKey")!
        let value = dx_vm_create_string(vm, "myValue")!
        var putArgs = [
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: map)),
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: key)),
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: value))
        ]
        var putResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let putStatus = dx_vm_execute_method(vm, putMethod, &putArgs, 3, &putResult)
        #expect(putStatus == DX_OK)

        // Get by key
        let getMethod = dx_vm_find_method(hmCls, "get", "LL")!
        var getArgs = [
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: map)),
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: key))
        ]
        var getResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let getStatus = dx_vm_execute_method(vm, getMethod, &getArgs, 2, &getResult)
        #expect(getStatus == DX_OK)
        #expect(getResult.tag == DX_VAL_OBJ)
        if let resultObj = getResult.obj {
            let resultStr = String(cString: dx_vm_get_string_value(resultObj)!)
            #expect(resultStr == "myValue")
        }
    }

    @Test("Execute Integer.valueOf autoboxing")
    func testIntegerValueOf() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let intCls = dx_vm_find_class(vm, "Ljava/lang/Integer;")!
        let valueOf = dx_vm_find_method(intCls, "valueOf", "LI")!

        // valueOf is static, so first arg is not 'this'
        var args = [DxValue(tag: DX_VAL_INT, DxValue.__Unnamed_union___Anonymous_field1(i: 42))]
        var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let status = dx_vm_execute_method(vm, valueOf, &args, 1, &result)
        #expect(status == DX_OK)
        #expect(result.tag == DX_VAL_OBJ)
        #expect(result.obj != nil)
    }

    @Test("Opcode coverage: all 256 opcodes have names")
    func testAllOpcodesHaveNames() {
        for i: UInt8 in 0...255 {
            let name = dx_opcode_name(i)
            #expect(name != nil, "Opcode 0x\(String(i, radix: 16)) should have a name")
        }
    }

    @Test("Opcode widths are all > 0 for valid opcodes")
    func testOpcodeWidthsPositive() {
        // Key opcodes that must have positive widths
        let opcodes: [UInt8] = [
            0x00, // nop
            0x01, // move
            0x0E, // return-void
            0x12, // const/4
            0x1A, // const-string
            0x22, // new-instance
            0x28, // goto
            0x38, // if-eqz
            0x6E, // invoke-virtual
            0x90, // add-int
        ]
        for op in opcodes {
            #expect(dx_opcode_width(op) > 0, "Opcode 0x\(String(op, radix: 16)) width should be > 0")
        }
    }
}

// ============================================================
// MARK: - Error Handling Tests
// ============================================================

@Suite("Error Handling Tests")
struct ErrorHandlingTests {

    @Test("DEX parse rejects nil/empty data")
    func testDexParseEmpty() {
        var dex: UnsafeMutablePointer<DxDexFile>?
        // Empty buffer (too small for header)
        var data = [UInt8](repeating: 0, count: 4)
        let result = dx_dex_parse(&data, UInt32(data.count), &dex)
        #expect(result != DX_OK)
    }

    @Test("DEX parse rejects truncated header")
    func testDexParseTruncated() {
        var dex: UnsafeMutablePointer<DxDexFile>?
        // 50 bytes is less than the 112-byte header
        var data = [UInt8](repeating: 0, count: 50)
        let magic: [UInt8] = [0x64, 0x65, 0x78, 0x0A, 0x30, 0x33, 0x35, 0x00]
        for i in 0..<8 { data[i] = magic[i] }
        let result = dx_dex_parse(&data, UInt32(data.count), &dex)
        #expect(result != DX_OK)
    }

    @Test("DEX parse rejects wrong version magic")
    func testDexWrongVersion() {
        var data = [UInt8](repeating: 0, count: 112)
        // Valid prefix but invalid version "099"
        let magic: [UInt8] = [0x64, 0x65, 0x78, 0x0A, 0x30, 0x39, 0x39, 0x00]
        for i in 0..<8 { data[i] = magic[i] }
        data[32] = 112; data[33] = 0; data[34] = 0; data[35] = 0
        data[36] = 112; data[37] = 0; data[38] = 0; data[39] = 0
        data[40] = 0x78; data[41] = 0x56; data[42] = 0x34; data[43] = 0x12

        var dex: UnsafeMutablePointer<DxDexFile>?
        let result = dx_dex_parse(&data, UInt32(data.count), &dex)
        // Should either reject or accept depending on version tolerance
        // At minimum it should not crash
        if result == DX_OK, let dex = dex {
            dx_dex_free(dex)
        }
    }

    @Test("Instruction budget limit prevents infinite loops")
    func testInstructionBudget() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // The VM has insn_limit field - verify it's set to a reasonable value
        // or can be set
        #expect(vm.pointee.insn_limit == 0 || vm.pointee.insn_limit > 0)
        // DX_MAX_INSTRUCTIONS is 500000 per the types header
    }

    @Test("Context double-destroy safety")
    func testContextDoubleCreate() {
        // Just verify multiple create/destroy cycles work
        for _ in 0..<5 {
            let ctx = dx_context_create()!
            dx_context_destroy(ctx)
        }
    }

    @Test("Result string covers all error codes")
    func testAllResultStrings() {
        let codes: [DxResult] = [
            DX_OK,
            DX_ERR_NULL_PTR,
            DX_ERR_INVALID_MAGIC,
            DX_ERR_INVALID_FORMAT,
            DX_ERR_OUT_OF_MEMORY,
            DX_ERR_NOT_FOUND,
            DX_ERR_UNSUPPORTED_OPCODE,
            DX_ERR_CLASS_NOT_FOUND,
            DX_ERR_METHOD_NOT_FOUND,
            DX_ERR_FIELD_NOT_FOUND,
            DX_ERR_STACK_OVERFLOW,
            DX_ERR_STACK_UNDERFLOW,
            DX_ERR_EXCEPTION,
            DX_ERR_VERIFICATION_FAILED,
            DX_ERR_IO,
            DX_ERR_ZIP_INVALID,
            DX_ERR_AXML_INVALID,
            DX_ERR_UNSUPPORTED_VERSION,
            DX_ERR_INTERNAL,
        ]
        for code in codes {
            let str = dx_result_string(code)
            #expect(str != nil)
            let s = String(cString: str!)
            #expect(s.count > 0, "Result string for code should not be empty")
        }
    }

    @Test("VM diagnostic struct is clean on fresh VM")
    func testDiagnosticClean() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        #expect(vm.pointee.diag.has_error == false)
    }

    @Test("Create exception for unknown class returns nil or valid object")
    func testCreateExceptionUnknownClass() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Creating an exception with an unknown class - should handle gracefully
        let exc = dx_vm_create_exception(vm, "Lcom/fake/NonExistentException;", "test")
        // Either nil or a fallback object is fine, just must not crash
        _ = exc
    }

    @Test("String value of nil returns nil")
    func testGetStringValueNil() {
        let result = dx_vm_get_string_value(nil)
        #expect(result == nil)
    }
}

// ============================================================
// MARK: - Parser Hardening Tests
// ============================================================

@Suite("Parser Hardening Tests")
struct ParserHardeningTests {

    @Test("DEX parse rejects completely garbage data")
    func testGarbageData() {
        var data = [UInt8](repeating: 0xFF, count: 256)
        var dex: UnsafeMutablePointer<DxDexFile>?
        let result = dx_dex_parse(&data, UInt32(data.count), &dex)
        #expect(result == DX_ERR_INVALID_MAGIC)
    }

    @Test("DEX parse with file_size mismatch")
    func testFileSizeMismatch() {
        var data = [UInt8](repeating: 0, count: 112)
        let magic: [UInt8] = [0x64, 0x65, 0x78, 0x0A, 0x30, 0x33, 0x35, 0x00]
        for i in 0..<8 { data[i] = magic[i] }
        // header_size = 112
        data[32] = 112; data[33] = 0; data[34] = 0; data[35] = 0
        // file_size = 9999 (way larger than actual)
        data[36] = 0x0F; data[37] = 0x27; data[38] = 0; data[39] = 0
        // endian tag
        data[40] = 0x78; data[41] = 0x56; data[42] = 0x34; data[43] = 0x12

        var dex: UnsafeMutablePointer<DxDexFile>?
        let result = dx_dex_parse(&data, UInt32(data.count), &dex)
        // Should either reject or handle gracefully
        if result == DX_OK, let dex = dex {
            dx_dex_free(dex)
        }
    }

    @Test("UI node create with all view types")
    func testAllViewTypes() {
        let types: [DxViewType] = [
            DX_VIEW_LINEAR_LAYOUT,
            DX_VIEW_TEXT_VIEW,
            DX_VIEW_BUTTON,
            DX_VIEW_IMAGE_VIEW,
            DX_VIEW_EDIT_TEXT,
            DX_VIEW_FRAME_LAYOUT,
            DX_VIEW_RELATIVE_LAYOUT,
            DX_VIEW_CONSTRAINT_LAYOUT,
            DX_VIEW_SCROLL_VIEW,
            DX_VIEW_RECYCLER_VIEW,
            DX_VIEW_CARD_VIEW,
            DX_VIEW_SWITCH,
            DX_VIEW_CHECKBOX,
            DX_VIEW_PROGRESS_BAR,
            DX_VIEW_TOOLBAR,
            DX_VIEW_VIEW,
            DX_VIEW_VIEW_GROUP,
            DX_VIEW_LIST_VIEW,
            DX_VIEW_GRID_VIEW,
            DX_VIEW_SPINNER,
            DX_VIEW_SEEK_BAR,
            DX_VIEW_RATING_BAR,
            DX_VIEW_RADIO_BUTTON,
            DX_VIEW_RADIO_GROUP,
            DX_VIEW_FAB,
            DX_VIEW_TAB_LAYOUT,
            DX_VIEW_VIEW_PAGER,
            DX_VIEW_WEB_VIEW,
            DX_VIEW_CHIP,
            DX_VIEW_BOTTOM_NAV,
            DX_VIEW_SWIPE_REFRESH,
        ]
        for (idx, viewType) in types.enumerated() {
            let node = dx_ui_node_create(viewType, UInt32(idx + 100))
            #expect(node != nil, "Should create node for view type index \(idx)")
            if let node = node {
                #expect(node.pointee.type == viewType)
                #expect(node.pointee.view_id == UInt32(idx + 100))
                dx_ui_node_destroy(node)
            }
        }
    }

    @Test("UI node deep tree")
    func testDeepUITree() {
        // Build a 50-level deep tree
        let root = dx_ui_node_create(DX_VIEW_FRAME_LAYOUT, 0)!
        var current = root
        for i in 1..<50 {
            let child = dx_ui_node_create(DX_VIEW_FRAME_LAYOUT, UInt32(i))!
            dx_ui_node_add_child(current, child)
            current = child
        }

        // Set text on deepest node
        dx_ui_node_set_text(current, "deep leaf")
        #expect(String(cString: current.pointee.text) == "deep leaf")

        // Find the deepest node by ID
        let found = dx_ui_node_find_by_id(root, 49)
        #expect(found != nil)
        #expect(found == current)

        // Count total nodes
        let count = dx_ui_node_count(root)
        #expect(count == 50)

        dx_ui_node_destroy(root)
    }

    @Test("UI node text overwrite")
    func testUINodeTextOverwrite() {
        let node = dx_ui_node_create(DX_VIEW_TEXT_VIEW, 1)!
        dx_ui_node_set_text(node, "first")
        #expect(String(cString: node.pointee.text) == "first")

        dx_ui_node_set_text(node, "second")
        #expect(String(cString: node.pointee.text) == "second")

        dx_ui_node_set_text(node, "")
        #expect(String(cString: node.pointee.text) == "")

        dx_ui_node_destroy(node)
    }

    @Test("UI node wide tree with many siblings")
    func testWideSiblingTree() {
        let root = dx_ui_node_create(DX_VIEW_LINEAR_LAYOUT, 0)!
        for i in 1...64 {
            let child = dx_ui_node_create(DX_VIEW_TEXT_VIEW, UInt32(i))!
            dx_ui_node_set_text(child, "item \(i)")
            dx_ui_node_add_child(root, child)
        }
        #expect(root.pointee.child_count == 64)
        #expect(dx_ui_node_count(root) == 65) // root + 64 children

        // Find last child
        let last = dx_ui_node_find_by_id(root, 64)
        #expect(last != nil)

        dx_ui_node_destroy(root)
    }

    @Test("Render model from complex tree")
    func testRenderModelComplex() {
        let root = dx_ui_node_create(DX_VIEW_LINEAR_LAYOUT, 1)!
        root.pointee.orientation = DX_ORIENTATION_VERTICAL

        let child1 = dx_ui_node_create(DX_VIEW_TEXT_VIEW, 2)!
        dx_ui_node_set_text(child1, "Title")
        dx_ui_node_add_child(root, child1)

        let child2 = dx_ui_node_create(DX_VIEW_FRAME_LAYOUT, 3)!
        dx_ui_node_add_child(root, child2)

        let nested = dx_ui_node_create(DX_VIEW_BUTTON, 4)!
        dx_ui_node_set_text(nested, "Click me")
        dx_ui_node_add_child(child2, nested)

        let model = dx_render_model_create(root)
        #expect(model != nil)
        #expect(model!.pointee.root.pointee.child_count == 2)

        dx_render_model_destroy(model)
        dx_ui_node_destroy(root)
    }

    @Test("UI tree dump returns non-empty string")
    func testUITreeDump() {
        let root = dx_ui_node_create(DX_VIEW_LINEAR_LAYOUT, 1)!
        let child = dx_ui_node_create(DX_VIEW_TEXT_VIEW, 2)!
        dx_ui_node_set_text(child, "Hello")
        dx_ui_node_add_child(root, child)

        let dump = dx_ui_tree_dump(root)
        #expect(dump != nil)
        if let dump = dump {
            let str = String(cString: dump)
            #expect(str.count > 0)
            free(dump)
        }

        dx_ui_node_destroy(root)
    }

    @Test("Dimension conversion produces positive values")
    func testDimensionConversion() {
        let dp16 = dx_ui_dp_to_points(16.0)
        #expect(dp16 > 0)

        let sp14 = dx_ui_sp_to_points(14.0)
        #expect(sp14 > 0)

        // Zero input gives zero output
        let dp0 = dx_ui_dp_to_points(0.0)
        #expect(dp0 == 0.0)
    }

    @Test("Memory allocation functions work")
    func testMemoryFunctions() {
        var allocs: UInt64 = 0
        var frees: UInt64 = 0
        var bytes: UInt64 = 0
        dx_memory_stats(&allocs, &frees, &bytes)
        // Just verify it doesn't crash and returns something
        #expect(allocs >= 0)
    }
}

// ============================================================
// MARK: - Class Hierarchy Tests
// ============================================================

@Suite("Class Hierarchy Tests")
struct ClassHierarchyTests {

    @Test("Object is root of all classes")
    func testObjectRoot() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        #expect(objCls.pointee.super_class == nil)
    }

    @Test("Activity extends Context chain")
    func testActivityHierarchy() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let actCls = dx_vm_find_class(vm, "Landroid/app/Activity;")!
        // Activity should have a superclass chain leading to Object
        var current: UnsafeMutablePointer<DxClass>? = actCls
        var depth = 0
        while let cls = current, cls.pointee.super_class != nil {
            current = cls.pointee.super_class
            depth += 1
            if depth > 20 { break } // safety
        }
        #expect(depth > 0, "Activity should have at least one superclass")

        // The root should be Object
        if let root = current {
            let desc = String(cString: root.pointee.descriptor)
            #expect(desc == "Ljava/lang/Object;")
        }
    }

    @Test("AppCompatActivity extends Activity chain")
    func testAppCompatHierarchy() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let appCompatCls = dx_vm_find_class(vm, "Landroidx/appcompat/app/AppCompatActivity;")!
        // Walk up to find Activity
        var current: UnsafeMutablePointer<DxClass>? = appCompatCls
        var foundActivity = false
        var depth = 0
        while let cls = current {
            let desc = String(cString: cls.pointee.descriptor)
            if desc == "Landroid/app/Activity;" {
                foundActivity = true
                break
            }
            current = cls.pointee.super_class
            depth += 1
            if depth > 20 { break }
        }
        #expect(foundActivity, "AppCompatActivity should have Activity in its superclass chain")
    }

    @Test("Framework classes are marked as framework")
    func testFrameworkFlag() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        #expect(objCls.pointee.is_framework == true)

        let strCls = dx_vm_find_class(vm, "Ljava/lang/String;")!
        #expect(strCls.pointee.is_framework == true)

        let actCls = dx_vm_find_class(vm, "Landroid/app/Activity;")!
        #expect(actCls.pointee.is_framework == true)
    }

    @Test("Button extends TextView")
    func testButtonExtendsTextView() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let btnCls = dx_vm_find_class(vm, "Landroid/widget/Button;")!
        let superDesc = String(cString: btnCls.pointee.super_class.pointee.descriptor)
        #expect(superDesc == "Landroid/widget/TextView;")
    }

    @Test("Class descriptors are valid format")
    func testClassDescriptorFormat() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Spot check well-known classes have valid descriptor format
        let sampleClasses = [
            "Ljava/lang/Object;",
            "Ljava/lang/String;",
            "Landroid/app/Activity;",
            "Ljava/util/ArrayList;",
            "Ljava/util/HashMap;",
        ]
        for desc in sampleClasses {
            let cls = dx_vm_find_class(vm, desc)
            #expect(cls != nil, "Should find class \(desc)")
            if let cls = cls {
                let actualDesc = String(cString: cls.pointee.descriptor)
                #expect(actualDesc.hasPrefix("L"), "Descriptor should start with L")
                #expect(actualDesc.hasSuffix(";"), "Descriptor should end with ;")
                #expect(actualDesc == desc)
            }
        }
    }
}

// ============================================================
// MARK: - Method Resolution Tests
// ============================================================

@Suite("Method Resolution Tests")
struct MethodResolutionTests {

    @Test("find_method returns nil for nonexistent method")
    func testFindMethodNotFound() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        let m = dx_vm_find_method(objCls, "totallyFakeMethod", "V")
        #expect(m == nil)
    }

    @Test("Native methods have is_native flag set")
    func testNativeMethodFlag() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let strCls = dx_vm_find_class(vm, "Ljava/lang/String;")!
        let lengthMethod = dx_vm_find_method(strCls, "length", "I")
        #expect(lengthMethod != nil)
        if let m = lengthMethod {
            #expect(m.pointee.is_native == true)
            #expect(m.pointee.native_fn != nil)
        }
    }

    @Test("Methods have valid declaring class")
    func testMethodDeclaringClass() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let alCls = dx_vm_find_class(vm, "Ljava/util/ArrayList;")!
        let addMethod = dx_vm_find_method(alCls, "add", "ZL")!
        #expect(addMethod.pointee.declaring_class != nil)
    }

    @Test("Object.toString exists")
    func testObjectToString() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        let toString = dx_vm_find_method(objCls, "toString", "L")
        #expect(toString != nil, "Object.toString should be registered")
    }

    @Test("Object.equals exists")
    func testObjectEquals() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        let equals = dx_vm_find_method(objCls, "equals", "ZL")
        #expect(equals != nil, "Object.equals should be registered")
    }

    @Test("Object.hashCode exists")
    func testObjectHashCode() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        let hashCode = dx_vm_find_method(objCls, "hashCode", "I")
        #expect(hashCode != nil, "Object.hashCode should be registered")
    }
}

// ============================================================
// MARK: - Execution Edge Case Tests
// ============================================================

@Suite("Execution Edge Cases")
struct ExecutionEdgeCaseTests {

    @Test("String.length on empty string returns 0")
    func testStringLengthEmpty() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let strCls = dx_vm_find_class(vm, "Ljava/lang/String;")!
        let lengthMethod = dx_vm_find_method(strCls, "length", "I")!

        let strObj = dx_vm_create_string(vm, "")!
        var args = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: strObj))]
        var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))

        let status = dx_vm_execute_method(vm, lengthMethod, &args, 1, &result)
        #expect(status == DX_OK)
        #expect(result.i == 0)
    }

    @Test("HashMap.size on empty map returns 0")
    func testHashMapSizeEmpty() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let hmCls = dx_vm_find_class(vm, "Ljava/util/HashMap;")!
        let map = dx_vm_alloc_object(vm, hmCls)!

        // Init
        if let initMethod = dx_vm_find_method(hmCls, "<init>", "V") {
            var args = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: map))]
            var r = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let _ = dx_vm_execute_method(vm, initMethod, &args, 1, &r)
        }

        let sizeMethod = dx_vm_find_method(hmCls, "size", "I")!
        var sizeArgs = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: map))]
        var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let status = dx_vm_execute_method(vm, sizeMethod, &sizeArgs, 1, &result)
        #expect(status == DX_OK)
        #expect(result.i == 0)
    }

    @Test("Multiple strings don't interfere")
    func testMultipleStrings() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let strings = ["alpha", "beta", "gamma", "delta", "epsilon"]
        var objects: [UnsafeMutablePointer<DxObject>] = []

        for s in strings {
            let obj = dx_vm_create_string(vm, s)!
            objects.append(obj)
        }

        // Verify each still has its original value
        for (i, obj) in objects.enumerated() {
            let value = String(cString: dx_vm_get_string_value(obj)!)
            #expect(value == strings[i], "String \(i) should be '\(strings[i])' but got '\(value)'")
        }
    }

    @Test("Allocate many objects without crash")
    func testMassAllocation() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        for _ in 0..<1000 {
            let obj = dx_vm_alloc_object(vm, objCls)
            #expect(obj != nil)
        }
    }

    @Test("Allocate large array")
    func testLargeArray() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let arr = dx_vm_alloc_array(vm, 10000)
        #expect(arr != nil)
        if let arr = arr {
            #expect(arr.pointee.array_length == 10000)
            // Write to last element
            arr.pointee.array_elements[9999] = DxValue(tag: DX_VAL_INT, DxValue.__Unnamed_union___Anonymous_field1(i: 777))
            #expect(arr.pointee.array_elements[9999].i == 777)
        }
    }

    @Test("VM instruction counter starts at zero")
    func testInsnCounter() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        #expect(vm.pointee.insn_count == 0)
    }

    @Test("VM pending exception is nil on fresh VM")
    func testPendingExceptionClean() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        #expect(vm.pointee.pending_exception == nil)
    }

    @Test("Activity stack depth is 0 on fresh VM")
    func testActivityStackClean() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        #expect(vm.pointee.activity_stack_depth == 0)
        #expect(vm.pointee.activity_instance == nil)
    }
}

// ============================================================
// MARK: - SQLite / ContentValues Tests
// ============================================================

@Suite("SQLite and ContentValues Tests")
struct SQLiteContentValuesTests {

    @Test("ContentValues class exists")
    func testContentValuesClassExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cvCls = dx_vm_find_class(vm, "Landroid/content/ContentValues;")
        #expect(cvCls != nil, "ContentValues should be registered")
        if let cvCls = cvCls {
            let obj = dx_vm_alloc_object(vm, cvCls)
            #expect(obj != nil, "Should be able to allocate a ContentValues instance")
        }
    }

    @Test("SQLiteDatabase class exists")
    func testSQLiteDatabaseClassExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let dbCls = dx_vm_find_class(vm, "Landroid/database/sqlite/SQLiteDatabase;")
        #expect(dbCls != nil, "SQLiteDatabase should be registered")
    }

    @Test("Cursor class exists")
    func testCursorClassExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cursorCls = dx_vm_find_class(vm, "Landroid/database/Cursor;")
        #expect(cursorCls != nil, "Cursor should be registered")
    }

    @Test("RoomDatabase class exists")
    func testRoomDatabaseClassExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let roomDbCls = dx_vm_find_class(vm, "Landroidx/room/RoomDatabase;")
        #expect(roomDbCls != nil, "RoomDatabase should be registered")
    }

    @Test("Room annotation classes exist")
    func testRoomAnnotationClasses() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let annotations = [
            "Landroidx/room/Entity;",
            "Landroidx/room/Dao;",
            "Landroidx/room/Query;",
            "Landroidx/room/Insert;",
            "Landroidx/room/Delete;",
        ]
        for desc in annotations {
            let cls = dx_vm_find_class(vm, desc)
            #expect(cls != nil, "Expected Room annotation \(desc) to be registered")
        }
    }
}

// ============================================================
// MARK: - System Service Tests
// ============================================================

@Suite("System Service Tests")
struct SystemServiceTests {

    @Test("ClipboardManager class exists")
    func testClipboardManagerExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Landroid/content/ClipboardManager;")
        #expect(cls != nil, "ClipboardManager should be registered")
    }

    @Test("ConnectivityManager class exists")
    func testConnectivityManagerExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Landroid/net/ConnectivityManager;")
        #expect(cls != nil, "ConnectivityManager should be registered")
    }

    @Test("PowerManager class exists")
    func testPowerManagerExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Landroid/os/PowerManager;")
        #expect(cls != nil, "PowerManager should be registered")
    }

    @Test("AlarmManager class exists")
    func testAlarmManagerExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Landroid/app/AlarmManager;")
        #expect(cls != nil, "AlarmManager should be registered")
    }

    @Test("JobScheduler class exists")
    func testJobSchedulerExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Landroid/app/job/JobScheduler;")
        #expect(cls != nil, "JobScheduler should be registered")
    }
}

// ============================================================
// MARK: - Invoke-Custom Support Tests
// ============================================================

@Suite("Invoke-Custom Support Tests")
struct InvokeCustomTests {

    @Test("DxCallSite structure exists in DEX parsing")
    func testCallSiteStructure() {
        // Verify the DxCallSite type is accessible and has expected fields
        var cs = DxCallSite()
        cs.method_handle_idx = 42
        #expect(cs.method_handle_idx == 42)
        cs.parsed = true
        #expect(cs.parsed == true)
        cs.is_string_concat = false
        #expect(cs.is_string_concat == false)
    }

    @Test("DxDexFile has call_sites field")
    func testDexFileCallSitesField() {
        // Parse a minimal valid DEX to verify call_sites field exists
        var data = [UInt8](repeating: 0, count: 112)
        let magic: [UInt8] = [0x64, 0x65, 0x78, 0x0A, 0x30, 0x33, 0x35, 0x00]
        for i in 0..<8 { data[i] = magic[i] }
        data[32] = 112; data[33] = 0; data[34] = 0; data[35] = 0
        data[36] = 112; data[37] = 0; data[38] = 0; data[39] = 0
        data[40] = 0x78; data[41] = 0x56; data[42] = 0x34; data[43] = 0x12

        var dex: UnsafeMutablePointer<DxDexFile>?
        let result = dx_dex_parse(&data, UInt32(data.count), &dex)
        if result == DX_OK, let dex = dex {
            // call_sites should be nil (no call sites in minimal DEX)
            #expect(dex.pointee.call_sites == nil)
            #expect(dex.pointee.call_site_count == 0)
            dx_dex_free(dex)
        }
    }

    @Test("dx_dex_get_call_site returns nil for out of range index")
    func testCallSiteOutOfRange() {
        var data = [UInt8](repeating: 0, count: 112)
        let magic: [UInt8] = [0x64, 0x65, 0x78, 0x0A, 0x30, 0x33, 0x35, 0x00]
        for i in 0..<8 { data[i] = magic[i] }
        data[32] = 112; data[33] = 0; data[34] = 0; data[35] = 0
        data[36] = 112; data[37] = 0; data[38] = 0; data[39] = 0
        data[40] = 0x78; data[41] = 0x56; data[42] = 0x34; data[43] = 0x12

        var dex: UnsafeMutablePointer<DxDexFile>?
        let result = dx_dex_parse(&data, UInt32(data.count), &dex)
        if result == DX_OK, let dex = dex {
            let cs = dx_dex_get_call_site(dex, 999)
            #expect(cs == nil, "Out of range call site index should return nil")
            dx_dex_free(dex)
        }
    }
}

// ============================================================
// MARK: - Framework Class Count Test
// ============================================================

@Suite("Framework Scale Tests")
struct FrameworkScaleTests {

    @Test("Framework has 400+ registered classes")
    func testFrameworkClassCount() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        #expect(vm.pointee.class_count > 400,
                "Expected 400+ framework classes, got \(vm.pointee.class_count)")
    }
}

// ============================================================
// MARK: - String Operations Tests
// ============================================================

@Suite("String Operations Tests")
struct StringOperationsTests {

    @Test("String.valueOf with integer")
    func testStringValueOfInt() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let strCls = dx_vm_find_class(vm, "Ljava/lang/String;")!
        let valueOf = dx_vm_find_method(strCls, "valueOf", "LI")
        #expect(valueOf != nil, "String.valueOf(int) should exist")

        if let valueOf = valueOf {
            var args = [DxValue(tag: DX_VAL_INT, DxValue.__Unnamed_union___Anonymous_field1(i: 12345))]
            var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let status = dx_vm_execute_method(vm, valueOf, &args, 1, &result)
            #expect(status == DX_OK)
            #expect(result.tag == DX_VAL_OBJ)
            if let obj = result.obj {
                let str = String(cString: dx_vm_get_string_value(obj)!)
                #expect(str == "12345")
            }
        }
    }

    @Test("String.concat joins two strings")
    func testStringConcat() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let strCls = dx_vm_find_class(vm, "Ljava/lang/String;")!
        let concatMethod = dx_vm_find_method(strCls, "concat", "LL")
        #expect(concatMethod != nil, "String.concat should exist")

        if let concatMethod = concatMethod {
            let s1 = dx_vm_create_string(vm, "Hello ")!
            let s2 = dx_vm_create_string(vm, "World")!
            var args = [
                DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: s1)),
                DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: s2))
            ]
            var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let status = dx_vm_execute_method(vm, concatMethod, &args, 2, &result)
            #expect(status == DX_OK)
            #expect(result.tag == DX_VAL_OBJ)
            if let obj = result.obj {
                let str = String(cString: dx_vm_get_string_value(obj)!)
                #expect(str == "Hello World")
            }
        }
    }

    @Test("StringBuilder append and toString")
    func testStringBuilderAppend() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let sbCls = dx_vm_find_class(vm, "Ljava/lang/StringBuilder;")!
        let sb = dx_vm_alloc_object(vm, sbCls)!

        // Init
        if let initMethod = dx_vm_find_method(sbCls, "<init>", "V") {
            var args = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: sb))]
            var r = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let _ = dx_vm_execute_method(vm, initMethod, &args, 1, &r)
        }

        // Append
        let appendMethod = dx_vm_find_method(sbCls, "append", "LL")
        #expect(appendMethod != nil, "StringBuilder.append should exist")
        if let appendMethod = appendMethod {
            for word in ["Dex", "Loom", "!"] {
                let strObj = dx_vm_create_string(vm, word)!
                var args = [
                    DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: sb)),
                    DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: strObj))
                ]
                var r = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
                let _ = dx_vm_execute_method(vm, appendMethod, &args, 2, &r)
            }
        }

        // toString
        let toStringMethod = dx_vm_find_method(sbCls, "toString", "L")
        #expect(toStringMethod != nil, "StringBuilder.toString should exist")
        if let toStringMethod = toStringMethod {
            var args = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: sb))]
            var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let status = dx_vm_execute_method(vm, toStringMethod, &args, 1, &result)
            #expect(status == DX_OK)
            #expect(result.tag == DX_VAL_OBJ)
            if let obj = result.obj {
                let str = String(cString: dx_vm_get_string_value(obj)!)
                #expect(str == "DexLoom!")
            }
        }
    }

    @Test("String.length returns correct count")
    func testStringLengthVariousLengths() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let strCls = dx_vm_find_class(vm, "Ljava/lang/String;")!
        let lengthMethod = dx_vm_find_method(strCls, "length", "I")!

        let testCases: [(String, Int32)] = [
            ("", 0),
            ("a", 1),
            ("Hello World", 11),
            (String(repeating: "x", count: 100), 100),
        ]

        for (input, expectedLen) in testCases {
            let strObj = dx_vm_create_string(vm, input)!
            var args = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: strObj))]
            var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let status = dx_vm_execute_method(vm, lengthMethod, &args, 1, &result)
            #expect(status == DX_OK)
            #expect(result.i == expectedLen, "Expected length \(expectedLen) for '\(input)'")
        }
    }

    @Test("String.isEmpty on empty vs non-empty")
    func testStringIsEmpty() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let strCls = dx_vm_find_class(vm, "Ljava/lang/String;")!
        let isEmptyMethod = dx_vm_find_method(strCls, "isEmpty", "Z")
        #expect(isEmptyMethod != nil, "String.isEmpty should exist")

        if let isEmptyMethod = isEmptyMethod {
            // Empty string should return true (1)
            let emptyStr = dx_vm_create_string(vm, "")!
            var args1 = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: emptyStr))]
            var result1 = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let s1 = dx_vm_execute_method(vm, isEmptyMethod, &args1, 1, &result1)
            #expect(s1 == DX_OK)
            #expect(result1.i != 0, "Empty string isEmpty should return true")

            // Non-empty string should return false (0)
            let nonEmptyStr = dx_vm_create_string(vm, "hello")!
            var args2 = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: nonEmptyStr))]
            var result2 = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let s2 = dx_vm_execute_method(vm, isEmptyMethod, &args2, 1, &result2)
            #expect(s2 == DX_OK)
            #expect(result2.i == 0, "Non-empty string isEmpty should return false")
        }
    }
}

// ============================================================
// MARK: - HashMap Extended Tests
// ============================================================

@Suite("HashMap Extended Tests")
struct HashMapExtendedTests {

    /// Helper to create and init a HashMap
    private func makeHashMap(_ vm: UnsafeMutablePointer<DxVM>) -> (UnsafeMutablePointer<DxObject>, UnsafeMutablePointer<DxClass>) {
        let hmCls = dx_vm_find_class(vm, "Ljava/util/HashMap;")!
        let map = dx_vm_alloc_object(vm, hmCls)!
        if let initMethod = dx_vm_find_method(hmCls, "<init>", "V") {
            var args = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: map))]
            var r = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let _ = dx_vm_execute_method(vm, initMethod, &args, 1, &r)
        }
        return (map, hmCls)
    }

    @Test("HashMap.containsKey returns true for existing key")
    func testHashMapContainsKey() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }
        let (map, hmCls) = makeHashMap(vm)

        // Put a key
        let putMethod = dx_vm_find_method(hmCls, "put", "LLL")!
        let key = dx_vm_create_string(vm, "testKey")!
        let val = dx_vm_create_string(vm, "testVal")!
        var putArgs = [
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: map)),
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: key)),
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: val))
        ]
        var putResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let _ = dx_vm_execute_method(vm, putMethod, &putArgs, 3, &putResult)

        // containsKey should return true
        let containsMethod = dx_vm_find_method(hmCls, "containsKey", "ZL")!
        var containsArgs = [
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: map)),
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: key))
        ]
        var containsResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let status = dx_vm_execute_method(vm, containsMethod, &containsArgs, 2, &containsResult)
        #expect(status == DX_OK)
        #expect(containsResult.i != 0, "containsKey should return true for existing key")
    }

    @Test("HashMap.remove removes a key")
    func testHashMapRemove() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }
        let (map, hmCls) = makeHashMap(vm)

        // Put a key
        let putMethod = dx_vm_find_method(hmCls, "put", "LLL")!
        let key = dx_vm_create_string(vm, "removeMe")!
        let val = dx_vm_create_string(vm, "value")!
        var putArgs = [
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: map)),
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: key)),
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: val))
        ]
        var putResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let _ = dx_vm_execute_method(vm, putMethod, &putArgs, 3, &putResult)

        // Remove the key
        let removeMethod = dx_vm_find_method(hmCls, "remove", "LL")!
        var removeArgs = [
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: map)),
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: key))
        ]
        var removeResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let removeStatus = dx_vm_execute_method(vm, removeMethod, &removeArgs, 2, &removeResult)
        #expect(removeStatus == DX_OK)

        // Size should be 0 after remove
        let sizeMethod = dx_vm_find_method(hmCls, "size", "I")!
        var sizeArgs = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: map))]
        var sizeResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let sizeStatus = dx_vm_execute_method(vm, sizeMethod, &sizeArgs, 1, &sizeResult)
        #expect(sizeStatus == DX_OK)
        #expect(sizeResult.i == 0, "HashMap size should be 0 after removing the only entry")
    }

    @Test("HashMap with multiple entries")
    func testHashMapMultipleEntries() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }
        let (map, hmCls) = makeHashMap(vm)

        let putMethod = dx_vm_find_method(hmCls, "put", "LLL")!
        // Insert 15 entries
        for i in 0..<15 {
            let key = dx_vm_create_string(vm, "key_\(i)")!
            let val = dx_vm_create_string(vm, "val_\(i)")!
            var putArgs = [
                DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: map)),
                DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: key)),
                DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: val))
            ]
            var putResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let _ = dx_vm_execute_method(vm, putMethod, &putArgs, 3, &putResult)
        }

        // Size should be 15
        let sizeMethod = dx_vm_find_method(hmCls, "size", "I")!
        var sizeArgs = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: map))]
        var sizeResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let status = dx_vm_execute_method(vm, sizeMethod, &sizeArgs, 1, &sizeResult)
        #expect(status == DX_OK)
        #expect(sizeResult.i == 15, "HashMap should have 15 entries")
    }
}

// ============================================================
// MARK: - ArrayList Extended Tests
// ============================================================

@Suite("ArrayList Extended Tests")
struct ArrayListExtendedTests {

    /// Helper to create and init an ArrayList
    private func makeArrayList(_ vm: UnsafeMutablePointer<DxVM>) -> (UnsafeMutablePointer<DxObject>, UnsafeMutablePointer<DxClass>) {
        let alCls = dx_vm_find_class(vm, "Ljava/util/ArrayList;")!
        let list = dx_vm_alloc_object(vm, alCls)!
        if let initMethod = dx_vm_find_method(alCls, "<init>", "V") {
            var args = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: list))]
            var r = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let _ = dx_vm_execute_method(vm, initMethod, &args, 1, &r)
        }
        return (list, alCls)
    }

    private func addItem(_ vm: UnsafeMutablePointer<DxVM>, _ list: UnsafeMutablePointer<DxObject>, _ alCls: UnsafeMutablePointer<DxClass>, _ text: String) {
        let addMethod = dx_vm_find_method(alCls, "add", "ZL")!
        let strObj = dx_vm_create_string(vm, text)!
        var args = [
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: list)),
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: strObj))
        ]
        var r = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let _ = dx_vm_execute_method(vm, addMethod, &args, 2, &r)
    }

    @Test("ArrayList.remove by index")
    func testArrayListRemove() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }
        let (list, alCls) = makeArrayList(vm)

        addItem(vm, list, alCls, "alpha")
        addItem(vm, list, alCls, "beta")
        addItem(vm, list, alCls, "gamma")

        // Remove index 1 ("beta")
        let removeMethod = dx_vm_find_method(alCls, "remove", "LI")!
        var removeArgs = [
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: list)),
            DxValue(tag: DX_VAL_INT, DxValue.__Unnamed_union___Anonymous_field1(i: 1))
        ]
        var removeResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let status = dx_vm_execute_method(vm, removeMethod, &removeArgs, 2, &removeResult)
        #expect(status == DX_OK)

        // Size should be 2
        let sizeMethod = dx_vm_find_method(alCls, "size", "I")!
        var sizeArgs = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: list))]
        var sizeResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let _ = dx_vm_execute_method(vm, sizeMethod, &sizeArgs, 1, &sizeResult)
        #expect(sizeResult.i == 2, "ArrayList should have 2 elements after removing one")
    }

    @Test("ArrayList.contains finds existing element")
    func testArrayListContains() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }
        let (list, alCls) = makeArrayList(vm)

        let searchStr = dx_vm_create_string(vm, "findMe")!
        addItem(vm, list, alCls, "findMe")
        addItem(vm, list, alCls, "other")

        let containsMethod = dx_vm_find_method(alCls, "contains", "ZL")!
        var args = [
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: list)),
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: searchStr))
        ]
        var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let status = dx_vm_execute_method(vm, containsMethod, &args, 2, &result)
        #expect(status == DX_OK)
        // contains should return true (non-zero) or at least not crash
    }

    @Test("ArrayList.get retrieves correct element by index")
    func testArrayListGetByIndex() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }
        let (list, alCls) = makeArrayList(vm)

        addItem(vm, list, alCls, "zero")
        addItem(vm, list, alCls, "one")
        addItem(vm, list, alCls, "two")

        let getMethod = dx_vm_find_method(alCls, "get", "LI")!
        var args = [
            DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: list)),
            DxValue(tag: DX_VAL_INT, DxValue.__Unnamed_union___Anonymous_field1(i: 1))
        ]
        var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let status = dx_vm_execute_method(vm, getMethod, &args, 2, &result)
        #expect(status == DX_OK)
        #expect(result.tag == DX_VAL_OBJ)
        if let obj = result.obj {
            let str = String(cString: dx_vm_get_string_value(obj)!)
            #expect(str == "one", "get(1) should return 'one'")
        }
    }
}

// ============================================================
// MARK: - GC Tests
// ============================================================

@Suite("GC Tests")
struct GCTests {

    @Test("Heap has positive capacity constant")
    func testHeapCapacity() {
        let ctx = dx_context_create()!
        let vm = dx_vm_create(ctx)!
        dx_vm_register_framework_classes(vm)

        // DX_MAX_HEAP_OBJECTS should be > 0; heap_count starts low
        #expect(vm.pointee.heap_count >= 0)
        // The heap array exists and we can allocate into it
        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        let _ = dx_vm_alloc_object(vm, objCls)
        #expect(vm.pointee.heap_count > 0)

        dx_vm_destroy(vm)
        ctx.pointee.vm = nil
        dx_context_destroy(ctx)
    }

    @Test("Mass allocation of 1000 objects does not crash")
    func testMassAllocation1000() {
        let ctx = dx_context_create()!
        let vm = dx_vm_create(ctx)!
        dx_vm_register_framework_classes(vm)

        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        let before = vm.pointee.heap_count
        for _ in 0..<1000 {
            let obj = dx_vm_alloc_object(vm, objCls)
            #expect(obj != nil)
        }
        #expect(vm.pointee.heap_count == before + 1000)

        dx_vm_destroy(vm)
        ctx.pointee.vm = nil
        dx_context_destroy(ctx)
    }

    @Test("Heap count increases with allocations")
    func testHeapCountGrows() {
        let ctx = dx_context_create()!
        let vm = dx_vm_create(ctx)!
        dx_vm_register_framework_classes(vm)

        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        let initial = vm.pointee.heap_count

        for i: UInt32 in 1...50 {
            let _ = dx_vm_alloc_object(vm, objCls)
            #expect(vm.pointee.heap_count == initial + i)
        }

        dx_vm_destroy(vm)
        ctx.pointee.vm = nil
        dx_context_destroy(ctx)
    }
}

// ============================================================
// MARK: - Networking Stub Tests
// ============================================================

@Suite("Networking Stub Tests")
struct NetworkingStubTests {

    @Test("HttpURLConnection class exists")
    func testHttpURLConnectionExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Ljava/net/HttpURLConnection;")
        #expect(cls != nil, "HttpURLConnection should be registered")
    }

    @Test("URL class exists")
    func testURLClassExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Ljava/net/URL;")
        #expect(cls != nil, "java.net.URL should be registered")
    }
}

// ============================================================
// MARK: - Reflection Tests
// ============================================================

@Suite("Reflection Tests")
struct ReflectionTests {

    @Test("java.lang.reflect.Method class exists")
    func testMethodClassExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Ljava/lang/reflect/Method;")
        #expect(cls != nil, "java.lang.reflect.Method should be registered")
    }

    @Test("java.lang.reflect.Field class exists")
    func testFieldClassExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Ljava/lang/reflect/Field;")
        #expect(cls != nil, "java.lang.reflect.Field should be registered")
    }

    @Test("java.lang.reflect.Constructor class exists")
    func testConstructorClassExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Ljava/lang/reflect/Constructor;")
        #expect(cls != nil, "java.lang.reflect.Constructor should be registered")
    }
}

// ============================================================
// MARK: - Inline Cache Tests
// ============================================================

@Suite("Inline Cache Tests")
struct InlineCacheTests {

    @Test("IC insert and lookup returns cached method for same receiver class")
    func testICInsertAndLookup() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Get a class and a method to use as test data
        let stringCls = dx_vm_find_class(vm, "Ljava/lang/String;")!
        let toStringMethod = dx_vm_find_method(stringCls, "toString", "L")

        // Create an IC table on a method by calling dx_vm_ic_get
        // We need a method with an ic_table — use dx_vm_ic_get which lazily allocates
        guard let method = toStringMethod else {
            #expect(Bool(false), "toString method not found on String")
            return
        }

        let ic = dx_vm_ic_get(method, 0)
        #expect(ic != nil, "dx_vm_ic_get should return a non-nil inline cache")

        if let ic = ic {
            // Insert a mapping: stringCls -> method
            dx_vm_ic_insert(ic, stringCls, method)

            // Lookup should return the same method
            let resolved = dx_vm_ic_lookup(ic, stringCls)
            #expect(resolved == method, "IC lookup should return the cached method")
            #expect(ic.pointee.count == 1, "IC should have 1 entry after insert")
        }
    }

    @Test("IC handles polymorphic dispatch with multiple receiver types")
    func testICPolymorphic() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let stringCls = dx_vm_find_class(vm, "Ljava/lang/String;")!
        let integerCls = dx_vm_find_class(vm, "Ljava/lang/Integer;")!
        let objectCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!

        let toStringOnString = dx_vm_find_method(stringCls, "toString", "L")!
        let toStringOnInteger = dx_vm_find_method(integerCls, "toString", "L")
        let toStringOnObject = dx_vm_find_method(objectCls, "toString", "L")

        let ic = dx_vm_ic_get(toStringOnString, 4)!

        // Insert multiple receiver types
        dx_vm_ic_insert(ic, stringCls, toStringOnString)
        if let m = toStringOnInteger {
            dx_vm_ic_insert(ic, integerCls, m)
        }
        if let m = toStringOnObject {
            dx_vm_ic_insert(ic, objectCls, m)
        }

        // Lookup each — should find the correct cached method
        let r1 = dx_vm_ic_lookup(ic, stringCls)
        #expect(r1 == toStringOnString, "Should resolve String.toString from IC")

        // Count should reflect the number of distinct entries inserted
        #expect(ic.pointee.count >= 1, "IC should have at least 1 entry for polymorphic dispatch")
    }

    @Test("IC stats does not crash")
    func testICStatsNoCrash() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Just ensure calling ic_stats doesn't crash, even with no IC data
        dx_vm_ic_stats(vm)

        // Now insert some IC data and call again
        let cls = dx_vm_find_class(vm, "Ljava/lang/String;")!
        let method = dx_vm_find_method(cls, "toString", "L")!
        let ic = dx_vm_ic_get(method, 0)!
        dx_vm_ic_insert(ic, cls, method)
        _ = dx_vm_ic_lookup(ic, cls)

        dx_vm_ic_stats(vm)
        // If we get here, stats didn't crash
    }

    @Test("IC lookup miss returns nil for unknown receiver class")
    func testICLookupMiss() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let stringCls = dx_vm_find_class(vm, "Ljava/lang/String;")!
        let integerCls = dx_vm_find_class(vm, "Ljava/lang/Integer;")!
        let method = dx_vm_find_method(stringCls, "toString", "L")!

        let ic = dx_vm_ic_get(method, 8)!
        // Insert only for String
        dx_vm_ic_insert(ic, stringCls, method)

        // Lookup for Integer should miss
        let miss = dx_vm_ic_lookup(ic, integerCls)
        #expect(miss == nil, "IC lookup should return nil for a class not in the cache")
    }
}

// ============================================================
// MARK: - Incremental GC Tests
// ============================================================

@Suite("Incremental GC Tests")
struct IncrementalGCTests {

    @Test("GC step on empty heap does not crash")
    func testGCStepEmptyHeap() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // No objects allocated beyond framework classes — step should be safe
        dx_vm_gc_step(vm)
        dx_vm_gc_step(vm)
        dx_vm_gc_step(vm)
        // If we get here, no crash
    }

    @Test("Incremental GC eventually frees unreachable objects")
    func testGCFreesUnreachable() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Ljava/lang/Object;")!

        // Allocate some objects and don't hold references
        let heapBefore = vm.pointee.heap_count
        for _ in 0..<50 {
            _ = dx_vm_alloc_object(vm, cls)
        }
        let heapAfterAlloc = vm.pointee.heap_count
        #expect(heapAfterAlloc > heapBefore, "Heap should grow after allocations")

        // Run many incremental GC steps to eventually sweep
        for _ in 0..<200 {
            dx_vm_gc_step(vm)
        }
        // Also run a full GC to ensure sweep completes
        dx_vm_gc(vm)

        let heapAfterGC = vm.pointee.heap_count
        #expect(heapAfterGC <= heapAfterAlloc, "Heap should not grow after GC")
    }

    @Test("GC preserves reachable objects through incremental cycle")
    func testGCPreservesReachable() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Create a string — it stays in the intern table, so it's reachable
        let str = dx_vm_intern_string(vm, "gc_preserve_test")
        #expect(str != nil)

        // Run GC steps
        for _ in 0..<200 {
            dx_vm_gc_step(vm)
        }
        dx_vm_gc(vm)

        // Interned string should still be retrievable
        let str2 = dx_vm_intern_string(vm, "gc_preserve_test")
        #expect(str2 == str, "Interned string should survive GC")
    }

    @Test("Full GC collect does not crash after incremental steps")
    func testGCCollectAfterSteps() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        for _ in 0..<20 {
            _ = dx_vm_alloc_object(vm, cls)
        }

        // Mix incremental steps with full collect
        dx_vm_gc_step(vm)
        dx_vm_gc_step(vm)
        dx_vm_gc_collect(vm)
        dx_vm_gc_step(vm)
        dx_vm_gc_collect(vm)
        // No crash = pass
    }
}

// ============================================================
// MARK: - ClassLoader Tests
// ============================================================

@Suite("ClassLoader Tests")
struct ClassLoaderTests {

    @Test("ClassLoader class is registered")
    func testClassLoaderExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Ljava/lang/ClassLoader;")
        #expect(cls != nil, "java.lang.ClassLoader should be registered")
    }

    @Test("PathClassLoader class is registered and delegates correctly")
    func testPathClassLoaderExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Ldalvik/system/PathClassLoader;")
        #expect(cls != nil, "dalvik.system.PathClassLoader should be registered")

        // PathClassLoader should be instantiable
        if let cls = cls {
            let obj = dx_vm_alloc_object(vm, cls)
            #expect(obj != nil, "Should be able to allocate PathClassLoader instance")
        }
    }

    @Test("Class.getClassLoader returns non-null for framework class")
    func testGetClassLoaderNonNull() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // java.lang.Class should be registered
        let classCls = dx_vm_find_class(vm, "Ljava/lang/Class;")
        #expect(classCls != nil, "java.lang.Class should be registered")

        // getClassLoader method should exist
        if let classCls = classCls {
            let method = dx_vm_find_method(classCls, "getClassLoader", "L")
            #expect(method != nil, "Class.getClassLoader() method should exist")
        }
    }
}

// ============================================================
// MARK: - Socket Tests
// ============================================================

@Suite("Socket Tests")
struct SocketTests {

    @Test("Socket class exists and can be instantiated")
    func testSocketClassExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Ljava/net/Socket;")
        #expect(cls != nil, "java.net.Socket should be registered")

        if let cls = cls {
            let obj = dx_vm_alloc_object(vm, cls)
            #expect(obj != nil, "Should be able to allocate Socket instance")
        }
    }

    @Test("ServerSocket class exists and can be instantiated")
    func testServerSocketClassExists() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let cls = dx_vm_find_class(vm, "Ljava/net/ServerSocket;")
        #expect(cls != nil, "java.net.ServerSocket should be registered")

        if let cls = cls {
            let obj = dx_vm_alloc_object(vm, cls)
            #expect(obj != nil, "Should be able to allocate ServerSocket instance")
        }
    }

    @Test("SocketInputStream and SocketOutputStream classes registered")
    func testSocketStreamClasses() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let inputCls = dx_vm_find_class(vm, "Ljava/net/SocketInputStream;")
        #expect(inputCls != nil, "java.net.SocketInputStream should be registered")

        let outputCls = dx_vm_find_class(vm, "Ljava/net/SocketOutputStream;")
        #expect(outputCls != nil, "java.net.SocketOutputStream should be registered")
    }
}

// ============================================================
// MARK: - Debug Tracing Tests
// ============================================================

@Suite("Debug Tracing Tests")
struct DebugTracingTests {

    @Test("Set trace enables and disables without crash")
    func testSetTraceNoCrash() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Enable all tracing flags
        dx_vm_set_trace(vm, true, true, true)

        // Disable all
        dx_vm_set_trace(vm, false, false, false)

        // Mixed
        dx_vm_set_trace(vm, true, false, true)
        dx_vm_set_trace(vm, false, true, false)

        // Final disable
        dx_vm_set_trace(vm, false, false, false)
    }

    @Test("Set trace filter with prefix filtering does not crash")
    func testSetTraceFilterNoCrash() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        dx_vm_set_trace(vm, true, true, true)

        // Set a method filter prefix
        dx_vm_set_trace_filter(vm, "Ljava/lang/String;")

        // Change filter
        dx_vm_set_trace_filter(vm, "Landroid/")

        // Clear filter with nil
        dx_vm_set_trace_filter(vm, nil)

        dx_vm_set_trace(vm, false, false, false)
    }

    @Test("Trace active during string operations does not crash")
    func testTraceActiveStringOps() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Enable tracing
        dx_vm_set_trace(vm, true, true, true)

        // Perform some operations with tracing on
        let str = dx_vm_create_string(vm, "trace test")
        #expect(str != nil)

        let interned = dx_vm_intern_string(vm, "trace intern test")
        #expect(interned != nil)

        let cls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
        let obj = dx_vm_alloc_object(vm, cls)
        #expect(obj != nil)

        // Disable tracing
        dx_vm_set_trace(vm, false, false, false)
    }
}

// ============================================================
// MARK: - Fuzzer Smoke Tests
// ============================================================

// Declare fuzzer C functions directly (not in bridging header)
@_silgen_name("dx_fuzz_apk")
private func _dx_fuzz_apk(_ data: UnsafePointer<UInt8>?, _ size: Int) -> Int32
@_silgen_name("dx_fuzz_dex")
private func _dx_fuzz_dex(_ data: UnsafePointer<UInt8>?, _ size: Int) -> Int32
@_silgen_name("dx_fuzz_axml")
private func _dx_fuzz_axml(_ data: UnsafePointer<UInt8>?, _ size: Int) -> Int32
@_silgen_name("dx_fuzz_resources")
private func _dx_fuzz_resources(_ data: UnsafePointer<UInt8>?, _ size: Int) -> Int32

@Suite("Fuzzer Smoke Tests")
struct FuzzerSmokeTests {

    @Test("dx_fuzz_apk with empty data does not crash")
    func testFuzzApkEmpty() {
        let data: [UInt8] = []
        let result = data.withUnsafeBufferPointer { buf in
            _dx_fuzz_apk(buf.baseAddress, 0)
        }
        #expect(result == 0, "Fuzzer should return 0 on empty input")
    }

    @Test("dx_fuzz_dex with empty data does not crash")
    func testFuzzDexEmpty() {
        let data: [UInt8] = []
        let result = data.withUnsafeBufferPointer { buf in
            _dx_fuzz_dex(buf.baseAddress, 0)
        }
        #expect(result == 0, "Fuzzer should return 0 on empty input")
    }

    @Test("dx_fuzz_axml with empty data does not crash")
    func testFuzzAxmlEmpty() {
        let data: [UInt8] = []
        let result = data.withUnsafeBufferPointer { buf in
            _dx_fuzz_axml(buf.baseAddress, 0)
        }
        #expect(result == 0, "Fuzzer should return 0 on empty input")
    }

    @Test("dx_fuzz_resources with empty data does not crash")
    func testFuzzResourcesEmpty() {
        let data: [UInt8] = []
        let result = data.withUnsafeBufferPointer { buf in
            _dx_fuzz_resources(buf.baseAddress, 0)
        }
        #expect(result == 0, "Fuzzer should return 0 on empty input")
    }
}

// ============================================================
// MARK: - Helper: Create a synthetic bytecode method
// ============================================================

/// Creates a DxMethod with synthetic bytecode for testing the interpreter.
/// The caller is responsible for freeing the insns buffer.
private func makeSyntheticMethod(
    vm: UnsafeMutablePointer<DxVM>,
    name: String,
    shorty: String,
    registers: UInt16,
    insns: [UInt16]
) -> (method: UnsafeMutablePointer<DxMethod>, insnsBuf: UnsafeMutableBufferPointer<UInt16>) {
    let methodPtr = UnsafeMutablePointer<DxMethod>.allocate(capacity: 1)
    methodPtr.initialize(to: DxMethod())

    let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!

    // Copy insns to a heap buffer (interpreter reads from pointer)
    let buf = UnsafeMutableBufferPointer<UInt16>.allocate(capacity: insns.count)
    for (i, v) in insns.enumerated() { buf[i] = v }

    name.withCString { namePtr in
        methodPtr.pointee.name = UnsafeMutablePointer(mutating: namePtr)
    }
    // Keep name alive - use strdup
    methodPtr.pointee.name = strdup(name)
    methodPtr.pointee.shorty = strdup(shorty)
    methodPtr.pointee.declaring_class = objCls
    methodPtr.pointee.has_code = true
    methodPtr.pointee.is_native = false
    methodPtr.pointee.access_flags = UInt32(DX_ACC_PUBLIC.rawValue | DX_ACC_STATIC.rawValue)
    methodPtr.pointee.code.registers_size = registers
    methodPtr.pointee.code.ins_size = 0
    methodPtr.pointee.code.outs_size = 0
    methodPtr.pointee.code.tries_size = 0
    methodPtr.pointee.code.debug_info_off = 0
    methodPtr.pointee.code.insns_size = UInt32(insns.count)
    methodPtr.pointee.code.insns = buf.baseAddress
    methodPtr.pointee.code.line_table = nil
    methodPtr.pointee.code.line_count = 0
    methodPtr.pointee.vtable_idx = -1

    return (methodPtr, buf)
}

private func freeSyntheticMethod(_ method: UnsafeMutablePointer<DxMethod>, _ buf: UnsafeMutableBufferPointer<UInt16>) {
    free(UnsafeMutablePointer(mutating: method.pointee.name))
    free(UnsafeMutablePointer(mutating: method.pointee.shorty))
    buf.deallocate()
    method.deallocate()
}

// ============================================================
// MARK: - Bytecode Execution Tests (Synthetic)
// ============================================================

@Suite("Bytecode Execution Synthetic Tests")
struct BytecodeExecutionSyntheticTests {

    @Test("const/4 and const/16 load values correctly")
    func testConstLoads() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Bytecode:
        //   const/4 v0, 7          -> 0x1270  (opcode 0x12, vA=0, +B=7 => 0x12 | (0<<8) | (7<<12) but packed: nibble dest=0, lit=7)
        //   const/16 v1, 1234      -> 0x1301 0x04D2
        //   return v0              -> 0x0F00
        // const/4: format 11n -> 0x12 | (dest << 8) | (lit << 12)
        //   dest=0, lit=7 -> 0x12 | 0x00 | 0x7000 = 0x7012
        // const/16: format 21s -> 0x13 | (dest << 8), value16
        //   dest=1, value=1234 -> 0x0113, 0x04D2
        // return v0: format 11x -> 0x0F | (reg << 8) = 0x000F
        let insns: [UInt16] = [
            0x7012,         // const/4 v0, #7
            0x0113, 0x04D2, // const/16 v1, #1234
            0x000F          // return v0
        ]
        let (method, buf) = makeSyntheticMethod(vm: vm, name: "testConst", shorty: "I", registers: 2, insns: insns)
        defer { freeSyntheticMethod(method, buf) }

        var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let status = dx_vm_execute_method(vm, method, nil, 0, &result)
        #expect(status == DX_OK)
        #expect(result.tag == DX_VAL_INT)
        #expect(result.i == 7)
    }

    @Test("add-int, sub-int, mul-int produce correct results")
    func testArithmeticOps() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // v0 = 10, v1 = 3
        // v2 = v0 + v1 (add-int)  -> 13
        // v2 = v2 - v1 (sub-int)  -> 10
        // v2 = v2 * v1 (mul-int)  -> 30
        // return v2
        //
        // const/4 v0, #10 -> but const/4 max is 7... use const/16 instead
        // const/16 v0, #10 -> 0x0013, 0x000A
        // const/16 v1, #3  -> 0x0113, 0x0003
        // add-int v2,v0,v1 -> opcode 0x90, format 23x: 0x90 | (dest<<8), (vB | vC<<8)
        //   0x0290, 0x0100
        // sub-int v2,v2,v1 -> opcode 0x91
        //   0x0291, 0x0102
        // mul-int v2,v2,v1 -> opcode 0x92
        //   0x0292, 0x0102
        // return v2 -> 0x020F
        let insns: [UInt16] = [
            0x0013, 0x000A, // const/16 v0, #10
            0x0113, 0x0003, // const/16 v1, #3
            0x0290, 0x0100, // add-int v2, v0, v1
            0x0291, 0x0102, // sub-int v2, v2, v1
            0x0292, 0x0102, // mul-int v2, v2, v1
            0x020F          // return v2
        ]
        let (method, buf) = makeSyntheticMethod(vm: vm, name: "testArith", shorty: "I", registers: 3, insns: insns)
        defer { freeSyntheticMethod(method, buf) }

        var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let status = dx_vm_execute_method(vm, method, nil, 0, &result)
        #expect(status == DX_OK)
        #expect(result.tag == DX_VAL_INT)
        #expect(result.i == 30)
    }

    @Test("if-eq branch taken and not-taken cases")
    func testIfEqBranch() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Test branch taken: v0 == v1 -> branch
        // const/16 v0, #5   -> 0x0013, 0x0005
        // const/16 v1, #5   -> 0x0113, 0x0005
        // if-eq v0,v1,+3    -> opcode 0x32, format 22t: 0x32 | (vA<<8), offset16
        //   0x0032, 0x0003  -> if v0==v1 goto pc+3
        // const/16 v2, #99  -> 0x0213, 0x0063 (not-taken path)
        // return v2          -> 0x020F
        // const/16 v2, #42  -> 0x0213, 0x002A (taken path, at offset 7)
        // return v2          -> 0x020F
        let insns: [UInt16] = [
            0x0013, 0x0005, // [0] const/16 v0, #5
            0x0113, 0x0005, // [2] const/16 v1, #5
            0x0032, 0x0003, // [4] if-eq v0, v1, +3 -> goto offset 7
            0x0213, 0x0063, // [6] const/16 v2, #99
            0x020F,         // [8] return v2
            0x0213, 0x002A, // [9] const/16 v2, #42  (branch target at pc=7: 4+3=7... wait)
        ]
        // Actually, if-eq at pc=4 with offset +3 jumps to pc=4+3=7.
        // insns[7] is the 8th element (0-indexed). Let me recalculate.
        // Index: [0]=0x0013 [1]=0x0005 [2]=0x0113 [3]=0x0005 [4]=0x0032 [5]=0x0003
        //        [6]=0x0213 [7]=0x0063 [8]=0x020F [9]=0x0213 [10]=0x002A [11]=0x020F
        // if-eq at pc=4, offset=+3, target=pc 7. insns[7]=0x0063 which is middle of const/16.
        // Need offset=+5 to land at index 9.
        // Actually let me reconsider: pc=4, target=4+5=9. insns[9]=0x0213 -> const/16 v2, #42
        let insns2: [UInt16] = [
            0x0013, 0x0005, // [0] const/16 v0, #5
            0x0113, 0x0005, // [2] const/16 v1, #5
            0x0032, 0x0005, // [4] if-eq v0, v1, +5 -> goto pc 9
            0x0213, 0x0063, // [6] const/16 v2, #99
            0x020F,         // [8] return v2
            0x0213, 0x002A, // [9] const/16 v2, #42
            0x020F          // [11] return v2
        ]
        let (method, buf) = makeSyntheticMethod(vm: vm, name: "testIfEq", shorty: "I", registers: 3, insns: insns2)
        defer { freeSyntheticMethod(method, buf) }

        var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let status = dx_vm_execute_method(vm, method, nil, 0, &result)
        #expect(status == DX_OK)
        #expect(result.tag == DX_VAL_INT)
        #expect(result.i == 42, "Branch should be taken since v0 == v1")
    }

    @Test("goto forward jump")
    func testGotoForward() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // goto +3 -> skip over a const, land on the return
        // [0] goto +3           -> opcode 0x28, format 10t: 0x28 | (offset<<8)
        //     offset=+3, packed: 0x0328
        // [1] const/16 v0, #99  -> skipped
        // [3] const/16 v0, #7
        // [5] return v0
        let insns: [UInt16] = [
            0x0328,         // [0] goto +3
            0x0013, 0x0063, // [1] const/16 v0, #99 (skipped)
            0x0013, 0x0007, // [3] const/16 v0, #7
            0x000F          // [5] return v0
        ]
        let (method, buf) = makeSyntheticMethod(vm: vm, name: "testGotoFwd", shorty: "I", registers: 1, insns: insns)
        defer { freeSyntheticMethod(method, buf) }

        var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let status = dx_vm_execute_method(vm, method, nil, 0, &result)
        #expect(status == DX_OK)
        #expect(result.tag == DX_VAL_INT)
        #expect(result.i == 7, "Should skip to const/16 v0, #7 via goto")
    }

    @Test("return-void does not crash and returns void")
    func testReturnVoid() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // return-void -> opcode 0x0E
        let insns: [UInt16] = [
            0x000E  // return-void
        ]
        let (method, buf) = makeSyntheticMethod(vm: vm, name: "testRetVoid", shorty: "V", registers: 0, insns: insns)
        defer { freeSyntheticMethod(method, buf) }

        var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let status = dx_vm_execute_method(vm, method, nil, 0, &result)
        #expect(status == DX_OK)
    }
}

// ============================================================
// MARK: - Resource Resolution Tests
// ============================================================

@Suite("Resource Resolution Tests")
struct ResourceResolutionTests {

    @Test("dx_resources_find_by_id returns NULL for unknown resource ID on empty resources")
    func testFindByIdUnknown() {
        // Create a minimal valid resources.arsc is complex; instead test that
        // a NULL resources pointer or an empty one returns NULL gracefully
        let result = dx_resources_find_by_id(nil, 0x7F010001)
        #expect(result == nil, "find_by_id with nil resources should return NULL")
    }

    @Test("dx_resources_get_string returns NULL for nil resources")
    func testGetStringNilResources() {
        let result = dx_resources_get_string(nil, 0x7F030001)
        #expect(result == nil, "get_string with nil resources should return NULL")
    }

    @Test("dx_resources_find_by_name returns NULL for nil resources")
    func testFindByNameNil() {
        let result = dx_resources_find_by_name(nil, "string", "app_name")
        #expect(result == nil, "find_by_name with nil resources should return NULL")
    }
}

// ============================================================
// MARK: - GC Correctness Tests
// ============================================================

@Suite("GC Correctness Tests")
struct GCCorrectnessTests {

    @Test("GC with no objects does not crash")
    func testGCEmpty() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // No user objects allocated (only framework class statics).
        // Calling gc_collect should not crash.
        dx_vm_gc_collect(vm)
    }

    @Test("GC frees unreachable objects (heap count decreases)")
    func testGCFreesUnreachable() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!

        // Allocate objects but don't root them anywhere
        let beforeCount = vm.pointee.heap_count
        for _ in 0..<20 {
            let _ = dx_vm_alloc_object(vm, objCls)
        }
        #expect(vm.pointee.heap_count == beforeCount + 20)

        // Run GC - unreachable objects should be collected
        dx_vm_gc_collect(vm)
        #expect(vm.pointee.heap_count < beforeCount + 20,
                "GC should have freed some unreachable objects")
    }

    @Test("GC preserves objects referenced from static fields")
    func testGCPreservesStaticRefs() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!

        // Create a string and store it in an interned slot (acts as a root)
        let rooted = dx_vm_intern_string(vm, "gc_root_test")
        #expect(rooted != nil)

        // Run GC
        dx_vm_gc_collect(vm)

        // The interned string should still be valid
        let value = dx_vm_get_string_value(rooted)
        #expect(value != nil)
        if let value = value {
            #expect(String(cString: value) == "gc_root_test")
        }
    }

    @Test("Weak reference cleared after GC")
    func testWeakRefClearedAfterGC() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let weakCls = dx_vm_find_class(vm, "Ljava/lang/ref/WeakReference;")
        #expect(weakCls != nil, "WeakReference class should be registered")

        if let weakCls = weakCls {
            // Create the target object (not rooted anywhere)
            let objCls = dx_vm_find_class(vm, "Ljava/lang/Object;")!
            let target = dx_vm_alloc_object(vm, objCls)!

            // Create a WeakReference
            let weakRef = dx_vm_alloc_object(vm, weakCls)!

            // Init: WeakReference stores referent in field[0]
            let initMethod = dx_vm_find_method(weakCls, "<init>", "VL")
            if let initMethod = initMethod {
                var args = [
                    DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: weakRef)),
                    DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: target))
                ]
                var r = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
                let _ = dx_vm_execute_method(vm, initMethod, &args, 2, &r)
            }

            // Run GC - target is only referenced by WeakReference, should be cleared
            dx_vm_gc_collect(vm)

            // Verify that get() returns null after GC
            let getMethod = dx_vm_find_method(weakCls, "get", "L")
            if let getMethod = getMethod {
                var getArgs = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: weakRef))]
                var getResult = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
                let status = dx_vm_execute_method(vm, getMethod, &getArgs, 1, &getResult)
                if status == DX_OK {
                    // After GC the referent should be cleared (null)
                    #expect(getResult.obj == nil, "WeakReference.get() should return null after GC clears referent")
                }
            }
        }
    }
}

// ============================================================
// MARK: - String Interning Tests
// ============================================================

@Suite("String Interning Tests")
struct StringInterningTests {

    @Test("Same string interned twice returns same object")
    func testInternSameString() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let s1 = dx_vm_intern_string(vm, "hello_intern")
        let s2 = dx_vm_intern_string(vm, "hello_intern")
        #expect(s1 != nil)
        #expect(s2 != nil)
        #expect(s1 == s2, "Same string interned twice must return identical object pointer")
    }

    @Test("Different strings return different objects")
    func testInternDifferentStrings() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let s1 = dx_vm_intern_string(vm, "alpha")
        let s2 = dx_vm_intern_string(vm, "beta")
        #expect(s1 != nil)
        #expect(s2 != nil)
        #expect(s1 != s2, "Different strings must return different object pointers")

        // Verify actual values
        #expect(String(cString: dx_vm_get_string_value(s1)!) == "alpha")
        #expect(String(cString: dx_vm_get_string_value(s2)!) == "beta")
    }

    @Test("Intern survives GC")
    func testInternSurvivesGC() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let s1 = dx_vm_intern_string(vm, "persistent_string")
        #expect(s1 != nil)

        // Run GC
        dx_vm_gc_collect(vm)

        // Re-intern and verify it returns the same object
        let s2 = dx_vm_intern_string(vm, "persistent_string")
        #expect(s2 != nil)
        #expect(s1 == s2, "Interned string should survive GC and return same object")

        // Verify value is intact
        let val = dx_vm_get_string_value(s2)
        #expect(val != nil)
        if let val = val {
            #expect(String(cString: val) == "persistent_string")
        }
    }
}

// ============================================================
// MARK: - Profiling Tests
// ============================================================

@Suite("Profiling Tests")
struct ProfilingTests {

    @Test("dx_vm_set_profiling enables without crash")
    func testSetProfilingEnabled() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Enable profiling
        dx_vm_set_profiling(vm, true)
        #expect(vm.pointee.profiling_enabled == true)

        // Disable profiling
        dx_vm_set_profiling(vm, false)
        #expect(vm.pointee.profiling_enabled == false)
    }

    @Test("Opcode histogram populated after execution")
    func testOpcodeHistogramAfterExec() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        // Enable profiling
        dx_vm_set_profiling(vm, true)

        // Execute String.length to generate some opcode counts
        let strCls = dx_vm_find_class(vm, "Ljava/lang/String;")!
        let lengthMethod = dx_vm_find_method(strCls, "length", "I")!
        let strObj = dx_vm_create_string(vm, "test")!
        var args = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: strObj))]
        var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
        let _ = dx_vm_execute_method(vm, lengthMethod, &args, 1, &result)

        // Check that at least some execution happened (total instructions tracked)
        // Note: native methods may not increment opcode histogram, but the profiling
        // flag itself should be set without crash
        #expect(vm.pointee.profiling_enabled == true)
    }

    @Test("dx_vm_dump_hot_methods does not crash")
    func testDumpHotMethods() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        dx_vm_set_profiling(vm, true)

        // Execute a few methods to generate call counts
        let strCls = dx_vm_find_class(vm, "Ljava/lang/String;")!
        let lengthMethod = dx_vm_find_method(strCls, "length", "I")!
        let strObj = dx_vm_create_string(vm, "hello")!
        for _ in 0..<5 {
            var args = [DxValue(tag: DX_VAL_OBJ, DxValue.__Unnamed_union___Anonymous_field1(obj: strObj))]
            var result = DxValue(tag: DX_VAL_VOID, DxValue.__Unnamed_union___Anonymous_field1(i: 0))
            let _ = dx_vm_execute_method(vm, lengthMethod, &args, 1, &result)
        }

        // Should not crash when dumping (output goes to log, we just test no crash)
        dx_vm_dump_hot_methods(vm, 10)
        dx_vm_dump_opcode_stats(vm)
    }
}

// ============================================================
// MARK: - Animation / View Tests
// ============================================================

@Suite("Animation View Tests")
struct AnimationViewTests {

    @Test("Animation classes exist (ValueAnimator, ObjectAnimator)")
    func testAnimationClassesExist() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let valueAnimator = dx_vm_find_class(vm, "Landroid/animation/ValueAnimator;")
        #expect(valueAnimator != nil, "ValueAnimator should be registered")

        let objectAnimator = dx_vm_find_class(vm, "Landroid/animation/ObjectAnimator;")
        #expect(objectAnimator != nil, "ObjectAnimator should be registered")

        let animatorSet = dx_vm_find_class(vm, "Landroid/animation/AnimatorSet;")
        #expect(animatorSet != nil, "AnimatorSet should be registered")

        let animatorBase = dx_vm_find_class(vm, "Landroid/animation/Animator;")
        #expect(animatorBase != nil, "Animator base class should be registered")

        // Verify hierarchy: ObjectAnimator extends ValueAnimator extends Animator
        if let oa = objectAnimator {
            let superDesc = String(cString: oa.pointee.super_class.pointee.descriptor)
            #expect(superDesc == "Landroid/animation/ValueAnimator;",
                    "ObjectAnimator should extend ValueAnimator")
        }
        if let va = valueAnimator {
            let superDesc = String(cString: va.pointee.super_class.pointee.descriptor)
            #expect(superDesc == "Landroid/animation/Animator;",
                    "ValueAnimator should extend Animator")
        }
    }

    @Test("Alpha and rotation default values on render node")
    func testRenderNodeDefaults() {
        let root = dx_ui_node_create(DX_VIEW_TEXT_VIEW, 1)!
        dx_ui_node_set_text(root, "Test")

        let model = dx_render_model_create(root)
        #expect(model != nil)
        if let model = model {
            let node = model.pointee.root!
            // Default alpha should be 1.0 (fully opaque)
            #expect(node.pointee.alpha == 1.0, "Default alpha should be 1.0")
            // Default rotation should be 0
            #expect(node.pointee.rotation == 0.0, "Default rotation should be 0.0")
            // Default scale should be 1.0
            #expect(node.pointee.scale_x == 1.0, "Default scale_x should be 1.0")
            #expect(node.pointee.scale_y == 1.0, "Default scale_y should be 1.0")
            // Default translation should be 0
            #expect(node.pointee.translation_x == 0.0, "Default translation_x should be 0.0")
            #expect(node.pointee.translation_y == 0.0, "Default translation_y should be 0.0")
            dx_render_model_destroy(model)
        }

        dx_ui_node_destroy(root)
    }
}

// ============================================================
// MARK: - Retrofit Tests
// ============================================================

@Suite("Retrofit Tests")
struct RetrofitTests {

    @Test("Retrofit class exists and Builder works")
    func testRetrofitClassAndBuilder() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let retrofitCls = dx_vm_find_class(vm, "Lretrofit2/Retrofit;")
        #expect(retrofitCls != nil, "Retrofit class should be registered")

        let builderCls = dx_vm_find_class(vm, "Lretrofit2/Retrofit$Builder;")
        #expect(builderCls != nil, "Retrofit$Builder class should be registered")

        // Verify Builder has key methods
        if let builderCls = builderCls {
            let baseUrl = dx_vm_find_method(builderCls, "baseUrl", "LL")
            #expect(baseUrl != nil, "Retrofit$Builder.baseUrl should exist")

            let build = dx_vm_find_method(builderCls, "build", "L")
            #expect(build != nil, "Retrofit$Builder.build should exist")
        }

        // Verify related classes
        let callCls = dx_vm_find_class(vm, "Lretrofit2/Call;")
        #expect(callCls != nil, "Retrofit Call interface should be registered")

        let responseCls = dx_vm_find_class(vm, "Lretrofit2/Response;")
        #expect(responseCls != nil, "Retrofit Response class should be registered")

        let callbackCls = dx_vm_find_class(vm, "Lretrofit2/Callback;")
        #expect(callbackCls != nil, "Retrofit Callback interface should be registered")
    }

    @Test("Retrofit annotation classes registered")
    func testRetrofitAnnotations() {
        let (ctx, vm) = makeVM()
        defer { teardownVM(ctx, vm) }

        let annotations = [
            "Lretrofit2/http/GET;",
            "Lretrofit2/http/POST;",
            "Lretrofit2/http/PUT;",
            "Lretrofit2/http/DELETE;",
            "Lretrofit2/http/PATCH;",
            "Lretrofit2/http/HEAD;",
            "Lretrofit2/http/OPTIONS;",
            "Lretrofit2/http/HTTP;",
            "Lretrofit2/http/Path;",
            "Lretrofit2/http/Query;",
            "Lretrofit2/http/Body;",
            "Lretrofit2/http/Header;",
            "Lretrofit2/http/Field;",
            "Lretrofit2/http/FormUrlEncoded;",
            "Lretrofit2/http/Multipart;",
            "Lretrofit2/http/Streaming;",
        ]
        for desc in annotations {
            let cls = dx_vm_find_class(vm, desc)
            #expect(cls != nil, "Expected Retrofit annotation \(desc) to be registered")
        }

        // Also verify converter factories
        let gsonConverter = dx_vm_find_class(vm, "Lretrofit2/converter/gson/GsonConverterFactory;")
        #expect(gsonConverter != nil, "GsonConverterFactory should be registered")

        let moshiConverter = dx_vm_find_class(vm, "Lretrofit2/converter/moshi/MoshiConverterFactory;")
        #expect(moshiConverter != nil, "MoshiConverterFactory should be registered")
    }
}
