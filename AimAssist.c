// AimAssist.c - Integer logic version, mirroring ROP-compatible AimAssist.asm

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

// Stack emulation (for demonstration)
int stack[256];

// Helper: Read int at address
int read_int(unsigned int addr) {
    return *(int*)(addr);
}

// Helper: Write int at address
void write_int(unsigned int addr, int value) {
    *(int*)(addr) = value;
}

// Entry point
void AimAssistTick() {
    // Only activate if Alt key is pressed (VK_MENU, 0x12, bit 18)
    if ((*(int*)0x7FFE02E0 & 0x40000) == 0)
        return;

    // Choose bone index based on "game time" for randomization (you can replace with fixed value if needed)
    int gameTime = read_int(0x12345678); // Replace 0x12345678 with correct address if needed
    int boneIndex = (gameTime & 0x3) == 0 ? BONE_HEAD : ((gameTime & 0x3) == 1 ? BONE_CHEST : BONE_PELVIS);

    // Get ClientPlayerManager
    unsigned int mgr = read_int(OFFSET_CLIENTPLAYERMANAGER);
    if (!mgr) return;

    // Get LocalPlayer
    unsigned int localPlayer = read_int(mgr + OFFSET_LOCALPLAYER);
    if (!localPlayer) return;

    // Get my team ID
    int myTeam = read_int(localPlayer + OFFSET_TEAMID);

    // Get my soldier
    unsigned int mySoldier = read_int(localPlayer + OFFSET_SOLDIER);
    if (!mySoldier) return;

    // Get my bone position (Vec3 as int-bits)
    unsigned int boneComp = read_int(mySoldier + OFFSET_BONECOMPONENT);
    if (!boneComp) return;
    unsigned int boneArray = read_int(boneComp + OFFSET_BONETRANSFORMS);
    if (!boneArray) return;
    unsigned int myBonePtr = boneArray + boneIndex * 0x50;
    int myX = read_int(myBonePtr + OFFSET_BONEPOS + 0);
    int myY = read_int(myBonePtr + OFFSET_BONEPOS + 4);
    int myZ = read_int(myBonePtr + OFFSET_BONEPOS + 8);

    // Get my yaw/pitch as int-bits
    unsigned int aimAssist = read_int(mySoldier + OFFSET_AIMASSIST);
    if (!aimAssist) return;
    int myYaw = read_int(aimAssist + OFFSET_AIMASSIST_YAW);
    int myPitch = read_int(aimAssist + OFFSET_AIMASSIST_PITCH);

    // Get allowed FOV as int-bits
    unsigned int weaponComponent = read_int(mySoldier + OFFSET_WEAPONCOMPONENT);
    if (!weaponComponent) return;
    unsigned int aimingPoseData = read_int(weaponComponent + OFFSET_AIMINGPOSEDATA);
    if (!aimingPoseData) return;
    int allowedFov = read_int(aimingPoseData + OFFSET_AIMFOV);

    // Get player list base pointer
    unsigned int playerList = read_int(mgr + OFFSET_PLAYERLIST);

    // Loop over players (max 64)
    for (int i = 0; i < 64; ++i) {
        unsigned int playerPtr = read_int(playerList + i * 4);
        if (!playerPtr) continue;
        if (playerPtr == localPlayer) continue;

        // Team check
        int teamId = read_int(playerPtr + OFFSET_TEAMID);
        if (teamId == myTeam) continue;

        // Soldier pointer and alive check
        unsigned int soldier = read_int(playerPtr + OFFSET_SOLDIER);
        if (!soldier) continue;
        unsigned int healthModule = read_int(soldier + OFFSET_HEALTHMODULE);
        if (!healthModule) continue;
        int health = read_int(healthModule + OFFSET_HEALTH);
        if (health <= 0) continue;

        // Get enemy bone position (Vec3 as int-bits)
        unsigned int enemyBoneComp = read_int(soldier + OFFSET_BONECOMPONENT);
        if (!enemyBoneComp) continue;
        unsigned int enemyBoneArray = read_int(enemyBoneComp + OFFSET_BONETRANSFORMS);
        if (!enemyBoneArray) continue;
        unsigned int enemyBonePtr = enemyBoneArray + boneIndex * 0x50;
        int enemyX = read_int(enemyBonePtr + OFFSET_BONEPOS + 0);
        int enemyY = read_int(enemyBonePtr + OFFSET_BONEPOS + 4);
        int enemyZ = read_int(enemyBonePtr + OFFSET_BONEPOS + 8);

        // delta = targetPos - myPos (integer math on float bit patterns)
        int dx = enemyX - myX;
        int dy = enemyY - myY;
        int dz = enemyZ - myZ;

        // FOV filtering (integer math, compare deltas directly)
        int yawDelta = dx - myYaw;
        int pitchDelta = dy - myPitch;
        int fovSq = yawDelta * yawDelta + pitchDelta * pitchDelta;
        int allowedFovSq = allowedFov * allowedFov;
        if (fovSq > allowedFovSq) continue;

        // Write aim angles (as int-bits)
        unsigned int mySoldier2 = read_int(localPlayer + OFFSET_SOLDIER);
        if (!mySoldier2) return;
        unsigned int aimAssist2 = read_int(mySoldier2 + OFFSET_AIMASSIST);
        if (!aimAssist2) return;
        write_int(aimAssist2 + OFFSET_AIMASSIST_YAW, dx);
        write_int(aimAssist2 + OFFSET_AIMASSIST_PITCH, dy);
        return; // Stop after first valid target for simplicity
    }
}
