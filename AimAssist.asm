; X86-assembly for Speedi13 ROP-Compiler - Minimal BF3 Aimbot Loop

;// Compiler settings (matching BF3_MinimapESP.asm)
;// <cfg=RandomPadding>true</cfg>
;// <cfg=RandomPaddingSize>128</cfg>
;// <cfg=SearchDlls>true</cfg>
;// <cfg=VirtualQuerySearch>false</cfg>
;// <cfg=PrintDebugOutput>false</cfg>

; Virtual register usage:
;// VR0 => GLOBAL_MinimumAddress (e.g., 0x10000, for pointer validation)
;// VR1 => enemyX
;// VR2 => myX / localPlayer
;// VR3 => myY / myTeam
;// VR4 => myZ / mySoldier
;// VR5 => enemyY
;// VR6 => enemyZ
;// VR7 => playerList base pointer
;// VR8 => player list iterator
;// VR9 => bone index (set by C code)

@l_Start:
    ; Hotkey check: VK_MENU (Alt key, bit 18, 0x40000)
    mov eax, 0x7FFE02E0
    mov eax, DWORD PTR[eax]
    mov VR9, eax           ; Store in VR9 for C code

    ; Get ClientPlayerManager
    mov eax, 0x0238EB58
    mov eax, DWORD PTR[eax]
    mov ecx, VR0
    sub eax, ecx
    jc End
    xchg eax, ecx

    ; Get LocalPlayer
    mov ebx, eax
    add ebx, 0x13C
    mov ebx, DWORD PTR[ebx]
    mov ecx, VR0
    sub ebx, ecx
    jc End
    xchg ebx, ecx
    mov VR2, ebx           ; LocalPlayer

    ; Get my team ID
    mov eax, VR2
    add eax, 0x1C34
    mov eax, DWORD PTR[eax]
    mov VR3, eax           ; myTeam

    ; Get my soldier
    mov eax, VR2
    add eax, 0x3A8
    mov eax, DWORD PTR[eax]
    mov ecx, VR0
    sub eax, ecx
    jc End
    xchg eax, ecx
    mov VR4, eax           ; mySoldier

    ; Get my bone component
    mov eax, VR4
    add eax, 0x490
    mov eax, DWORD PTR[eax]
    mov ecx, VR0
    sub eax, ecx
    jc End
    xchg eax, ecx

    ; Get my bone array
    mov ebx, eax
    add ebx, 0x150
    mov ebx, DWORD PTR[ebx]
    mov ecx, VR0
    sub ebx, ecx
    jc End
    xchg ebx, ecx

    ; Calculate myBonePtr = boneArray + VR9 * 0x50
    mov eax, VR9           ; Bone index from C code
    mov ecx, 0x50          ; Bone size
    imul eax, ecx          ; eax = VR9 * 0x50
    add eax, ebx           ; myBonePtr = boneArray + (boneIndex * boneSize)

    ; Get my bone position (Vec3)
    mov edx, eax
    add edx, 0x30
    mov edx, DWORD PTR[edx]  ; myX
    mov VR2, edx

    mov edx, eax
    add edx, 0x34
    mov edx, DWORD PTR[edx]  ; myY
    mov VR3, edx

    mov edx, eax
    add edx, 0x38
    mov edx, DWORD PTR[edx]  ; myZ
    mov VR4, edx

    ; Get player list base pointer
    mov eax, 0x0238EB58
    mov eax, DWORD PTR[eax]
    mov ecx, VR0
    sub eax, ecx
    jc End
    xchg eax, ecx

    add eax, 0x344
    mov eax, DWORD PTR[eax]
    mov ecx, VR0
    sub eax, ecx
    jc End
    xchg eax, ecx
    mov VR7, eax           ; playerList base

    ; Set up player loop (64 players, 4-byte stride)
    mov VR8, VR7           ; Iterator = playerList
    mov eax, VR7
    add eax, 256           ; 64 * 4
    mov VR10, eax          ; End pointer (use VR10 to avoid VR9 overwrite)

@Loop:
    mov eax, VR8
    mov ecx, VR10
    sub eax, ecx
    je l_Start
    js l_Start

    ; Get player pointer
    mov eax, VR8
    mov eax, DWORD PTR[eax]
    mov ecx, VR0
    sub eax, ecx
    jc NextPlayer
    xchg eax, ecx

    ; Skip if localPlayer
    mov ecx, VR2
    sub eax, ecx
    je NextPlayer
    xchg eax, ecx

    ; Team check
    mov ebx, eax
    add ebx, 0x1C34
    mov ebx, DWORD PTR[ebx]
    mov ecx, VR3
    sub ebx, ecx
    je NextPlayer
    xchg ebx, ecx

    ; Get enemy soldier
    mov ebx, eax
    add ebx, 0x3A8
    mov ebx, DWORD PTR[ebx]
    mov ecx, VR0
    sub ebx, ecx
    jc NextPlayer
    xchg ebx, ecx

    ; Health check
    mov ecx, ebx
    add ecx, 0x1E0
    mov ecx, DWORD PTR[ecx]
    mov edx, VR0
    sub ecx, edx
    jc NextPlayer
    xchg ecx, edx

    mov edx, ecx
    add edx, 0x20
    mov edx, DWORD PTR[edx]
    mov ecx, 0
    sub edx, ecx
    jc NextPlayer
    je NextPlayer

    ; Get enemy bone component
    mov ecx, ebx
    add ecx, 0x490
    mov ecx, DWORD PTR[ecx]
    mov edx, VR0
    sub ecx, edx
    jc NextPlayer
    xchg ecx, edx

    ; Get enemy bone array
    mov edx, ecx
    add edx, 0x150
    mov edx, DWORD PTR[edx]
    mov ecx, VR0
    sub edx, ecx
    jc NextPlayer
    xchg edx, ecx

    ; Calculate enemyBonePtr = boneArray + VR9 * 0x50
    mov eax, VR9           ; Bone index (ensure VR9 is not overwritten by end pointer!)
    mov ecx, 0x50          ; Bone size
    imul eax, ecx          ; eax = VR9 * 0x50
    add eax, edx           ; edx = enemy bone array base

    ; Get enemy bone position (Vec3)
    mov edx, eax
    add edx, 0x30
    mov edx, DWORD PTR[edx]  ; enemyX
    mov VR1, edx

    mov edx, eax
    add edx, 0x34
    mov edx, DWORD PTR[edx]  ; enemyY
    mov VR5, edx

    mov edx, eax
    add edx, 0x38
    mov edx, DWORD PTR[edx]  ; enemyZ
    mov VR6, edx

    ; Break after first valid target (for aimbot, you may want to process all players—remove this if so)
    jmp End

@NextPlayer:
    add VR8, 4             ; Next player
    jmp Loop

@End:
    nop
    jmp l_Start            ; Restart the whole logic (continuous loop)
