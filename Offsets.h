#pragma once
#include <cstdint>

// --- BIẾN TOÀN CỤC (Mày phải tự tìm bằng iGG) ---
#define ADDR_ENTITY_LIST    0x0 // Mảng chứa toàn bộ Player
#define ADDR_VIEW_MATRIX    0x0 // Ma trận Camera
#define ADDR_LOCAL_PLAYER   0x0 // Nhân vật của mình

// --- OFFSET TRONG CLASS (Từ dump.cs) ---
#define OFF_PLAYER_POS      0x0 // Tọa độ chân
#define OFF_PLAYER_HEAD     0x0 // Tọa độ đầu
#define OFF_PLAYER_HP       0x0 // Máu
#define OFF_PLAYER_TEAM     0x0 // Team (để check địch/ta)

// --- BIẾN CHO AIM ---
extern float aimFOV;
extern float aimSmooth;
extern bool isAimEnabled;
