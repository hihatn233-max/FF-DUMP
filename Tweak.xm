#import <substrate.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import "VIPMenu.h"
#import "Resolver.h"
#import "Offsets.h"

extern bool isAimEnabled;

static float (*orig_GetHealth)(void* instance);

static float hooked_GetHealth(void* instance) {
    float hp = orig_GetHealth(instance);
    if (isAimEnabled && hp > 0) {
        // Đây là nơi mày có thể làm God Mode (nếu muốn)
    }
    return hp;
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        init_il2cpp();
        [[VIPMenu shared] makeKeyAndVisible];
        
        // Tự động dò và Hook hàm GetHealth của Player
        void* hp_addr = get_method_address(CLASS_PLAYER, METHOD_GET_HP);
        if (hp_addr) {
            MSHookFunction(hp_addr, (void*)hooked_GetHealth, (void**)&orig_GetHealth);
        }
    });
}
