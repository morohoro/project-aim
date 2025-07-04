// AimAssist.c - Refactored for Speedi13 ROP-Compiler integration
// Implements BF3 aimbot logic with pointer chasing in assembly and FOV/aim logic in C

#include <stdint.h>

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


```c
// AimAssist.c - Refactored for Speedi13 ROP-Compiler integration
// Implements BF3 aimbot logic with pointer chasing in assembly and FOV/aim logic in C

#include <stdint.h>
#include <math.h>

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
    // Check hotkey (VK_MENU, bit 18, 0x40000) from VR9
    if ((GetVirtualRegister(9) & 0x40000) == 0) {
        return;
    }

    // Set bone index (dynamic or hardcoded)
    // Replace 0x12345678 with actual game time address if available
    int gameTime = read_int(0x12345678); // Placeholder; update with valid address
    int boneIndex = (gameTime & 0x3) == 0 ? BONE_HEAD : ((gameTime & 0x3) == 1 ? BONE_CHEST : BONE_PELVIS);
    SetVirtualRegister(9, boneIndex); // Set VR9 for assembly (overwrites hotkey state)

    // Set VR0 for pointer validation (minimum address)
    SetVirtualRegister(0, 0x1000000);

    // Define the stack array for ROP chain
    DWORD boneOffset = boneIndex * 0x50; // Compute once for both uses
    DWORD stack[] = {
        0x7FFE02E0,              // GetAsyncKeyState
        OFFSET_CLIENTPLAYERMANAGER, // 0x0238EB58 (ClientPlayerManager)
        OFFSET_CLIENTPLAYERMANAGER + OFFSET_PLAYERLIST, // 0x0238EF9C (ClientPlayerManager + 0x344)
        boneOffset,              // boneIndex * 0x50 (for myBonePtr)
        boneOffset,              // boneIndex * 0x50 (for enemyBonePtr)
        0x0                      // For health check
    };

    // Execute ROP chain with stack
    // Assuming ExecuteROPChain accepts a stack parameter; adjust if needed
    ExecuteROPChain((DWORD)&stack);

    // Get enemy position from virtual registers
    float enemyX = *(float*)&GetVirtualRegister(1); // VR1
    float enemyY = *(float*)&GetVirtualRegister(5); // VR5
    float enemyZ = *(float*)&GetVirtualRegister(6); // VR6

    // Get local player position (stored in VR2, VR3, VR4 after reuse)
    float myX = *(float*)&GetVirtualRegister(2); // VR2
    float myY = *(float*)&GetVirtualRegister(3); // VR3
    float myZ = *(float*)&GetVirtualRegister(4); // VR4

    // Validate enemy position (basic check to avoid crashes)
    if (enemyX == 0.0f && enemyY == 0.0f && enemyZ == 0.0f) {
        return; // No valid target found
    }

    // Get ClientPlayerManager
    uint32_t mgr = read_int(OFFSET_CLIENTPLAYERMANAGER);
    if (!mgr) return;

    // Get LocalPlayer
    uint32_t localPlayer = read_int(mgr + OFFSET_LOCALPLAYER);
    if (!localPlayer) return;

    // Get my soldier
    uint32_t mySoldier = read_int(localPlayer + OFFSET_SOLDIER);
    if (!mySoldier) return;

    // Get my yaw/pitch (as floats)
    uint32_t aimAssist = read_int(mySoldier + OFFSET_AIMASSIST);
    if (!aimAssist) return;
    float myYaw = read_float(aimAssist + OFFSET_AIMASSIST_YAW);
    float myPitch = read_float(aimAssist + OFFSET_AIMASSIST_PITCH);

    // Get allowed FOV
    uint32_t weaponComponent = read_int(mySoldier + OFFSET_WEAPONCOMPONENT);
    if (!weaponComponent) return;
    uint32_t aimingPoseData = read_int(weaponComponent + OFFSET_AIMINGPOSEDATA);
    if (!aimingPoseData) return;
    float allowedFov = read_float(aimingPoseData + OFFSET_AIMFOV);

    // Calculate delta (vector to target)
    float dx = enemyX - myX;
    float dy = enemyY - myY;
    float dz = enemyZ - myZ;

    // Calculate yaw and pitch angles (basic atan2 approximation)
    float yaw = atan2f(dy, dx);
    float distance = sqrtf(dx * dx + dy * dy + dz * dz);
    float pitch = -atan2f(dz, distance);

    // FOV check
    float yawDelta = fabsf(yaw - myYaw);
    float pitchDelta = fabsf(pitch - myPitch);
    if (yawDelta > allowedFov || pitchDelta > allowedFov) {
        return; // Target outside FOV
    }

    // Write aim angles
    write_float(aimAssist + OFFSET_AIMASSIST_YAW, yaw);
    write_float(aimAssist + OFFSET_AIMASSIST_PITCH, pitch);
}
