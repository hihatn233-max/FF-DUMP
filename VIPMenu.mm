#import "VIPMenu.h"
#import "Offsets.h"
#import "Resolver.h"
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>

// Hàm đọc bộ nhớ
inline uintptr_t getBaseAddress() { return (uintptr_t)_dyld_get_image_header(0); }
template<typename T>
T readMem(uintptr_t address) {
    T data = {};
    vm_size_t size = sizeof(T);
    vm_read_overwrite(mach_task_self(), (vm_address_t)address, size, (vm_address_t)&data, &size);
    return data;
}

// ... (Copy phần struct Vector3 và biến toàn cục từ tin trước)

// ... (Copy phần ESPOverlay vào đây)

// Trong hàm drawRect của ESP, mày thay đổi hàm getEnemyList để nó đọc qua cái Resolver:
- (NSArray *)getEnemyList {
    NSMutableArray *enemies = [NSMutableArray array];
    uintptr_t base = getBaseAddress();
    
    // Mày phải quét iGG lấy 3 địa chỉ này, không có Resolver nào tự tìm được mảng Entity
    uintptr_t entityList = readMem<uintptr_t>(base + ADDR_ENTITY_LIST);
    uintptr_t localPlayer = readMem<uintptr_t>(base + ADDR_LOCAL_PLAYER);
    
    if (!entityList || !localPlayer) return enemies;
    
    // ... (Code vòng lặp for đọc tọa độ như cũ)
    // Vì đọc tọa độ (Vector3) vẫn phải dùng Offset cố định của struct (OFF_BONE_HEAD), không dùng Resolver được.
}
