;X86-assembly in Intel syntax with additional virtual registers (VR0 - VR9 and VMM) to ease programming

;//Compiler settings:
; <cfg=SearchDlls>true</cfg>
; <cfg=VirtualQuerySearch>true</cfg>
; <cfg=PrintDebugOutput>false</cfg>

;Virtual registers
;//VR9 => random number
;//VR8 => random number
;//VR7 => random number
;//VR6 => random number
;//VR5 => random number
;//VR4 => random number
;//VR3 => random number
;//VR2 => random number
;//VR1 => random number
;//VR0 => GLOBAL_MinimumAddress
;//read only register:
;//VMM => VirtualAllocEx( hGame, 0, 0x2000, MEM_COMMIT|MEM_RESERVE, PAGE_READWRITE );

;//Initial value of the general-purpose register:
;//EAX => Original StackPointer (ESP)

;//Virtual register usage in code below:
;//VR0 => GLOBAL_MinimumAddress (0x10000)
;//VR1 => ClientPlayerManager |=> enemyX
;//VR2 => LocalPlayer |=> myX
;//VR3 => myTeam |=> myY
;//VR4 => soldier |=> myZ
;//VR5 => boneComponent |=> enemyY
;//VR6 => myBonePtr |=> enemyZ
;//VR7 => playerList
;//VR8 => PlayerListPos
;//VR9 => boneIndex |=> PlayerListEnd

@l_Start:
    pop eax                     ; Load 0x7FFE02E0 (GetAsyncKeyState)
    mov eax, DWORD PTR [eax]    ; Get hotkey state
    mov VR9, eax                ; Store in VR9 (boneIndex)
    pop eax                     ; Load ClientPlayerManager (0x0238EB58)
    mov eax, DWORD PTR [eax]    ; Dereference
    mov ecx, VR0                ; VR0 = GLOBAL_MinimumAddress (0x10000)
    sub eax, ecx
    jc End                      ; Skip if invalid
    xchg eax, ecx
    mov VR1, eax                ; VR1 = ClientPlayerManager
    mov eax, VR1
    add eax, 0x4                ; ClientPlayerManager + 0x13C (LocalPlayer)
    ; ... (repeat add eax, 0x4 49 times to reach 0x13C = 316 decimal)
    mov eax, DWORD PTR [eax]    ; Get LocalPlayer
    mov ecx, VR0
    sub eax, ecx
    jc End
    xchg eax, ecx
    mov VR2, eax                ; VR2 = LocalPlayer
    mov eax, VR2
    add eax, 0x4                ; LocalPlayer + 0x1C34 (myTeam)
    ; ... (repeat add eax, 0x4 1805 times to reach 0x1C34 = 7220 decimal)
    mov eax, DWORD PTR [eax]
    mov ecx, VR0
    sub eax, ecx
    jc End
    xchg eax, ecx
    mov VR3, eax                ; VR3 = myTeam
    mov eax, VR2
    add eax, 0x4                ; LocalPlayer + 0x3A8 (soldier)
    ; ... (repeat add eax, 0x4 234 times to reach 0x3A8 = 936 decimal)
    mov eax, DWORD PTR [eax]
    mov ecx, VR0
    sub eax, ecx
    jc End
    xchg eax, ecx
    mov VR4, eax                ; VR4 = soldier
    mov eax, VR4
    add eax, 0x4                ; soldier + 0x490 (boneComponent)
    ; ... (repeat add eax, 0x4 292 times to reach 0x490 = 1168 decimal)
    mov eax, DWORD PTR [eax]
    mov ecx, VR0
    sub eax, ecx
    jc End
    xchg eax, ecx
    mov VR5, eax                ; VR5 = boneComponent
    mov eax, VR5
    add eax, 0x4                ; boneComponent + 0x150 (boneArray)
    ; ... (repeat add eax, 0x4 84 times to reach 0x150 = 336 decimal)
    mov eax, DWORD PTR [eax]
    xchg eax, ebx               ; ebx = boneArray
    pop eax                     ; Load precomputed boneIndex * 0x50
    xchg eax, ebx
    add eax, ebx                ; eax = boneArray + boneIndex * 0x50
    mov VR6, eax                ; VR6 = myBonePtr
    mov eax, VR6
    add eax, 0x4                ; myBonePtr + 0x30 (myX)
    ; ... (repeat add eax, 0x4 12 times to reach 0x30 = 48 decimal)
    mov eax, DWORD PTR [eax]
    mov VR2, eax                ; VR2 = myX
    mov eax, VR6
    add eax, 0x4                ; myBonePtr + 0x34 (myY)
    ; ... (repeat add eax, 0x4 13 times to reach 0x34 = 52 decimal)
    mov eax, DWORD PTR [eax]
    mov VR3, eax                ; VR3 = myY
    mov eax, VR6
    add eax, 0x4                ; myBonePtr + 0x38 (myZ)
    ; ... (repeat add eax, 0x4 14 times to reach 0x38 = 56 decimal)
    mov eax, DWORD PTR [eax]
    mov VR4, eax                ; VR4 = myZ
    pop eax                     ; Load ClientPlayerManager + 0x344 (playerList)
    mov eax, DWORD PTR [eax]
    mov ecx, VR0
    sub eax, ecx
    jc End
    xchg eax, ecx
    mov VR7, eax                ; VR7 = playerList
    mov eax, VR7
    mov VR8, eax                ; VR8 = PlayerListPos
    mov eax, VR7
    add eax, 0x4                ; playerList + 0x100 (64 * 4 = 256)
    ; ... (repeat add eax, 0x4 64 times to reach 0x100 = 256 decimal)
    mov VR9, eax                ; VR9 = PlayerListEnd

