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
mov eax, [0x7FFE02E0]
mov ecx, 0x40000
and eax, ecx
sub eax, 0
je .end

; --- Time-based randomization for bone targeting ---
mov VR0, [GameTimeAddress]        ; Read game time or tick counter
and VR0, 0x3                      ; Mask to 0-3 (for 3 bones)
cmp VR0, 0
je .bone_head
cmp VR0, 1
je .bone_chest
mov VR8, 2                        ; pelvis
jmp .bone_selected

.bone_head:
mov VR8, 4
jmp .bone_selected

.bone_chest:
mov VR8, 3

.bone_selected:
; --- Get ClientPlayerManager ---
mov VR0, [0x0238EB58]
mov ecx, 0
sub VR0, ecx
je .end

; --- Get LocalPlayer ---
mov VR1, [VR0 + 0x13C]
mov ecx, 0
sub VR1, ecx
je .end

; --- Get my team ID ---
mov VR6, [VR1 + 0x1C34]

; --- Get my soldier ---
mov VR7, [VR1 + 0x3A8]
mov ecx, 0
sub VR7, ecx
je .end

; --- Get my bone position (e.g., head) ---
mov VR5, [VR7 + 0x490]         ; BoneCollisionComponent
mov ecx, 0
sub VR5, ecx
je .end
mov VR5, [VR5 + 0x150]         ; BoneTransforms array
mov ecx, 0
sub VR5, ecx
je .end
mov VR9, VR8
imul VR9, 0x50                 ; sizeof(LinearTransform) = 0x50
add VR5, VR9

; Store myPos (Vec3) to stack (scalar, safe)
movss xmm0, [VR5 + 0x30]
movss [esp-0x10], xmm0
movss xmm0, [VR5 + 0x34]
movss [esp-0x0C], xmm0
movss xmm0, [VR5 + 0x38]
movss [esp-0x08], xmm0

; --- Get my current yaw/pitch for FOV calculation ---
mov VR9, [VR7 + 0xA90]         ; AimAssist
mov ecx, 0
sub VR9, ecx
je .end
movss xmm4, [VR9 + 0x0C]       ; my_yaw
movss [esp-0x60], xmm4
movss xmm5, [VR9 + 0x18]       ; my_pitch
movss [esp-0x5C], xmm5

; --- Get allowed FOV from AimingPoseData ---
mov VR4, [VR7 + 0x19A0]        ; WeaponComponent (example offset)
mov ecx, 0
sub VR4, ecx
je .end
mov VR4, [VR4 + 0x38]          ; AimingPoseData* (example offset)
mov ecx, 0
sub VR4, ecx
je .end
movss xmm3, [VR4 + 0x08]       ; m_targetingFov
movss [esp-0x50], xmm3

; --- Get player list ---
mov VR2, [VR0 + 0x344]
mov VR5, 0                     ; i = 0

; --- Target search loop ---
.loop:
cmp VR5, 64
jge .no_target

mov VR3, [VR2 + VR5*4]
mov ecx, 0
sub VR3, ecx
je .next

cmp VR3, VR1
je .next

mov VR7, [VR3 + 0x1C34]
cmp VR7, VR6
je .next

mov VR7, [VR3 + 0x3A8]
mov ecx, 0
sub VR7, ecx
je .next

mov VR4, [VR7 + 0x1E0]
mov ecx, 0
sub VR4, ecx
je .next
fld dword [VR4 + 0x20]
fldz
fcomip st0, st1
fstp st0
jbe .next

; --- Get target bone position ---
mov VR4, [VR7 + 0x490]         ; BoneCollisionComponent
mov ecx, 0
sub VR4, ecx
je .next
mov VR4, [VR4 + 0x150]         ; BoneTransforms array
mov ecx, 0
sub VR4, ecx
je .next
mov VR9, VR8
imul VR9, 0x50
add VR4, VR9

; Store targetPos (Vec3) to stack (scalar, safe)
movss xmm1, [VR4 + 0x30]
movss [esp-0x20], xmm1
movss xmm1, [VR4 + 0x34]
movss [esp-0x1C], xmm1
movss xmm1, [VR4 + 0x38]
movss [esp-0x18], xmm1

; --- Calculate delta = targetPos - myPos (element-wise) ---
movss xmm2, [esp-0x20]         ; delta.x = target.x - my.x
subss xmm2, [esp-0x10]
movss [esp-0x30], xmm2

movss xmm2, [esp-0x1C]         ; delta.y = target.y - my.y
subss xmm2, [esp-0x0C]
movss [esp-0x2C], xmm2

movss xmm2, [esp-0x18]         ; delta.z = target.z - my.z
subss xmm2, [esp-0x08]
movss [esp-0x28], xmm2

; --- Calculate yaw = atan2(delta.x, delta.z) ---
fld dword [esp-0x30]           ; delta.x
fld dword [esp-0x28]           ; delta.z
fpatan
fstp dword [esp-0x40]          ; yaw

; --- Calculate dist = sqrt(delta.x^2 + delta.z^2) ---
fld dword [esp-0x30]           ; delta.x
fmul st0, st0
fld dword [esp-0x28]           ; delta.z
fmul st0, st0
faddp st1, st0
fsqrt
fstp dword [esp-0x44]          ; dist

; --- Calculate pitch = -atan2(delta.y, dist) ---
fld dword [esp-0x2C]           ; delta.y
fld dword [esp-0x44]           ; dist
fpatan
fchs
fstp dword [esp-0x48]          ; pitch

; --- FOV Filtering ---
; yaw_diff = abs(target_yaw - my_yaw)
movss xmm6, [esp-0x40]         ; target_yaw
subss xmm6, [esp-0x60]         ; my_yaw
movaps xmm7, xmm6
xorps xmm7, [AbsMask]          ; AbsMask = 0x80000000 (sign bit)
minss xmm6, xmm7               ; xmm6 = abs(yaw_diff)

; pitch_diff = abs(target_pitch - my_pitch)
movss xmm8, [esp-0x48]         ; target_pitch
subss xmm8, [esp-0x5C]         ; my_pitch
movaps xmm7, xmm8
xorps xmm7, [AbsMask]
minss xmm8, xmm7               ; xmm8 = abs(pitch_diff)

; fov = sqrt(yaw_diff^2 + pitch_diff^2)
movaps xmm0, xmm6
mulss xmm0, xmm0
movaps xmm1, xmm8
mulss xmm1, xmm1
addss xmm0, xmm1
sqrtss xmm0, xmm0
movss [esp-0x54], xmm0         ; fov

; Compare to allowed FOV
movss xmm1, [esp-0x50]         ; allowed FOV
ucomiss xmm0, xmm1
ja .next                       ; if fov > allowed, skip target

; --- Write aim angles ---
mov VR7, [VR1 + 0x3A8]
mov VR7, [VR7 + 0xA90]         ; AimAssist
mov ecx, 0
sub VR7, ecx
je .end
movss xmm0, [esp-0x40]
movss [VR7 + 0x0C], xmm0       ; m_yaw
movss xmm1, [esp-0x48]
movss [VR7 + 0x18], xmm1       ; m_pitch

jmp .end

.next:
inc VR5
jmp .loop

.no_target:
; No valid target found

.end:
ret

; --- Data section for AbsMask (sign bit mask for abs) ---
AbsMask: dd 0x80000000
