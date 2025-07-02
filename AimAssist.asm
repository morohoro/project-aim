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

; Store myPos (Vec3) as integers
mov eax, VR5
add eax, 0x30
mov ebx, [eax]
mov [esp-0x10], ebx   ; X

mov eax, VR5
add eax, 0x34
mov ebx, [eax]
mov [esp-0x0C], ebx   ; Y

mov eax, VR5
add eax, 0x38
mov ebx, [eax]
mov [esp-0x08], ebx   ; Z

; Get my current yaw/pitch for FOV calculation (as integers)
mov eax, VR7
add eax, 0xA90
mov eax, [eax]
mov VR9, eax
mov eax, VR9
sub eax, 0
je end

mov eax, VR9
add eax, 0x0C
mov ebx, [eax]
mov [esp-0x60], ebx   ; Yaw

mov eax, VR9
add eax, 0x18
mov ebx, [eax]
mov [esp-0x5C], ebx   ; Pitch

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
mov ebx, [eax]
mov [esp-0x50], ebx    ; store FOV value as int-bits

; Get player list base pointer
mov eax, VR0
add eax, 0x344
mov eax, [eax]
mov VR2, eax

; Set i = 0
mov eax, 0
mov VR5, eax

@loop:
; if i >= 64: jump to no_target
mov eax, VR5
sub eax, 64
jge no_target

; Calculate player pointer: playerPtr = [VR2 + i*4]
mov eax, VR5
imul eax, 4
mov ebx, VR2
add eax, ebx
mov eax, [eax]
mov VR3, eax

; If playerPtr == 0, skip to next
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

; get player soldier, skip if null
mov eax, VR3
add eax, 0x3A8
mov eax, [eax]
mov VR7, eax
mov eax, VR7
sub eax, 0
je next

; check player alive (player.soldier + 0x1E0 != 0, [ +0x20 ] > 0 as int)
mov eax, VR7
add eax, 0x1E0
mov eax, [eax]
mov VR4, eax
mov eax, VR4
sub eax, 0
je next

mov eax, VR4
add eax, 0x20
mov ebx, [eax]         ; ebx = health (float bits as int)
mov eax, ebx
sub eax, 0
jle next               ; If health <= 0 as int, skip (best-effort: works for simple positive health)

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

; Store targetPos (Vec3) to stack as ints (float bits)
mov eax, VR4
add eax, 0x30
mov ebx, [eax]
mov [esp-0x20], ebx   ; target X

mov eax, VR4
add eax, 0x34
mov ebx, [eax]
mov [esp-0x1C], ebx   ; target Y

mov eax, VR4
add eax, 0x38
mov ebx, [eax]
mov [esp-0x18], ebx   ; target Z

; delta = targetPos - myPos (as integer math on float bit patterns)
mov eax, [esp-0x20]   ; target X
sub eax, [esp-0x10]   ; my X
mov [esp-0x30], eax   ; delta X

mov eax, [esp-0x1C]   ; target Y
sub eax, [esp-0x0C]   ; my Y
mov [esp-0x2C], eax   ; delta Y

mov eax, [esp-0x18]   ; target Z
sub eax, [esp-0x08]   ; my Z
mov [esp-0x28], eax   ; delta Z

; Compute distSq = delta.x^2 + delta.z^2 (integer math)
mov eax, [esp-0x30]          ; delta.x (int float bits)
imul eax, eax
mov ebx, eax                 ; ebx = delta.x^2

mov eax, [esp-0x28]          ; delta.z
imul eax, eax
add ebx, eax                 ; ebx = delta.x^2 + delta.z^2

mov [esp-0x44], ebx          ; Store distSq (no sqrt)

; For "yaw" and "pitch", you cannot calculate angle without a lookup table.
; Instead, you can store delta.x and delta.z, and later compare to your view direction's delta.x/delta.z (or use dot product approximation)
mov eax, [esp-0x30]          ; delta.x
mov [esp-0x40], eax

mov eax, [esp-0x2C]          ; delta.y
mov [esp-0x48], eax

; (If you need to compare to your current yaw/pitch, use the deltas directly or use a lookup table outside the ROP logic.)

; Integer-only FOV Filtering

; Horizontal (yaw) delta: abs(targetYaw - myYaw)
mov eax, [esp-0x40]     ; target yaw (integer bits, previously stored)
sub eax, [esp-0x60]     ; my yaw
mov ebx, eax
sar ebx, 31             ; sign extend
xor eax, ebx
sub eax, ebx            ; eax = abs(targetYaw - myYaw)
mov [esp-0x70], eax

; Vertical (pitch) delta: abs(targetPitch - myPitch)
mov eax, [esp-0x48]     ; target pitch
sub eax, [esp-0x5C]     ; my pitch
mov ebx, eax
sar ebx, 31
xor eax, ebx
sub eax, ebx            ; eax = abs(targetPitch - myPitch)
mov [esp-0x6C], eax

; FOV squared = yawDelta^2 + pitchDelta^2
mov eax, [esp-0x70]
imul eax, eax
mov ebx, eax

mov eax, [esp-0x6C]
imul eax, eax
add ebx, eax            ; ebx = FOV squared

mov [esp-0x54], ebx     ; store FOV squared

; Compare to allowed FOV (squared, integer)
mov eax, [esp-0x50]     ; allowed FOV (as int bits, float)
imul eax, eax           ; allowed FOV squared
cmp [esp-0x54], eax
ja next                 ; skip if outside allowed FOV

; Write aim angles (as integer bits)
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
mov ebx, [esp-0x40]     ; target yaw as int bits
mov [eax], ebx

mov eax, VR7
add eax, 0x18
mov ebx, [esp-0x48]     ; target pitch as int bits
mov [eax], ebx

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
