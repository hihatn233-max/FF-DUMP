#import <substrate.h>
#import <dlfcn.h>
#import "VIPMenu.h"

%ctor {
    // Đợi 5 giây cho game load xong xuôi rồi mới bật menu
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        // Dùng setHidden thay vì makeKeyAndVisible để không cướp cảm ứng của game
        VIPMenu *menu = [VIPMenu shared];
        menu.hidden = NO;
    });
}
