#import "VIPMenu.h"
#import "Offsets.h"
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#include <cmath>

// ==========================================
// 1. HÀM TOÀN CỤC
// ==========================================
inline uintptr_t getBaseAddress() { return (uintptr_t)_dyld_get_image_header(0); }

template<typename T>
T readMem(uintptr_t address) {
    T data = {};
    vm_size_t size = sizeof(T);
    vm_read_overwrite(mach_task_self(), (vm_address_t)address, size, (vm_address_t)&data, &size);
    return data;
}

struct Vector3 {
    float x, y, z;
    Vector3() : x(0), y(0), z(0) {}
    Vector3(float _x, float _y, float _z) : x(_x), y(_y), z(_z) {}
    Vector3 operator-(const Vector3& v) const { return Vector3(x - v.x, y - v.y, z - v.z); }
};

float aimFOV = 20.0f;
float aimSmooth = 0.15f;
bool isAimEnabled = false;
bool isEspEnabled = false;

// ==========================================
// 2. LỚP VẼ ESP (Đã đóng ngoặc chuẩn)
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

- (void)updateFrame {
    if (isEspEnabled) [self setNeedsDisplay];
}

- (CGPoint)worldToScreen:(float)x y:(float)y z:(float)z {
    float *matrix = readMem<float*>(getBaseAddress() + ADDR_VIEW_MATRIX);
    if (!matrix) return CGPointMake(-1, -1);
    
    float w = matrix[12] * x + matrix[13] * y + matrix[14] * z + matrix[15];
    if (w < 0.01f) return CGPointMake(-1, -1);
    
    float screenX = (matrix[0] * x + matrix[1] * y + matrix[2] * z + matrix[3]) / w;
    float screenY = (matrix[4] * x + matrix[5] * y + matrix[6] * z + matrix[7]) / w;
    
    float width = self.bounds.size.width;
    float height = self.bounds.size.height;
    return CGPointMake((width / 2.0f) + (width / 2.0f) * screenX, (height / 2.0f) - (height / 2.0f) * screenY);
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    if (!isEspEnabled) return;
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.0 green:1.0 blue:1.0 alpha:0.8].CGColor);
    
    NSArray *enemies = [self getEnemyList];
    
    for (NSDictionary *enemy in enemies) {
        float hX = [enemy[@"headX"] floatValue], hY = [enemy[@"headY"] floatValue], hZ = [enemy[@"headZ"] floatValue];
        float fX = [enemy[@"feetX"] floatValue], fY = [enemy[@"feetY"] floatValue], fZ = [enemy[@"feetZ"] floatValue];
        
        CGPoint headScreen = [self worldToScreen:hX y:hY z:hZ];
        CGPoint feetScreen = [self worldToScreen:fX y:fY z:fZ];
        if (headScreen.x < 0 || feetScreen.x < 0) continue;

        NSString *uid = enemy[@"uid"];
        NSValue *lastVal = self.lastPositions[uid];
        if (lastVal) {
            CGPoint lh = [lastVal CGPointValue];
            headScreen.x = lh.x + (headScreen.x - lh.x) * 0.35f;
            headScreen.y = lh.y + (headScreen.y - lh.y) * 0.35f;
        }
        self.lastPositions[uid] = [NSValue valueWithCGPoint:headScreen];

        float boxHeight = feetScreen.y - headScreen.y;
        if (boxHeight < 5) continue;
        float boxWidth = boxHeight * 0.45f;
        CGRect boxRect = CGRectMake(headScreen.x - boxWidth/2, headScreen.y, boxWidth, boxHeight);
        
        CGContextSetShadowWithColor(ctx, CGSizeZero, 4.0, [UIColor cyanColor].CGColor);
        CGContextStrokeRect(ctx, boxRect);
        
        CGContextMoveToPoint(ctx, self.bounds.size.width / 2, self.bounds.size.height);
        CGContextAddLineToPoint(ctx, headScreen.x, headScreen.y);
        CGContextStrokePath(ctx);
    }
}

