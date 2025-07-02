// AimAssist.c - ROP-friendly aimbot with bone/hitbox targeting and hotkey selection

#define OFFSET_CLIENTPLAYERMANAGER   0x02380B58
#define OFFSET_LOCALPLAYER           0xBC
#define OFFSET_PLAYERLIST            0x9C
#define OFFSET_SOLDIER               0xF8
#define OFFSET_TEAMID                0x13C
#define OFFSET_HEALTHMODULE          0x344
#define OFFSET_AIMASSIST             0x3A8
#define OFFSET_AIMASSIST_YAW         0x0C
#define OFFSET_AIMASSIST_PITCH       0x18

#define OFFSET_BONECOMPONENT         0xA20    // Example, confirm for your version
#define OFFSET_BONETRANSFORMS        0x30

#define BONE_HEAD    4
#define BONE_CHEST   3
#define BONE_PELVIS  2

#define VK_NUMPAD1   0x61
#define VK_NUMPAD2   0x62
#define VK_NUMPAD3   0x63

typedef struct { float x, y, z; } Vec3;

static float g_AimbotFovDegrees = 30.0f;
static int g_TargetBone = BONE_HEAD;

void SetAimbotFov(float degrees) { g_AimbotFovDegrees = degrees; }

// Helper: Get local player pointer
unsigned int GetLocalPlayer() {
    unsigned int mgr = *(unsigned int*)OFFSET_CLIENTPLAYERMANAGER;
    if (!mgr) return 0;
    return *(unsigned int*)(mgr + OFFSET_LOCALPLAYER);
}

// Helper: Get team ID
int GetTeamId(unsigned int player) {
    if (!player) return -1;
    return *(int*)(player + OFFSET_TEAMID);
}

// Helper: Check if soldier is alive
int IsAlive(unsigned int soldier) {
    if (!soldier) return 0;
    unsigned int healthModule = *(unsigned int*)(soldier + OFFSET_HEALTHMODULE);
    if (!healthModule) return 0;
    float health = *(float*)(healthModule + 0x20);
    return (health > 0.1f);
}

// Helper: Get bone position (head/chest/pelvis)
int GetBonePosition(unsigned int soldier, int boneIndex, Vec3* outPos) {
    if (!soldier || !outPos) return 0;
    unsigned int boneComp = *(unsigned int*)(soldier + OFFSET_BONECOMPONENT);
    if (!boneComp) return 0;
    unsigned int boneArray = *(unsigned int*)(boneComp + OFFSET_BONETRANSFORMS);
    if (!boneArray) return 0;
    // Each BoneTransformInfo is typically 0x50 bytes, position at +0x40
    *outPos = *(Vec3*)(boneArray + boneIndex * 0x50 + 0x40);
    return 1;
}

float Degrees(float radians) { return radians * (180.0f / 3.14159265f); }
float AngleDiff(float a, float b) {
    float diff = a - b;
    while (diff >  3.14159265f) diff -= 2.0f * 3.14159265f;
    while (diff < -3.14159265f) diff += 2.0f * 3.14159265f;
    return diff;
}

// Hotkey handler: update g_TargetBone based on numpad key
void UpdateTargetBone() {
    // Replace with your own key state check if needed
    if (*(unsigned short*)0x7FFE02E0 & (1 << VK_NUMPAD1)) g_TargetBone = BONE_HEAD;
    if (*(unsigned short*)0x7FFE02E0 & (1 << VK_NUMPAD2)) g_TargetBone = BONE_CHEST;
    if (*(unsigned short*)0x7FFE02E0 & (1 << VK_NUMPAD3)) g_TargetBone = BONE_PELVIS;
}

