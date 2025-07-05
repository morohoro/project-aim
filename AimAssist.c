// AimAssist.c - Project for Speedi13 ROP-Compiler Battlefield 3 integration By Morohoro
// Implements BF3 aimbot logic with pointer chasing in assembly and FOV/aim logic in C

#include <stdint.h>
#include <math.h>
#include <windows.h> // For GetTickCount()

// Offsets from original AimAssist.c
#define OFFSET_CLIENTPLAYERMANAGER   0x0238EB58
#define OFFSET_LOCALPLAYER           0x13C
#define OFFSET_PLAYERLIST            0x344
#define OFFSET_SOLDIER               0x3A8
#define OFFSET_TEAMID                0x1C34
#define OFFSET_HEALTHMODULE          0x1E0
#define OFFSET_HEALTH                0x20
#define OFFSET_AIMASSIST             0xA90
#define OFFSET_AIMASSIST_YAW         0x0C
#define OFFSET_AIMASSIST_PITCH       0x18
#define OFFSET_WEAPONCOMPONENT       0x19A0
#define OFFSET_AIMINGPOSEDATA        0x38
#define OFFSET_AIMFOV                0x08
#define OFFSET_BONECOMPONENT         0x490
#define OFFSET_BONETRANSFORMS        0x150
#define OFFSET_BONEPOS               0x30

#define BONE_HEAD    4
#define BONE_CHEST   3
#define BONE_PELVIS  2

// ROP-Compiler API (assumed provided by Speedi13 ROP-Compiler)
extern void ExecuteROPChain(void);
extern int GetVirtualRegister(int index);
extern void SetVirtualRegister(int index, int value);

// Helper: Read int at address with validation
static inline int read_int(uint32_t addr) {
    if (!addr || addr < 0x1000000) return 0; // Basic pointer validation
    return *(int*)addr;
}

// Helper: Read float at address with validation
static inline float read_float(uint32_t addr) {
    if (!addr || addr < 0x1000000) return 0.0f;
    return *(float*)addr;
}

// Helper: Write float at address with validation
static inline void write_float(uint32_t addr, float value) {
    if (addr && addr >= 0x1000000) {
        *(float*)addr = value;
    }
}



// Entry point
void AimAssistTick(void) {
    // Timer-based bone switching logic
    static DWORD aimkey_down_start = 0;
    static int last_aimkey_state = 0;

    int aimkey_state = (GetVirtualRegister(7) & 0x40000) != 0;
    DWORD now = GetTickCount();

    int boneIndex = BONE_PELVIS; // Default

    if (aimkey_state) {
        if (!last_aimkey_state) {
            // Key was just pressed
            aimkey_down_start = now;
        }
        DWORD held_ms = now - aimkey_down_start;
        if (held_ms >= 4000) {
            boneIndex = 7; // Example: leg (replace with actual leg bone index)
        } else if (held_ms >= 2000) {
            boneIndex = BONE_HEAD;
        } else {
            boneIndex = BONE_PELVIS;
        }
    } else {
        aimkey_down_start = now;
    }
    last_aimkey_state = aimkey_state;

    if (!aimkey_state) {
        return;
    }

    SetVirtualRegister(9, boneIndex); // Set VR9 for assembly (overwrites hotkey state)
    SetVirtualRegister(0, 0x1000000);

    DWORD boneOffset = boneIndex * 0x50; // Compute once for both uses
    DWORD stack[] = {
        0x7FFE02E0,              // GetAsyncKeyState
        OFFSET_CLIENTPLAYERMANAGER, // 0x0238EB58 (ClientPlayerManager)
        boneOffset,              // boneIndex * 0x50 (for myBonePtr)
        OFFSET_CLIENTPLAYERMANAGER + OFFSET_PLAYERLIST, // 0x0238EF9C (ClientPlayerManager + 0x344)
        0x0,                     // For health check
        boneOffset               // boneIndex * 0x50 (for enemyBonePtr)
    };

    ExecuteROPChain((DWORD)&stack);

    float enemyX = *(float*)&GetVirtualRegister(1); // VR1
    float enemyY = *(float*)&GetVirtualRegister(5); // VR5
    float enemyZ = *(float*)&GetVirtualRegister(6); // VR6

    float myX = *(float*)&GetVirtualRegister(2); // VR2
    float myY = *(float*)&GetVirtualRegister(3); // VR3
    float myZ = *(float*)&GetVirtualRegister(4); // VR4

    if (enemyX == 0.0f && enemyY == 0.0f && enemyZ == 0.0f) {
        return; // No valid target found
    }

    uint32_t mgr = read_int(OFFSET_CLIENTPLAYERMANAGER);
    if (!mgr) return;

    uint32_t localPlayer = read_int(mgr + OFFSET_LOCALPLAYER);
    if (!localPlayer) return;

    uint32_t mySoldier = read_int(localPlayer + OFFSET_SOLDIER);
    if (!mySoldier) return;

    uint32_t aimAssist = read_int(mySoldier + OFFSET_AIMASSIST);
    if (!aimAssist) return;
    float myYaw = read_float(aimAssist + OFFSET_AIMASSIST_YAW);
    float myPitch = read_float(aimAssist + OFFSET_AIMASSIST_PITCH);

    uint32_t weaponComponent = read_int(mySoldier + OFFSET_WEAPONCOMPONENT);
    if (!weaponComponent) return;
    uint32_t aimingPoseData = read_int(weaponComponent + OFFSET_AIMINGPOSEDATA);
    if (!aimingPoseData) return;
    float allowedFov = read_float(aimingPoseData + OFFSET_AIMFOV);

    float dx = enemyX - myX;
    float dy = enemyY - myY;
    float dz = enemyZ - myZ;

    float yaw = atan2f(dy, dx);
    float distance = sqrtf(dx * dx + dy * dy + dz * dz);
    float pitch = -atan2f(dz, distance);

    float yawDelta = fabsf(yaw - myYaw);
    float pitchDelta = fabsf(pitch - myPitch);
    if (yawDelta > allowedFov || pitchDelta > allowedFov) {
        return; // Target outside FOV
    }

    write_float(aimAssist + OFFSET_AIMASSIST_YAW, yaw);
    write_float(aimAssist + OFFSET_AIMASSIST_PITCH, pitch);
}