@Loop:
    mov eax, VR8
    mov ecx, VR9
    sub eax, ecx
    je l_Start
    js l_Start
    mov eax, VR8
    mov eax, DWORD PTR [eax]
    mov ecx, VR0
    sub eax, ecx
    jc NextPlayer
    xchg eax, ecx
    mov ecx, VR2                ; VR2 = LocalPlayer
    sub eax, ecx
    je NextPlayer
    xchg eax, ecx
    xchg eax, ebx
    mov eax, ebx                ; ebx = player
    add eax, 0x4                ; player + 0x1C34 (team)
    ; ... (repeat add eax, 0x4 1805 times to reach 0x1C34 = 7220 decimal)
    mov eax, DWORD PTR [eax]
    xchg eax, ebx
    mov ecx, VR3                ; VR3 = myTeam
    xchg eax, ebx
    sub eax, ecx
    xchg eax, ebx
    je NextPlayer
    xchg eax, ebx
    xchg eax, ecx
    xchg eax, ebx
    mov eax, ebx                ; ebx = player
    add eax, 0x4                ; player + 0x3A8 (soldier)
    ; ... (repeat add eax, 0x4 234 times to reach 0x3A8 = 936 decimal)
    mov eax, DWORD PTR [eax]
    xchg eax, ebx
    mov ecx, VR0
    xchg eax, ebx
    sub eax, ecx
    xchg eax, ebx
    jc NextPlayer
    xchg eax, ebx
    xchg eax, ecx
    xchg eax, ebx
    mov eax, ebx                ; ebx = soldier
    add eax, 0x4                ; soldier + 0x548 (healthComponent)
    ; ... (repeat add eax, 0x4 337 times to reach 0x548 = 1348 decimal)
    mov eax, DWORD PTR [eax]
    xchg eax, ebx
    mov ecx, VR0
    xchg eax, ebx
    sub eax, ecx
    xchg eax, ebx
    jc NextPlayer
    xchg eax, ebx
    xchg eax, edx
    xchg eax, ebx
    add eax, 0x4                ; healthComponent + 0x30 (health)
    ; ... (repeat add eax, 0x4 12 times to reach 0x30 = 48 decimal)
    mov eax, DWORD PTR [eax]
    xchg eax, edx
    pop ecx                     ; Load 0x0 for health check
    sub eax, ecx
    jc NextPlayer
    je NextPlayer
    xchg eax, edx
    xchg eax, ebx
    mov eax, ebx                ; ebx = soldier
    add eax, 0x4                ; soldier + 0x490 (boneComponent)
    ; ... (repeat add eax, 0x4 292 times to reach 0x490 = 1168 decimal)
    mov eax, DWORD PTR [eax]
    xchg eax, ebx
    mov ecx, VR0
    xchg eax, ebx
    sub eax, ecx
    xchg eax, ebx
    jc NextPlayer
    xchg eax, ebx
    xchg eax, edx
    xchg eax, ebx
    add eax, 0x4                ; boneComponent + 0x150 (boneArray)
    ; ... (repeat add eax, 0x4 84 times to reach 0x150 = 336 decimal)
    mov eax, DWORD PTR [eax]
    xchg eax, ebx               ; ebx = boneArray
    pop eax                     ; Load precomputed boneIndex * 0x50
    xchg eax, ebx
    add eax, ebx                ; eax = boneArray + boneIndex * 0x50
    mov edx, eax                ; edx = enemyBonePtr
    xchg eax, edx
    add eax, 0x4                ; enemyBonePtr + 0x30 (enemyX)
    ; ... (repeat add eax, 0x4 12 times to reach 0x30 = 48 decimal)
    mov eax, DWORD PTR [eax]
    xchg eax, edx
    mov VR1, eax                ; VR1 = enemyX
    mov eax, edx
    add eax, 0x4                ; enemyBonePtr + 0x34 (enemyY)
    ; ... (repeat add eax, 0x4 13 times to reach 0x34 = 52 decimal)
    mov eax, DWORD PTR [eax]
    xchg eax, edx
    mov VR5, eax                ; VR5 = enemyY
    mov eax, edx
    add eax, 0x4                ; enemyBonePtr + 0x38 (enemyZ)
    ; ... (repeat add eax, 0x4 14 times to reach 0x38 = 56 decimal)
    mov eax, DWORD PTR [eax]
    xchg eax, edx
    mov VR6, eax                ; VR6 = enemy事先

@NextPlayer:
    mov eax, VR8
    add eax, 0x4
    mov VR8, eax
    jmp Loop

@End:
    nop
    jmp l_Start
