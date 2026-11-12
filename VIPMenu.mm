#import "VIPMenu.h"
@implementation VIPMenu
+ (instancetype)shared {
    static VIPMenu *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[VIPMenu alloc] initWithFrame:[UIScreen mainScreen].bounds];
        shared.windowLevel = 10000000;
        shared.backgroundColor = [UIColor clearColor];
        shared.rootViewController = [UIViewController new];
        
        // Nút test
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(20, 100, 60, 60);
        btn.backgroundColor = [UIColor cyanColor];
        btn.layer.cornerRadius = 30;
        [btn setTitle:@"V" forState:UIControlStateNormal];
        [shared.rootViewController.view addSubview:btn];
    });
    return shared;
}
@end
