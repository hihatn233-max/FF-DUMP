#import <substrate.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import "VIPMenu.h"
#import "Offsets.h"

static void (*orig_UpdateCamera)(void* instance);

static void hooked_UpdateCamera(void* instance) {
    orig_UpdateCamera(instance);
    if (isAimEnabled) {
        // Logic Aim được xử lý tự động trong file VIPMenu.mm
    }
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [[VIPMenu shared] makeKeyAndVisible];
        
        // BỎ COMMENT ĐOẠN DƯỚI KHI MÀY CÓ OFFSET CỦA HÀM UPDATE CAMERA
        /*
        uintptr_t base = (uintptr_t)_dyld_get_image_header(0);
        void* cameraAddr = (void*)(base + 0xYOUR_OFFSET_HERE);
        MSHookFunction(cameraAddr, (void*)hooked_UpdateCamera, (void**)&orig_UpdateCamera);
        */
    });
}
