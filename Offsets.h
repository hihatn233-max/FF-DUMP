#pragma once
#include <cstdint>

// --- TÊN CLASS/HÀM ĐỂ RESOLVER TỰ TÌM ---
#define CLASS_PLAYER    "Player"
#define METHOD_GET_HP   "get_Health"

// --- OFFSET FIELD (Mày lấy từ dump.cs iOS hoặc V7A) ---
#define OFF_PLAYER_TEAM     0x59
#define OFF_PLAYER_HP       0x4BC
#define OFF_BONE_HEAD       0x458
#define OFF_BONE_LFOOT      0x47C

// --- ĐỊA CHỈ TĨNH MẢNG (Phải dùng iGG quét) ---
#define ADDR_ENTITY_LIST    0x0 
#define ADDR_LOCAL_PLAYER   0x0
#define ADDR_VIEW_MATRIX    0x0
