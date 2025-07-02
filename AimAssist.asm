; Battlefield 3 ROP-compiler compatible aimbot with FOV filtering, bone targeting, and Alt hotkey
; Update all offsets for your BF3 version!

; --- Register usage ---
; VR0: ClientPlayerManager
; VR1: LocalPlayer
; VR2: PlayerList
; VR3: CurrentPlayer
; VR4: BestTarget / temp
; VR5: Loop counter / temp
; VR6: MyTeam
; VR7: Temp
; VR8: BoneIndex
; VR9: Temp

; --- Offsets (examples, update for your version) ---
; 0x0238EB58 = ClientPlayerManager
; 0x13C      = LocalPlayer
; 0x344      = PlayerList
; 0x3A8      = Soldier
; 0x1C34     = TeamID
; 0x1E0      = HealthModule
; 0x20       = Health
; 0xA90      = AimAssist
; 0x0C       = m_yaw
; 0x18       = m_pitch
; 0x490      = BoneCollisionComponent
; 0x150      = BoneTransforms array
; 0x30       = Vec3 position in LinearTransform
; 0x19A0     = WeaponComponent (example, check SDK)
; 0x38       = AimingPoseData* in WeaponComponent (example, check SDK)
; 0x08       = m_targetingFov in AimingPoseData
; Bone indices: 4=head, 3=chest, 2=pelvis

; --- Hotkey: Only run if Alt key is pressed (VK_MENU, 0x12, bit 18) ---
; Hotkey: Only run if Alt key (VK_MENU/0x12, bit 18) is pressed
mov eax, [0x7FFE02E0]
mov ecx, 0x40000
and eax, ecx
sub eax, 0
je end

;-------------------------
; Time-based random bone selection
mov eax, [GameTimeAddress]
mov VR0, eax

mov eax, VR0
and eax, 0x3
mov VR0, eax

mov eax, VR0
sub eax, 0
je bone_head
mov eax, VR0
sub eax, 1
je bone_chest
mov eax, 2
mov VR8, eax
jmp bone_selected

@bone_head:
mov eax, 4
mov VR8, eax
jmp bone_selected

@bone_chest:
mov eax, 3
mov VR8, eax

@bone_selected:

;-------------------------
; Get ClientPlayerManager
mov eax, [0x0238EB58]
mov VR0, eax
mov eax, VR0
sub eax, 0
je end

; Get LocalPlayer
mov eax, VR0
add eax, 0x13C
mov eax, [eax]
mov VR1, eax
mov eax, VR1
sub eax, 0
je end

; Get my team ID
mov eax, VR1
add eax, 0x1C34
mov eax, [eax]
mov VR6, eax

; Get my soldier
mov eax, VR1
add eax, 0x3A8
mov eax, [eax]
mov VR7, eax
mov eax, VR7
sub eax, 0
je end

; Get my bone position (head/chest/etc)
mov eax, VR7
add eax, 0x490
mov eax, [eax]
mov VR5, eax
mov eax, VR5
sub eax, 0
je end
mov eax, VR5
add eax, 0x150
mov eax, [eax]
mov VR5, eax
mov eax, VR5
sub eax, 0
je end
mov eax, VR8
mov VR9, eax
mov eax, VR9
imul eax, 0x50
mov VR9, eax
mov eax, VR5
add eax, VR9
mov VR5, eax

; Store myPos (Vec3) to stack
mov eax, VR5
add eax, 0x30
movss xmm0, [eax]
movss [esp-0x10], xmm0
mov eax, VR5
add eax, 0x34
movss xmm0, [eax]
movss [esp-0x0C], xmm0
mov eax, VR5
add eax, 0x38
movss xmm0, [eax]
movss [esp-0x08], xmm0

; Get my current yaw/pitch for FOV calculation
mov eax, VR7
add eax, 0xA90
mov eax, [eax]
mov VR9, eax
mov eax, VR9
sub eax, 0
je end
mov eax, VR9
add eax, 0x0C
movss xmm4, [eax]
movss [esp-0x60], xmm4
mov eax, VR9
add eax, 0x18
movss xmm5, [eax]
movss [esp-0x5C], xmm5

; Get allowed FOV from AimingPoseData
mov eax, VR7
add eax, 0x19A0
mov eax, [eax]
mov VR4, eax
mov eax, VR4
sub eax, 0
je end
mov eax, VR4
add eax, 0x38
mov eax, [eax]
mov VR4, eax
mov eax, VR4
sub eax, 0
je end
mov eax, VR4
add eax, 0x08
movss xmm3, [eax]
movss [esp-0x50], xmm3

