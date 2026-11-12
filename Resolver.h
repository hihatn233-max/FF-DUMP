#pragma once
#include <stdint.h>
#include <dlfcn.h>

typedef void* (*il2cpp_domain_get_t)(void);
typedef void** (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* count);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void* (*il2cpp_class_get_method_from_name_t)(void* klass, const char* name, int argsCount);
typedef void* (*il2cpp_method_get_pointer_t)(void* method);

struct IL2CPP_API {
    il2cpp_domain_get_t domain_get;
    il2cpp_domain_get_assemblies_t domain_get_assemblies;
    il2cpp_assembly_get_image_t assembly_get_image;
    il2cpp_class_from_name_t class_from_name;
    il2cpp_class_get_method_from_name_t class_get_method_from_name;
    il2cpp_method_get_pointer_t method_get_pointer;
};

static IL2CPP_API api;

inline void init_il2cpp() {
    void* handle = dlopen("@executable_path/Frameworks/UnityFramework.framework/UnityFramework", RTLD_LAZY);
    if (!handle) return;
    api.domain_get = (il2cpp_domain_get_t)dlsym(handle, "il2cpp_domain_get");
    api.domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(handle, "il2cpp_domain_get_assemblies");
    api.assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(handle, "il2cpp_assembly_get_image");
    api.class_from_name = (il2cpp_class_from_name_t)dlsym(handle, "il2cpp_class_from_name");
    api.class_get_method_from_name = (il2cpp_class_get_method_from_name_t)dlsym(handle, "il2cpp_class_get_method_from_name");
    api.method_get_pointer = (il2cpp_method_get_pointer_t)dlsym(handle, "il2cpp_method_get_pointer");
}

inline void* get_method_address(const char* className, const char* methodName) {
    if (!api.domain_get) return nullptr;
    void* domain = api.domain_get();
    size_t count = 0;
    void** assemblies = api.domain_get_assemblies(domain, &count);

    for (size_t i = 0; i < count; i++) {
        void* image = api.assembly_get_image(assemblies[i]);
        void* klass = api.class_from_name(image, "", className);
        if (!klass) klass = api.class_from_name(image, "Assembly-CSharp", className);
        
        if (klass) {
            void* method = api.class_get_method_from_name(klass, methodName, -1);
            if (method) return api.method_get_pointer(method);
        }
    }
    return nullptr;
}