- (NSArray *)getEnemyList {
    NSMutableArray *enemies = [NSMutableArray array];
    uintptr_t base = getBaseAddress();
    uintptr_t entityList = readMem<uintptr_t>(base + ADDR_ENTITY_LIST);
    uintptr_t localPlayer = readMem<uintptr_t>(base + ADDR_LOCAL_PLAYER);
    
    if (!entityList || !localPlayer) return enemies;

    int myTeam = readMem<int>(localPlayer + OFF_PLAYER_TEAM);

    for (int i = 0; i < 50; i++) {
        uintptr_t player = readMem<uintptr_t>(entityList + (i * 0x8));
        if (!player || player == localPlayer) continue;

        bool isDead = readMem<bool>(player + OFF_PLAYER_ISDEAD);
        int team = readMem<int>(player + OFF_PLAYER_TEAM);

        if (!isDead && team != myTeam) {
            Vector3 head = readMem<Vector3>(player + OFF_BONE_HEAD);
            Vector3 feet = readMem<Vector3>(player + OFF_BONE_LFOOT);
            
            [enemies addObject:@{
                @"headX": @(head.x), @"headY": @(head.y), @"headZ": @(head.z),
                @"feetX": @(feet.x), @"feetY": @(feet.y), @"feetZ": @(feet.z),
                @"uid": [NSString stringWithFormat:@"%d", i]
            }];
        }
    }
    return enemies;
}
@end

// ==========================================
// 3. LỚP MENU VIP
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

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self.rootViewController.view) return nil;
    return hitView;
}

