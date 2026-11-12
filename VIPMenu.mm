#import "VIPMenu.h"
#import "Offsets.h"
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#include <cmath>

// ==========================================
// 1. HÀM ĐỌC BỘ NHỚ (Không cần thư viện ngoài)
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
    Vector3 operator-(const Vector3& v) const { return Vector3(x - v.x, y - v.y, z - v.z); }
};

// Biến toàn cục
float aimFOV = 20.0f;
float aimSmooth = 0.15f;
bool isAimEnabled = false;
bool isEspEnabled = false;

// ==========================================
// 2. LỚP VẼ ESP (Smooth CADisplayLink)
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
- (void)updateFrame { if (isEspEnabled) [self setNeedsDisplay]; }

- (CGPoint)worldToScreen:(float)x y:(float)y z:(float)z {
    float *matrix = readMem<float*>(getBaseAddress() + ADDR_VIEW_MATRIX); // Đọc ma trận Camera
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
    CGContextSetStrokeColorWithColor(ctx, [UIColor cyanColor].CGColor);
    
    NSArray *enemies = [self getEnemyList];
    
    for (NSDictionary *enemy in enemies) {
        Vector3 head = {[enemy[@"headX"] floatValue], [enemy[@"headY"] floatValue], [enemy[@"headZ"] floatValue]};
        Vector3 feet = {[enemy[@"feetX"] floatValue], [enemy[@"feetY"] floatValue], [enemy[@"feetZ"] floatValue]};
        
        CGPoint headScreen = [self worldToScreen:head.x y:head.y z:head.z];
        CGPoint feetScreen = [self worldToScreen:feet.x y:feet.y z:feet.z];
        if (headScreen.x < 0 || feetScreen.x < 0) continue;

        // Làm mượt
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
        
        // Vẽ Box & Line
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
    if (!entityList) return enemies;

    for (int i = 0; i < 50; i++) {
        uintptr_t player = readMem<uintptr_t>(entityList + (i * 0x8));
        if (!player) continue;

        float hp = readMem<float>(player + OFF_PLAYER_HP);
        int team = readMem<int>(player + OFF_PLAYER_TEAM);

        if (hp > 0 && hp <= 200 && team != 1) { // team 1 là đồng đội
            Vector3 head = readMem<Vector3>(player + OFF_PLAYER_HEAD);
            Vector3 feet = readMem<Vector3>(player + OFF_PLAYER_POS);
            
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
// 3. LỚP MENU (VIPMenu)
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
    floatingBtn.backgroundColor = [UIColor cyanColor];
    floatingBtn.layer.cornerRadius = 30;
    [floatingBtn setTitle:@"V" forState:UIControlStateNormal];
    [floatingBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [floatingBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [floatingBtn addGestureRecognizer:pan];
    [self.rootViewController.view addSubview:floatingBtn];

    self.containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
    self.containerView.center = self.center;
    self.containerView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.07 alpha:0.95];
    self.containerView.layer.cornerRadius = 16;
    self.containerView.layer.borderColor = [UIColor cyanColor].CGColor;
    self.containerView.layer.borderWidth = 1.5;
    self.containerView.hidden = YES;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 300, 400) style:UITableViewStyleInsetGrouped];
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
    [self.rootViewController.view insertSubview:self.espOverlay atIndex:0];

    self.features = @[
        @{@"name": @"ESP VIP", @"desc": @"Box, Line", @"type": @"esp"},
        @{@"name": @"FOV", @"desc": @"Độ rộng góc ngắm", @"type": @"slider_fov"},
        @{@"name": @"Smooth", @"desc": @"Độ mượt của tâm", @"type": @"slider_smooth"}
    ];
}

- (void)toggleMenu {
    self.containerView.hidden = !self.containerView.hidden;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self];
    pan.view.center = CGPointMake(pan.view.center.x + translation.x, pan.view.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:self];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.features.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
        cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
    }
    NSDictionary *f = self.features[indexPath.row];
    cell.textLabel.text = f[@"name"];
    cell.detailTextLabel.text = f[@"desc"];
    
    if ([f[@"type"] isEqualToString:@"esp"]) {
        UISwitch *sw = [[UISwitch alloc] init];
        sw.onTintColor = [UIColor cyanColor];
        [sw addTarget:self action:@selector(espToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    } else {
        UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 120, 30)];
        sl.minimumTrackTintColor = [UIColor cyanColor];
        sl.tag = indexPath.row;
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