; Get player list
mov eax, VR0
add eax, 0x344
mov eax, [eax]
mov VR2, eax

; i = 0
mov eax, 0
mov VR5, eax

@loop:
; if i >= 64, stop
mov eax, VR5
sub eax, 64
jge no_target

; playerPtr = [VR2 + i*4]
mov eax, VR5
imul eax, 4
mov ebx, VR2
add eax, ebx
mov eax, [eax]
mov VR3, eax
mov eax, VR3
sub eax, 0
je next

; if playerPtr == LocalPlayer, skip
mov eax, VR3
sub eax, VR1
je next

; if player.team == myTeam, skip
mov eax, VR3
add eax, 0x1C34
mov eax, [eax]
mov VR7, eax
mov eax, VR7
sub eax, VR6
je next

; get player soldier
mov eax, VR3
add eax, 0x3A8
mov eax, [eax]
mov VR7, eax
mov eax, VR7
sub eax, 0
je next

; check player alive (player.soldier + 0x1E0 != 0, [ +0x20 ] > 0)
mov eax, VR7
add eax, 0x1E0
mov eax, [eax]
mov VR4, eax
mov eax, VR4
sub eax, 0
je next
mov eax, VR4
add eax, 0x20
fld dword [eax]
fldz
fcomip st0, st1
fstp st0
jbe next

; Get target bone position
mov eax, VR7
add eax, 0x490
mov eax, [eax]
mov VR4, eax
mov eax, VR4
sub eax, 0
je next
mov eax, VR4
add eax, 0x150
mov eax, [eax]
mov VR4, eax
mov eax, VR4
sub eax, 0
je next
mov eax, VR8
mov VR9, eax
mov eax, VR9
imul eax, 0x50
mov VR9, eax
mov eax, VR4
add eax, VR9
mov VR4, eax

; Store targetPos (Vec3) to stack
mov eax, VR4
add eax, 0x30
movss xmm1, [eax]
movss [esp-0x20], xmm1
mov eax, VR4
add eax, 0x34
movss xmm1, [eax]
movss [esp-0x1C], xmm1
mov eax, VR4
add eax, 0x38
movss xmm1, [eax]
movss [esp-0x18], xmm1

; delta = targetPos - myPos
movss xmm2, [esp-0x20]
subss xmm2, [esp-0x10]
movss [esp-0x30], xmm2
movss xmm2, [esp-0x1C]
subss xmm2, [esp-0x0C]
movss [esp-0x2C], xmm2
movss xmm2, [esp-0x18]
subss xmm2, [esp-0x08]
movss [esp-0x28], xmm2

; yaw = atan2(delta.x, delta.z)
fld dword [esp-0x30]
fld dword [esp-0x28]
fpatan
fstp dword [esp-0x40]

; dist = sqrt(delta.x^2 + delta.z^2)
fld dword [esp-0x30]
fmul st0, st0
fld dword [esp-0x28]
fmul st0, st0
faddp st1, st0
fsqrt
fstp dword [esp-0x44]

; pitch = -atan2(delta.y, dist)
fld dword [esp-0x2C]
fld dword [esp-0x44]
fpatan
fchs
fstp dword [esp-0x48]

; FOV Filtering
movss xmm6, [esp-0x40]
subss xmm6, [esp-0x60]
movaps xmm7, xmm6
xorps xmm7, [AbsMask]
minss xmm6, xmm7

movss xmm8, [esp-0x48]
subss xmm8, [esp-0x5C]
movaps xmm7, xmm8
xorps xmm7, [AbsMask]
minss xmm8, xmm7

movaps xmm0, xmm6
mulss xmm0, xmm0
movaps xmm1, xmm8
mulss xmm1, xmm1
addss xmm0, xmm1
sqrtss xmm0, xmm0
movss [esp-0x54], xmm0

movss xmm1, [esp-0x50]
ucomiss xmm0, xmm1
ja next

; Write aim angles
mov eax, VR1
add eax, 0x3A8
mov eax, [eax]
mov VR7, eax
mov eax, VR7
add eax, 0xA90
mov eax, [eax]
mov VR7, eax
mov eax, VR7
sub eax, 0
je end

mov eax, VR7
add eax, 0x0C
movss xmm0, [esp-0x40]
movss [eax], xmm0
mov eax, VR7
add eax, 0x18
movss xmm1, [esp-0x48]
movss [eax], xmm1

jmp end

@next:
; i++
mov eax, VR5
add eax, 1
mov VR5, eax
jmp loop

@no_target:
; No valid target found

@end:
ret
