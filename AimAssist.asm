; AimAssist.asm (ROP-Compiler compatible)
; Assumes:
;   - VR0 = bone index (set by loader/C: 4=head, 3=chest, 2=pelvis)
;   - All input checks (hotkey, randomization) handled externally

; Get ClientPlayerManager
mov eax, 0x0238EB58
mov eax, DWORD PTR[eax]
mov VR1, eax

; Get LocalPlayer
mov eax, VR1
add eax, 0x13C
mov eax, DWORD PTR[eax]
mov VR2, eax

; Get my team ID
mov eax, VR2
add eax, 0x1C34
mov eax, DWORD PTR[eax]
mov VR3, eax        ; myTeam

; Get my soldier
mov eax, VR2
add eax, 0x3A8
mov eax, DWORD PTR[eax]
mov VR4, eax        ; mySoldier

; Get my bone component
mov eax, VR4
add eax, 0x490
mov eax, DWORD PTR[eax]
mov VR5, eax

; Get my bone array
mov eax, VR5
add eax, 0x150
mov eax, DWORD PTR[eax]
mov VR5, eax

; Calculate myBonePtr = boneArray + VR0 * 0x50
mov eax, VR0           ; bone index (already set)
; If add eax, 0x50 supported, repeat VR0 times (for small set, unroll or loop)
add eax, 0x50          ; repeat as needed if possible/gadget exists

add eax, VR5           ; myBonePtr
mov VR6, eax

; Get my bone position (Vec3)
mov eax, VR6
add eax, 0x30
mov ebx, DWORD PTR[eax]    ; myX

mov eax, VR6
add eax, 0x34
mov ecx, DWORD PTR[eax]    ; myY

mov eax, VR6
add eax, 0x38
mov edx, DWORD PTR[eax]    ; myZ

; Get my yaw/pitch
mov eax, VR4
add eax, 0xA90
mov eax, DWORD PTR[eax]

mov esi, eax      ; aimAssist ptr

mov eax, esi
add eax, 0x0C
mov ebx, DWORD PTR[eax]    ; myYaw

mov eax, esi
add eax, 0x18
mov ecx, DWORD PTR[eax]    ; myPitch

; Get allowed FOV
mov eax, VR4
add eax, 0x19A0
mov eax, DWORD PTR[eax]
add eax, 0x38
mov eax, DWORD PTR[eax]
add eax, 0x08
mov edi, DWORD PTR[eax]    ; allowedFov

; Get player list base pointer
mov eax, VR1
add eax, 0x344
mov eax, DWORD PTR[eax]
mov VR7, eax               ; playerList

; Loop over 64 players (pseudo, since ROP-compiler can't do full loops, unroll or do once for demo)
; (Repeat this block for each i=0..63 in C, or handle externally and pass pointer in VR8)

; Example for first player (player 0)
mov eax, VR7
; add eax, i*4 (i=0 for demo, add accordingly in C)
mov eax, DWORD PTR[eax]    ; playerPtr

; Check playerPtr != 0 and not localPlayer
; (If needed, can check in C before passing pointer)

; Team check
mov ebx, eax
add ebx, 0x1C34
mov ebx, DWORD PTR[ebx]
sub ebx, VR3
je @next

; Get soldier pointer
mov ebx, eax
add ebx, 0x3A8
mov ebx, DWORD PTR[ebx]

; Alive check omitted for brevity (do in C if possible)

; Get enemy bone
mov ebx, ebx
add ebx, 0x490
mov ebx, DWORD PTR[ebx]
add ebx, 0x150
mov ebx, DWORD PTR[ebx]
add ebx, VR0
add ebx, 0x50     ; as above, simulate bone index * 0x50

; Get enemy bone position (Vec3)
mov eax, ebx
add eax, 0x30
mov esi, DWORD PTR[eax]    ; enemyX

mov eax, ebx
add eax, 0x34
mov edi, DWORD PTR[eax]    ; enemyY

mov eax, ebx
add eax, 0x38
mov ebp, DWORD PTR[eax]    ; enemyZ

; delta = enemyPos - myPos (integer math)
sub esi, ebx   ; dx = enemyX - myX
sub edi, ecx   ; dy = enemyY - myY

; (FOV filtering and write-back omitted for brevity)

@next:
; End of single iteration (for full implementation, repeat as needed externally or unroll)

ret