- (void)setupUI {
    UIButton *floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatingBtn.frame = CGRectMake(20, 100, 60, 60);
    
    NSString *iconPath = @"/Library/Application Support/FFMenu/kart_icon.png";
    UIImage *kartImg = [UIImage imageWithContentsOfFile:iconPath];
    
    if (kartImg) {
        [floatingBtn setImage:kartImg forState:UIControlStateNormal];
        floatingBtn.imageView.contentMode = UIViewContentModeScaleAspectFill;
        floatingBtn.layer.cornerRadius = 30;
        floatingBtn.clipsToBounds = YES;
    } else {
        [floatingBtn setTitle:@"V" forState:UIControlStateNormal];
        [floatingBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        floatingBtn.backgroundColor = [UIColor cyanColor];
        floatingBtn.layer.cornerRadius = 30;
    }
    
    floatingBtn.layer.borderColor = [UIColor cyanColor].CGColor;
    floatingBtn.layer.borderWidth = 2.0;
    floatingBtn.layer.shadowColor = [UIColor cyanColor].CGColor;
    floatingBtn.layer.shadowOpacity = 0.8;
    floatingBtn.layer.shadowRadius = 10;
    floatingBtn.layer.shadowOffset = CGSizeZero;
    [floatingBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [floatingBtn addGestureRecognizer:pan];
    [self.rootViewController.view addSubview:floatingBtn];

    self.containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 450)];
    self.containerView.center = self.center;
    
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.containerView.bounds;
    blurView.layer.cornerRadius = 20;
    blurView.clipsToBounds = YES;
    [self.containerView addSubview:blurView];
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.containerView.bounds;
    gradient.colors = @[(id)[UIColor colorWithRed:0 green:0.5 blue:0.5 alpha:0.3].CGColor,
                        (id)[UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:0.8].CGColor];
    gradient.cornerRadius = 20;
    [self.containerView.layer insertSublayer:gradient atIndex:0];

    self.containerView.layer.cornerRadius = 20;
    self.containerView.layer.borderColor = [UIColor cyanColor].CGColor;
    self.containerView.layer.borderWidth = 1.5;
    self.containerView.hidden = YES;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 320, 40)];
    titleLabel.text = @"TienAnh211";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:22];
    titleLabel.layer.shadowColor = [UIColor cyanColor].CGColor;
    titleLabel.layer.shadowOpacity = 1.0;
    titleLabel.layer.shadowRadius = 5;
    titleLabel.layer.shadowOffset = CGSizeZero;
    [self.containerView addSubview:titleLabel];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 60, 320, 380) style:UITableViewStyleInsetGrouped];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.containerView addSubview:self.tableView];
    [self.rootViewController.view addSubview:self.containerView];

    UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleMenu)];
    tripleTap.numberOfTouchesRequired = 3;
    tripleTap.numberOfTapsRequired = 2;
    tripleTap.cancelsTouchesInView = NO;
    [self.rootViewController.view addGestureRecognizer:tripleTap];

    self.espOverlay = [[ESPOverlay alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [self.rootViewController.view insertSubview:self.espOverlay atIndex:0];

    self.features = @[
        @{@"name": @"ESP Box VIP", @"desc": @"Vẽ khung xuyên tường", @"type": @"esp", @"icon": @"cube.transparent"},
        @{@"name": @"Aim FOV", @"desc": @"Bán kính khóa mục tiêu", @"type": @"slider_fov", @"icon": @"scope"},
        @{@"name": @"Smooth Lock", @"desc": @"Độ mượt khi kéo tâm", @"type": @"slider_smooth", @"icon": @"wind"}
    ];
}

- (void)toggleMenu {
    if (self.containerView.hidden) {
        self.containerView.hidden = NO;
        self.containerView.alpha = 0;
        self.containerView.transform = CGAffineTransformMakeScale(0.8, 0.8);
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.containerView.alpha = 1;
            self.containerView.transform = CGAffineTransformIdentity;
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self.containerView.alpha = 0;
            self.containerView.transform = CGAffineTransformMakeScale(0.8, 0.8);
        } completion:^(BOOL finished) {
            self.containerView.hidden = YES;
        }];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self];
    pan.view.center = CGPointMake(pan.view.center.x + translation.x, pan.view.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:self];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.features.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"VIPCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"VIPCell"];
        cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
        cell.layer.cornerRadius = 12;
        cell.clipsToBounds = YES;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:15];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        cell.detailTextLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:12];
    }
    
    NSDictionary *f = self.features[indexPath.row];
    cell.textLabel.text = f[@"name"];
    cell.detailTextLabel.text = f[@"desc"];
    
    if (@available(iOS 13.0, *)) {
        UIImage *icon = [UIImage systemImageNamed:f[@"icon"]];
        cell.imageView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.imageView.tintColor = [UIColor cyanColor];
    }

    if ([f[@"type"] isEqualToString:@"esp"]) {
        UISwitch *sw = [[UISwitch alloc] init];
        sw.onTintColor = [UIColor cyanColor];
        [sw addTarget:self action:@selector(espToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    } else {
        UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 100, 30)];
        sl.minimumTrackTintColor = [UIColor cyanColor];
        sl.maximumTrackTintColor = [UIColor darkGrayColor];
        sl.thumbTintColor = [UIColor whiteColor];
        sl.tag = indexPath.row;
        
        if ([f[@"type"] isEqualToString:@"slider_fov"]) {
            sl.minimumValue = 5.0f; sl.maximumValue = 90.0f; sl.value = aimFOV;
        } else {
            sl.minimumValue = 0.05f; sl.maximumValue = 0.8f; sl.value = aimSmooth;
        }
        
        [sl addTarget:self action:@selector(sliderMoved:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sl;
    }
    return cell;
}

- (void)espToggled:(UISwitch *)sw {
    isEspEnabled = sw.isOn;
    if (isEspEnabled) [self.espOverlay start]; else [self.espOverlay stop];
}

- (void)sliderMoved:(UISlider *)sl {
    if (sl.tag == 1) aimFOV = sl.value; else aimSmooth = sl.value;
}
@end
