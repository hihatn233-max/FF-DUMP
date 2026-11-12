#import "VIPMenu.h"
#import "Offsets.h"
#import "AimEngine.h"
#import <QuartzCore/QuartzCore.h>

// Khởi tạo biến toàn cục
float aimFOV = 15.0f;
float aimSmooth = 0.15f;
bool isAimEnabled = false;

@interface VIPMenu () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *floatingBtn;
@property (nonatomic, strong) NSArray *features;
@end

@implementation VIPMenu
// ... (Giữ nguyên các hàm init, hitTest, toggleMenu, handlePan như bản trước)

- (void)setupUI {
    // ... (Nút bong bóng và Khung Menu giữ nguyên)
    
    // Cập nhật lại mảng Features
    self.features = @[
        @{@"name": @"Enable Aim", @"desc": @"Humanized Smooth", @"type": @"toggle_aim"},
        @{@"name": @"ESP Box", @"desc": @"Vẽ Box & Health", @"type": @"toggle_esp"},
        @{@"name": @"FOV (Độ rộng)", @"desc": @"Chỉ bám khi địch ở gần", @"type": @"slider_fov"},
        @{@"name": @"Smooth (Độ mượt)", @"desc": @"Càng cao càng giống người", @"type": @"slider_smooth"}
    ];
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
    } 
    else if ([type hasPrefix:@"slider"]) {
        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 120, 30)];
        slider.minimumTrackTintColor = [UIColor cyanColor];
        slider.maximumTrackTintColor = [UIColor darkGrayColor];
        slider.tag = indexPath.row;
        
        if ([type isEqualToString:@"slider_fov"]) {
            slider.minimumValue = 5.0f;
            slider.maximumValue = 90.0f;
            slider.value = aimFOV;
        } else {
            slider.minimumValue = 0.05f;
            slider.maximumValue = 0.8f;
            slider.value = aimSmooth;
        }
        [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = slider;
    }
    
    return cell;
}

- (void)switchChanged:(UISwitch *)sender {
    NSString *type = self.features[sender.tag][@"type"];
    if ([type isEqualToString:@"toggle_aim"]) {
        isAimEnabled = sender.isOn;
    } else if ([type isEqualToString:@"toggle_esp"]) {
        // Gọi hàm bật tắt ESPOverlay
    }
}

- (void)sliderChanged:(UISlider *)sender {
    NSString *type = self.features[sender.tag][@"type"];
    if ([type isEqualToString:@"slider_fov"]) {
        aimFOV = sender.value;
    } else if ([type isEqualToString:@"slider_smooth"]) {
        aimSmooth = sender.value;
    }
}

// ==========================================
// ESP ĐỌC BỘ NHỚ (Đã nâng cấp)
// ==========================================
- (NSArray *)getEnemyList {
    NSMutableArray *enemies = [NSMutableArray array];
    uintptr_t base = KittyMemory::getBaseAddress(); // Lấy Base của game
    if (!base) return enemies;

    uintptr_t entityList = base + ADDR_ENTITY_LIST;
    uintptr_t localPlayer = KittyMemory::read<uintptr_t>(base + ADDR_LOCAL_PLAYER);
    if (!localPlayer) return enemies;

    // Lấy Team của mình để không vẽ box lên đồng đội
    int myTeam = KittyMemory::read<int>(localPlayer + OFF_PLAYER_TEAM);

    for (int i = 0; i < 50; i++) {
        // Đọc con trỏ tới player thứ i
        uintptr_t player = KittyMemory::read<uintptr_t>(entityList + (i * 0x8)); 
        if (!player || player == localPlayer) continue;

        int team = KittyMemory::read<int>(player + OFF_PLAYER_TEAM);
        float hp = KittyMemory::read<float>(player + OFF_PLAYER_HP);

        // Check điều kiện: Còn sống và khác Team
        if (hp > 0 && hp <= 200 && team != myTeam) {
            Vector3 head = KittyMemory::read<Vector3>(player + OFF_PLAYER_HEAD);
            Vector3 feet = KittyMemory::read<Vector3>(player + OFF_PLAYER_POS);
            
            // (Tọa độ Head và Feet này sẽ được đưa vào hàm WorldToScreen để vẽ Box)
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
