#import "VIPMenu.h"
#import "Offsets.h"
#import <QuartzCore/QuartzCore.h>
#include <cmath>
#include <mach/mach.h>
#include <mach-o/dyld.h>

// ==========================================
// MEMORY READER & TOÁN HỌC
// ==========================================
inline uintptr_t getBaseAddress() { return (uintptr_t)_dyld_get_image_header(0); }

template<typename T>
T readMemory(uintptr_t address) {
    T data = {};
    vm_size_t size = sizeof(T);
    kern_return_t kr = vm_read_overwrite(mach_task_self(), (vm_address_t)address, size, (vm_address_t)&data, &size);
    if (kr != KERN_SUCCESS) return {};
    return data;
}

struct Vector3 {
    float x, y, z;
    Vector3() : x(0), y(0), z(0) {}
    Vector3(float _x, float _y, float _z) : x(_x), y(_y), z(_z) {}
    Vector3 operator-(const Vector3& v) const { return Vector3(x - v.x, y - v.y, z - v.z); }
};

float aimFOV = 15.0f;
float aimSmooth = 0.15f;
bool isAimEnabled = false;

// ==========================================
// ESP OVERLAY
// ==========================================
@interface ESPOverlay : UIView
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSValue*> *lastPositions;
@property (nonatomic, assign) float *viewMatrix;
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
- (void)updateFrame { [self setNeedsDisplay]; }

- (CGPoint)worldToScreen:(float)x y:(float)y z:(float)z {
    if (!self.viewMatrix) return CGPointMake(-1, -1);
    float w = self.viewMatrix[12] * x + self.viewMatrix[13] * y + self.viewMatrix[14] * z + self.viewMatrix[15];
    if (w < 0.01f) return CGPointMake(-1, -1);
    float screenX = (self.viewMatrix[0] * x + self.viewMatrix[1] * y + self.viewMatrix[2] * z + self.viewMatrix[3]) / w;
    float screenY = (self.viewMatrix[4] * x + self.viewMatrix[5] * y + self.viewMatrix[6] * z + self.viewMatrix[7]) / w;
    return CGPointMake((self.bounds.size.width / 2.0f) + (self.bounds.size.width / 2.0f) * screenX, 
                       (self.bounds.size.height / 2.0f) - (self.bounds.size.height / 2.0f) * screenY);
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetStrokeColorWithColor(ctx, [UIColor cyanColor].CGColor);
    
    NSArray *enemies = [self getEnemyList]; 
    
    for (NSDictionary *enemy in enemies) {
        float hX = [enemy[@"headX"] floatValue], hY = [enemy[@"headY"] floatValue], hZ = [enemy[@"headZ"] floatValue];
        float fX = [enemy[@"feetX"] floatValue], fY = [enemy[@"feetY"] floatValue], fZ = [enemy[@"feetZ"] floatValue];
        NSString *uid = enemy[@"uid"];
        float hp = [enemy[@"hp"] floatValue];
        
        CGPoint head = [self worldToScreen:hX y:hY z:hZ];
        CGPoint feet = [self worldToScreen:fX y:fY z:fZ];
        if (head.x < 0 || feet.x < 0) continue;

        NSValue *lastHeadVal = self.lastPositions[uid];
        if (lastHeadVal) {
            CGPoint lastHead = [lastHeadVal CGPointValue];
            head.x = lastHead.x + (head.x - lastHead.x) * 0.35f;
            head.y = lastHead.y + (head.y - lastHead.y) * 0.35f;
        }
        self.lastPositions[uid] = [NSValue valueWithCGPoint:head];

        float boxHeight = feet.y - head.y;
        if (boxHeight < 5) continue;
        float boxWidth = boxHeight * 0.45f;
        CGRect boxRect = CGRectMake(head.x - boxWidth/2, head.y, boxWidth, boxHeight);
        
        CGContextStrokeRect(ctx, boxRect);
        
        CGContextSetStrokeColorWithColor(ctx, [UIColor redColor].CGColor);
        CGContextSetLineWidth(ctx, 2.0);
        float hpHeight = boxHeight * (hp / 100.0f);
        CGContextMoveToPoint(ctx, boxRect.origin.x - 5, boxRect.origin.y + boxHeight);
        CGContextAddLineToPoint(ctx, boxRect.origin.x - 5, boxRect.origin.y + boxHeight - hpHeight);
        CGContextStrokePath(ctx);
        
        CGContextSetStrokeColorWithColor(ctx, [UIColor cyanColor].CGColor);
        CGContextSetLineWidth(ctx, 1.0);
        CGContextMoveToPoint(ctx, self.bounds.size.width / 2, self.bounds.size.height);
        CGContextAddLineToPoint(ctx, head.x, head.y);
        CGContextStrokePath(ctx);
    }
}

