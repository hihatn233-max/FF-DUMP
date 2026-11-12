#import <substrate.h>
#import <dlfcn.h>
#import "VIPMenu.h"
#import "Resolver.h"
#import "Offsets.h"

static void (*orig_AimUpdate)(void* instance);
static float (*orig_GetHealth)(void* instance);

static void hooked_AimUpdate(void* instance) {
    orig_AimUpdate(instance); 
}

static float hooked_GetHealth(void* instance) {
    return 100.0f; 
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        init_il2cpp();
        
        // Tự tìm và Hook
        void* aim_addr = get_method_address(CLASS_AIM, METHOD_AIM);
        if (aim_addr) {
            MSHookFunction(aim_addr, (void*)hooked_AimUpdate, (void**)&orig_AimUpdate);
        }

        void* hp_addr = get_method_address(CLASS_PLAYER, METHOD_HP);
        if (hp_addr) {
            MSHookFunction(hp_addr, (void*)hooked_GetHealth, (void**)&orig_GetHealth);
        }

        [[VIPMenu shared] makeKeyAndVisible];
    });
}
