#pragma once
#include <cmath>
#include <cstdint>
#import "Offsets.h"
#import "KittyMemory/MemoryPatch.hpp"

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

// Hàm Can thiệp vào Camera (Cần hook vào hàm xoay Camera của game)
inline void ApplyHumanizedAim(float targetYaw, float targetPitch, float currentYaw, float currentPitch, float dt) {
    if (!isAimEnabled) return;

    // 1. Check FOV (Địch có nằm trong vòng ngắm không)
    float deltaYaw = targetYaw - currentYaw;
    float deltaPitch = targetPitch - currentPitch;
    
    // Nếu góc lệch lớn hơn FOV thì bỏ qua (không bám)
    if (abs(deltaYaw) > (aimFOV / 2.0f) || abs(deltaPitch) > (aimFOV / 2.0f)) return;

    // 2. Humanized Smooth (Nội suy tuyến tính)
    // Tốc độ xoay = Khoảng cách * Hệ số Smooth * DeltaTime
    float smoothFactor = aimSmooth * dt * 60.0f; // 60fps base
    if (smoothFactor > 1.0f) smoothFactor = 1.0f;

    float newYaw = currentYaw + (deltaYaw * smoothFactor);
    float newPitch = currentPitch + (deltaPitch * smoothFactor);

    // Ghi đè góc xoay mới vào game (Cần hàm write của KittyMemory)
    // KittyMemory::write<float>(cameraAddr + 0xYawOffset, newYaw);
    // KittyMemory::write<float>(cameraAddr + 0xPitchOffset, newPitch);
}
