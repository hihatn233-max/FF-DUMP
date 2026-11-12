#import <substrate.h>
#import <dlfcn.h>
#import "VIPMenu.h"

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [[VIPMenu shared] makeKeyAndVisible];
    });
}