- (NSArray *)getEnemyList {
    NSMutableArray *enemies = [NSMutableArray array];
    uintptr_t base = getBaseAddress(); 
    if (!base) return enemies;

    uintptr_t entityList = base + ADDR_ENTITY_LIST;
    uintptr_t localPlayer = readMemory<uintptr_t>(base + ADDR_LOCAL_PLAYER);
    if (!localPlayer) return enemies;

    int myTeam = readMemory<int>(localPlayer + OFF_PLAYER_TEAM);

    for (int i = 0; i < 50; i++) {
        uintptr_t player = readMemory<uintptr_t>(entityList + (i * 0x8)); 
        if (!player || player == localPlayer) continue;

        int team = readMemory<int>(player + OFF_PLAYER_TEAM);
        float hp = readMemory<float>(player + OFF_PLAYER_HP);

        if (hp > 0 && hp <= 200 && team != myTeam) {
            Vector3 head = readMemory<Vector3>(player + OFF_PLAYER_HEAD);
            Vector3 feet = readMemory<Vector3>(player + OFF_PLAYER_POS);
            
            [enemies addObject:@{
                @"headX": @(head.x), @"headY": @(head.y), @"headZ": @(head.z),
                @"feetX": @(feet.x), @"feetY": @(feet.y), @"feetZ": @(feet.z),
                @"hp": @(hp),
                @"uid": [NSString stringWithFormat:@"%lu", (unsigned long)player]
            }];
        }
    }
    return enemies;
}
@end

// ==========================================
// VIP MENU CLASS
// ==========================================
@interface VIPMenu () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *floatingBtn;
@property (nonatomic, strong) NSArray *features;
@property (nonatomic, strong) ESPOverlay *espOverlay;
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
        self.rootViewController.view.backgroundColor = [UIColor clearColor];
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
    self.floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingBtn.frame = CGRectMake(20, 100, 60, 60);
    self.floatingBtn.backgroundColor = [UIColor cyanColor];
    self.floatingBtn.layer.cornerRadius = 30;
    [self.floatingBtn setTitle:@"V" forState:UIControlStateNormal];
    [self.floatingBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.floatingBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.floatingBtn addGestureRecognizer:pan];
    [self.rootViewController.view addSubview:self.floatingBtn];

    self.containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
    self.containerView.center = self.center;
    self.containerView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.07 alpha:0.95];
    self.containerView.layer.cornerRadius = 16;
    self.containerView.layer.borderColor = [UIColor cyanColor].CGColor;
    self.containerView.layer.borderWidth = 1.5;
    self.containerView.hidden = YES;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, 260, 50)];
    titleLabel.text = @"TIENANH VIP (OB55)";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.containerView addSubview:titleLabel];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 50, 300, 350) style:UITableViewStyleInsetGrouped];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.containerView addSubview:self.tableView];
    [self.rootViewController.view addSubview:self.containerView];

    UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleMenu)];
    tripleTap.numberOfTouchesRequired = 3;
    tripleTap.numberOfTapsRequired = 2;
    [self addGestureRecognizer:tripleTap];

    self.espOverlay = [[ESPOverlay alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [self.rootViewController.view addSubview:self.espOverlay];

    self.features = @[
        @{@"name": @"Enable Aim", @"desc": @"Humanized Smooth", @"type": @"toggle_aim"},
        @{@"name": @"ESP Box", @"desc": @"Vẽ Box & Health", @"type": @"toggle_esp"},
        @{@"name": @"FOV (Độ rộng)", @"desc": @"Chỉ bám khi địch ở gần", @"type": @"slider_fov"},
        @{@"name": @"Smooth (Độ mượt)", @"desc": @"Càng cao càng giống người", @"type": @"slider_smooth"}
    ];
}

- (void)toggleMenu {
    if (self.containerView.hidden) {
        self.containerView.hidden = NO;
        self.containerView.alpha = 0;
        self.containerView.transform = CGAffineTransformMakeScale(0.9, 0.9);
        [UIView animateWithDuration:0.2 animations:^{
            self.containerView.alpha = 1;
            self.containerView.transform = CGAffineTransformIdentity;
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self.containerView.alpha = 0;
            self.containerView.transform = CGAffineTransformMakeScale(0.9, 0.9);
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.features.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"VIPCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"VIPCell"];
        cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    NSDictionary *feature = self.features[indexPath.row];
    cell.textLabel.text = feature[@"name"];
    cell.detailTextLabel.text = feature[@"desc"];
    
    NSString *type = feature[@"type"];
    if ([type hasPrefix:@"toggle"]) {
        UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
        toggle.onTintColor = [UIColor cyanColor];
        [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        toggle.tag = indexPath.row;
        cell.accessoryView = toggle;
    } else if ([type hasPrefix:@"slider"]) {
        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 120, 30)];
        slider.minimumTrackTintColor = [UIColor cyanColor];
        slider.maximumTrackTintColor = [UIColor darkGrayColor];
        slider.tag = indexPath.row;
        if ([type isEqualToString:@"slider_fov"]) {
            slider.minimumValue = 5.0f; slider.maximumValue = 90.0f; slider.value = aimFOV;
        } else {
            slider.minimumValue = 0.05f; slider.maximumValue = 0.8f; slider.value = aimSmooth;
        }
        [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = slider;
    }
    return cell;
}

- (void)switchChanged:(UISwitch *)sender {
    NSString *type = self.features[sender.tag][@"type"];
    if ([type isEqualToString:@"toggle_aim"]) isAimEnabled = sender.isOn;
    else if ([type isEqualToString:@"toggle_esp"]) {
        if (sender.isOn) [self.espOverlay start];
        else [self.espOverlay stop];
    }
}

- (void)sliderChanged:(UISlider *)sender {
    NSString *type = self.features[sender.tag][@"type"];
    if ([type isEqualToString:@"slider_fov"]) aimFOV = sender.value;
    else if ([type isEqualToString:@"slider_smooth"]) aimSmooth = sender.value;
}
@end