// Find best target (closest enemy, alive, within FOV)
unsigned int FindBestTarget(unsigned int localPlayer) {
    unsigned int mgr = *(unsigned int*)OFFSET_CLIENTPLAYERMANAGER;
    if (!mgr) return 0;

    unsigned int playerVec = mgr + OFFSET_PLAYERLIST;
    unsigned int begin = *(unsigned int*)playerVec;
    unsigned int end   = *(unsigned int*)(playerVec + 4);

    int myTeam = GetTeamId(localPlayer);
    unsigned int bestTarget = 0;
    float bestDist = 99999.0f;
    float bestFov = g_AimbotFovDegrees;

    unsigned int mySoldier = *(unsigned int*)(localPlayer + OFFSET_SOLDIER);
    if (!mySoldier || !IsAlive(mySoldier)) return 0;

    Vec3 myPos;
    if (!GetBonePosition(mySoldier, g_TargetBone, &myPos)) return 0;

    unsigned int aimAssist = *(unsigned int*)(mySoldier + OFFSET_AIMASSIST);
    if (!aimAssist) return 0;
    float myYaw   = *(float*)(aimAssist + OFFSET_AIMASSIST_YAW);
    float myPitch = *(float*)(aimAssist + OFFSET_AIMASSIST_PITCH);

    for (unsigned int it = begin; it != end; it += 4) {
        unsigned int player = *(unsigned int*)it;
        if (!player || player == localPlayer) continue;
        if (GetTeamId(player) == myTeam) continue;

        unsigned int soldier = *(unsigned int*)(player + OFFSET_SOLDIER);
        if (!soldier || !IsAlive(soldier)) continue;

        Vec3 pos;
        if (!GetBonePosition(soldier, g_TargetBone, &pos)) continue;

        // Calculate aim angles
        float targetYaw, targetPitch;
        {
            Vec3 delta;
            delta.x = pos.x - myPos.x;
            delta.y = pos.y - myPos.y;
            delta.z = pos.z - myPos.z;
            targetYaw = atan2f(delta.x, delta.z);
            float dist = sqrtf(delta.x * delta.x + delta.z * delta.z);
            targetPitch = -atan2f(delta.y, dist);
        }

        float yawDiff   = Degrees(fabsf(AngleDiff(targetYaw, myYaw)));
        float pitchDiff = Degrees(fabsf(targetPitch - myPitch));
        float fov = sqrtf(yawDiff * yawDiff + pitchDiff * pitchDiff);

        if (fov > g_AimbotFovDegrees) continue;

        float dx = pos.x - myPos.x;
        float dy = pos.y - myPos.y;
        float dz = pos.z - myPos.z;
        float dist = dx*dx + dy*dy + dz*dz;

        if (fov < bestFov || (fabsf(fov - bestFov) < 0.01f && dist < bestDist)) {
            bestFov = fov;
            bestDist = dist;
            bestTarget = player;
        }
    }
    return bestTarget;
}

// Set aim angles
void SetAimAngles(unsigned int soldier, float yaw, float pitch) {
    unsigned int aimAssist = *(unsigned int*)(soldier + OFFSET_AIMASSIST);
    if (!aimAssist) return;
    *(float*)(aimAssist + OFFSET_AIMASSIST_YAW) = yaw;
    *(float*)(aimAssist + OFFSET_AIMASSIST_PITCH) = pitch;
}

// Main aimbot loop (call from ROP chain)
void AimbotTick() {
    unsigned short keyState = *(unsigned short*)0x7FFE02E0;
    if (!(keyState & (1 << VK_NUMPAD1)) &&
        !(keyState & (1 << VK_NUMPAD2)) &&
        !(keyState & (1 << VK_NUMPAD3)))
        return;
    UpdateTargetBone(); // Set g_TargetBone based on which key is pressed

    unsigned int localPlayer = GetLocalPlayer();
    if (!localPlayer) return;

    unsigned int mySoldier = *(unsigned int*)(localPlayer + OFFSET_SOLDIER);
    if (!mySoldier || !IsAlive(mySoldier)) return;

    unsigned int target = FindBestTarget(localPlayer);
    if (!target) return;

    unsigned int targetSoldier = *(unsigned int*)(target + OFFSET_SOLDIER);
    if (!targetSoldier) return;

    Vec3 myPos, targetPos;
    if (!GetBonePosition(mySoldier, g_TargetBone, &myPos)) return;
    if (!GetBonePosition(targetSoldier, g_TargetBone, &targetPos)) return;

    float yaw, pitch;
    {
        Vec3 delta;
        delta.x = targetPos.x - myPos.x;
        delta.y = targetPos.y - myPos.y;
        delta.z = targetPos.z - myPos.z;
        yaw = atan2f(delta.x, delta.z);
        float dist = sqrtf(delta.x * delta.x + delta.z * delta.z);
        pitch = -atan2f(delta.y, dist);
    }

    SetAimAngles(mySoldier, yaw, pitch);
}

// --- End of AimAssist.c ---

