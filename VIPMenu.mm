#import "VIPMenu.h"
#import "Offsets.h"
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#include <cmath>

// Biến toàn cục (Dùng chung với Tweak.xm)
float aimFOV = 20.0f;
float aimSmooth = 0.15f;
bool isAimEnabled = false;
bool isEspEnabled = false;

// ==========================================
// LỚP VẼ ESP (Giữ nguyên)
// ==========================================
@interface ESPOverlay : UIView
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSValue*> *lastPositions;
- (void)start;
- (void)stop;
@end

@implementation ESPOverlay
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.lastPositions = [NSMutableDictionary dictionary];
    }
    return self;
}
- (void)start {
    if (!self.displayLink) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}
- (void)stop {
    [self.displayLink invalidate];
    self.displayLink = nil;
    [self setNeedsDisplay];
}
- (void)updateFrame { if (isEspEnabled) [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect { /* ... (Như cũ) ... */ }
- (NSArray *)getEnemyList { return @[]; /* Đọc bộ nhớ */ }
@end

// ==========================================
// LỚP MENU (VIPMenu)
// ==========================================
@interface VIPMenu () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) ESPOverlay *espOverlay;
@property (nonatomic, strong) NSArray *features;
@end

@implementation VIPMenu

+ (instancetype)shared {
    static VIPMenu *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[VIPMenu alloc] initWithFrame:[UIScreen mainScreen].bounds];
    });
    return shared;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = 10000000;
        self.backgroundColor = [UIColor clearColor];
        self.rootViewController = [UIViewController new];
        [self setupUI];
    }
    return self;
}

// SỬA LẠI HÀM NÀY ĐỂ KHÔNG CHẶN CẢM ỨNG
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    // Nếu chạm vào nút hoặc menu thì nhận, chạm ra ngoài thì trả về game
    if (hitView == self.rootViewController.view) {
        return nil;
    }
    return hitView;
}

- (void)setupUI {
    // Nút bong bóng
    UIButton *floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatingBtn.frame = CGRectMake(20, 100, 60, 60);
    floatingBtn.backgroundColor = [UIColor cyanColor];
    floatingBtn.layer.cornerRadius = 30;
    [floatingBtn setTitle:@"V" forState:UIControlStateNormal];
    [floatingBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [floatingBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [floatingBtn addGestureRecognizer:pan];
    [self.rootViewController.view addSubview:floatingBtn];

    // Khung Menu
    self.containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
    self.containerView.center = self.center;
    self.containerView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.07 alpha:0.95];
    self.containerView.layer.cornerRadius = 16;
    self.containerView.layer.borderColor = [UIColor cyanColor].CGColor;
    self.containerView.layer.borderWidth = 1.5;
    self.containerView.hidden = YES;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 300, 30)];
    titleLabel.text = @"TienAnh211"; // ĐÃ ĐỔI TÊN
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.containerView addSubview:titleLabel];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 50, 300, 350) style:UITableViewStyleInsetGrouped];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.containerView addSubview:self.tableView];
    [self.rootViewController.view addSubview:self.containerView];

    // SỬA LỖI GESTURE 3 NGÓN
    UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleMenu)];
    tripleTap.numberOfTouchesRequired = 3;
    tripleTap.numberOfTapsRequired = 2;
    tripleTap.cancelsTouchesInView = NO; // Cho phép game vẫn nhận được chạm
    [self.rootViewController.view addGestureRecognizer:tripleTap];

    // ESP Overlay
    self.espOverlay = [[ESPOverlay alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [self.rootViewController.view insertSubview:self.espOverlay atIndex:0];

    self.features = @[
        @{@"name": @"ESP VIP", @"desc": @"Box, Line", @"type": @"esp"},
        @{@"name": @"FOV", @"desc": @"Độ rộng góc ngắm", @"type": @"slider_fov"},
        @{@"name": @"Smooth", @"desc": @"Độ mượt", @"type": @"slider_smooth"}
    ];
}

- (void)toggleMenu { self.containerView.hidden = !self.containerView.hidden; }
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self];
    pan.view.center = CGPointMake(pan.view.center.x + translation.x, pan.view.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:self];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.features.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // ... (Giữ nguyên phần tạo cell) ...
    return [UITableViewCell new]; // Placeholder
}
@end
