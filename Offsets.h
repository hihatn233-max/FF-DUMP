#pragma once
#include <cstdint>

// --- TÊN CLASS VÀ HÀM (Dùng cho Resolver tự dò) ---
#define CLASS_PLAYER    "Player"
#define METHOD_GET_HP   "get_Health"

// --- ĐỊA CHỈ TĨNH (Mày điền sau khi dùng iGG quét) ---
#define ADDR_ENTITY_LIST    0x0
#define ADDR_LOCAL_PLAYER   0x0
#define ADDR_VIEW_MATRIX    0x0

// --- OFFSET TRONG CLASS (Từ bảng V7A) ---
#define OFF_PLAYER_ISDEAD   0x50
#define OFF_PLAYER_TEAM     0x59
#define OFF_PLAYER_HP       0x4BC
#define OFF_BONE_HEAD       0x458
#define OFF_BONE_LFOOT      0x47C
