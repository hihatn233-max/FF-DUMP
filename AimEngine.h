#pragma once
#include <cmath>
#include <cstdint>
#include <mach/mach.h>
#include <mach-o/dyld.h>

// Hàm lấy địa chỉ gốc của game
inline uintptr_t getBaseAddress() {
    return (uintptr_t)_dyld_get_image_header(0); 
}

// Hàm đọc bộ nhớ thuần C++
template<typename T>
T readMemory(uintptr_t address) {
    T data = {};
    vm_size_t size = sizeof(T);
    kern_return_t kr = vm_read_overwrite(mach_task_self(), (vm_address_t)address, size, (vm_address_t)&data, &size);
    if (kr != KERN_SUCCESS) return {};
    return data;
}

// Cấu trúc Vector 3 chiều
struct Vector3 {
    float x, y, z;
    Vector3() : x(0), y(0), z(0) {}
    Vector3(float _x, float _y, float _z) : x(_x), y(_y), z(_z) {}
    Vector3 operator-(const Vector3& v) const { return Vector3(x - v.x, y - v.y, z - v.z); }
    float Length() { return sqrt(x*x + y*y + z*z); }
};

// Tính góc Yaw và Pitch từ mình tới địch
inline void CalcAngle(Vector3 src, Vector3 dst, float &yaw, float &pitch) {
    Vector3 delta = dst - src;
    float hyp = sqrt(delta.x * delta.x + delta.z * delta.z);
    yaw = atan2(delta.x, delta.z) * 180.0f / M_PI;
    pitch = atan2(delta.y, hyp) * 180.0f / M_PI;
}

extern float aimFOV;
extern float aimSmooth;
extern bool isAimEnabled;

// Hàm Can thiệp vào Camera (Cần hook vào hàm xoay Camera của game)
inline void ApplyHumanizedAim(float targetYaw, float targetPitch, float currentYaw, float currentPitch, float dt) {
    if (!isAimEnabled) return;

    float deltaYaw = targetYaw - currentYaw;
    float deltaPitch = targetPitch - currentPitch;
    
    if (abs(deltaYaw) > (aimFOV / 2.0f) || abs(deltaPitch) > (aimFOV / 2.0f)) return;

    float smoothFactor = aimSmooth * dt * 60.0f;
    if (smoothFactor > 1.0f) smoothFactor = 1.0f;

    float newYaw = currentYaw + (deltaYaw * smoothFactor);
    float newPitch = currentPitch + (deltaPitch * smoothFactor);

    // Ghi đè góc xoay mới vào game (Mày phải tự viết hàm writeMemory nếu cần)
    // writeMemory<float>(cameraAddr + 0xYawOffset, newYaw);
    // writeMemory<float>(cameraAddr + 0xPitchOffset, newPitch);
}
