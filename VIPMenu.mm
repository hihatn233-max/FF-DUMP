#import "VIPMenu.h"
#import "Offsets.h"
#import <QuartzCore/QuartzCore.h>

@interface VIPMenu () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *floatingBtn;
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
        self.rootViewController.view.backgroundColor = [UIColor clearColor];
        [self setupUI];
    }
    return self;
}

// HÀM QUAN TRỌNG NHẤT: Quyết định xem có nhận chạm hay không
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    
    // Nếu điểm chạm là cái nền trong suốt (không phải nút, không phải menu) -> Bỏ qua
    if (hitView == self.rootViewController.view) {
        return nil; 
    }
    return hitView;
}

- (void)setupUI {
    // 1. NÚT BONG BÓNG
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

    // 2. KHUNG MENU
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

    // 3. GESTURE 3 NGÓN TAY
    UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleMenu)];
    tripleTap.numberOfTouchesRequired = 3;
    tripleTap.numberOfTapsRequired = 2;
    [self addGestureRecognizer:tripleTap];

    self.features = @[
        @{@"name": @"Aim Cổ (Head)", @"desc": @"Ghim thẳng vào đầu"},
        @{@"name": @"Aim Body", @"desc": @"Ghim vào ngực/bụng"},
        @{@"name": @"Magic Bullet", @"desc": @"Đạn tự bay theo tâm"},
        @{@"name": @"ESP VIP", @"desc": @"Box, Line, Health"}
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
        
        UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
        toggle.onTintColor = [UIColor cyanColor];
        cell.accessoryView = toggle;
    }
    NSDictionary *feature = self.features[indexPath.row];
    cell.textLabel.text = feature[@"name"];
    cell.detailTextLabel.text = feature[@"desc"];
    return cell;
}
@end
