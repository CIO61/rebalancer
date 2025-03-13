local scaling_code = [[
    push ebx
    xor ebx, ebx
    cmp eax, threshold_1
    jnl label_1
    imul eax, multiplier_1
    add ebx, eax
    jmp end_label
        label_1:
    cmp eax, threshold_2
    jnl label_2
    sub eax, threshold_1
    add ebx, threshold_1*multiplier_1
    imul eax, multiplier_2
    add ebx, eax
    jmp end_label
        label_2:
    cmp eax, threshold_3
    jnl label_3
    sub eax, threshold_2
    add ebx, threshold_1*multiplier_1 + (threshold_2-threshold_1)*multiplier_2
    imul eax, multiplier_3
    add ebx, eax
    jmp end_label
        label_3:
    cmp eax, threshold_4
    jnl label_4
    sub eax, threshold_3
    add ebx, threshold_1*multiplier_1 + (threshold_2-threshold_1)*multiplier_2 + (threshold_3-threshold_2)*multiplier_3
    imul eax, multiplier_4
    add ebx, eax
    jmp end_label
        label_4:
    add ebx, threshold_1*multiplier_1 + (threshold_2-threshold_1)*multiplier_2 + (threshold_3-threshold_2)*multiplier_3 + (threshold_4-threshold_3)*multiplier_4
        end_label:
    mov eax, ebx
]]
return {
    continuous_scaling_code = scaling_code .. [[
        pop ebx
    ]],
    discrete_scaling_code = scaling_code .. [[
        push edx
        mov edx, 0x147AE148
        imul edx
        mov eax, edx
        shr eax, 1
        pop edx
        imul eax, 0x19
        pop ebx
    ]],
    range_split_asm1 = [[
        push eax
        movsx eax, word [edi+esi+0x6A2]
        cmp eax, 0x16
        jne lbl_1
        mov eax, archer_range
        jmp lbl_4
            lbl_1:
        cmp eax, 0x46
        jne lbl_2
        mov eax, arabbow_range
        jmp lbl_4
            lbl_2:
        cmp eax, 0x4A
        jne lbl_3
        mov eax, horse_archer_range
        jmp lbl_4
            lbl_3:
        pop eax
        mov eax, [eax*4+0x5B6358]
        jmp lbl_5
            lbl_4:
        add esp, 0x04
            lbl_5:
        nop
    ]],
    range_split_asm2 = [[
        cmp eax,0x00
        jne xbow
        mov ebp, archer_range*archer_range
        jmp controlOneExit
            xbow:
        cmp eax,0x01
        jne arabbow
        mov ebp, xbow_range*xbow_range
        jmp controlOneExit
            arabbow:
        cmp eax,0x30
        jne horse_archer
        mov ebp, arabbow_range*arabbow_range
        jmp controlOneExit
            horse_archer:
        cmp eax,0x34
        jne fbal
        mov ebp, horse_archer_range*horse_archer_range
        jmp controlOneExit
            fbal:
        cmp eax,0x37
        jne controlOneExit
        mov ebp, fbal_range*fbal_range
            controlOneExit:
        nop
    ]],
    range_split_asm3 = [[
        cmp eax,0x00
        jne xbow
        mov esi, archer_range*archer_range
        jmp controlTwoExit
            xbow:
        cmp eax,0x01
        jne arabbow
        mov esi, xbow_range*xbow_range
        jmp controlTwoExit
            arabbow:
        cmp eax,0x30
        jne horse_archer
        mov esi, arabbow_range*arabbow_range
        jmp controlTwoExit
            horse_archer:
        cmp eax,0x34
        jne fbal
        mov esi, horse_archer_range*horse_archer_range
        jmp controlTwoExit
            fbal:
        cmp eax,0x37
        jne controlTwoExit
        mov esi, fbal_range*fbal_range
            controlTwoExit:
        nop
    ]],
    range_split_asm4 = [[
        push eax
        movzx eax,word [ebp+0x145D0CA]
        cmp eax,0x16
        jne xbow
        mov esi, archer_range*archer_range
        jmp controlThreeExit
            xbow:
        cmp eax,0x17
        jne arabbow
        mov esi, xbow_range*xbow_range
        jmp controlThreeExit
            arabbow:
        cmp eax,0x46
        jne horse_archer
        mov esi, arabbow_range*arabbow_range
        jmp controlThreeExit
            horse_archer:
        cmp eax,0x4A
        jne controlThreeExit
        mov esi, horse_archer_range*horse_archer_range
            controlThreeExit:
        pop eax
        cmp eax,0x21
    ]],
    range_split_asm5 = [[
        cmp eax,0x00
        jne xbow
        mov eax, archer_range*archer_range
        jmp controlFourExit
            xbow:
        cmp eax,0x01
        jne arabbow
        mov eax, xbow_range*xbow_range
        jmp controlFourExit
            arabbow:
        cmp eax,0x30
        jne horse_archer
        mov eax, arabbow_range*arabbow_range
        jmp controlFourExit
            horse_archer:
        cmp eax,0x34
        jne fbal
        mov eax, horse_archer_range*horse_archer_range
        jmp controlFourExit
            fbal:
        cmp eax,0x37
        jne controlFourExit
        mov eax, fbal_range*fbal_range
            controlFourExit:
        nop
    ]],
    range_split_asm6 = [[
        cmp ecx,0x00
        jne xbow
        mov edx, archer_range*archer_range
        jmp controlFiveExit
            xbow:
        cmp ecx,0x01
        jne arabbow
        mov edx, xbow_range*xbow_range
        jmp controlFiveExit
            arabbow:
        cmp ecx,0x30
        jne horse_archer
        mov edx, arabbow_range*arabbow_range
        jmp controlFiveExit
            horse_archer:
        cmp ecx,0x34
        jne fbal
        mov edx, horse_archer_range*horse_archer_range
        jmp controlFiveExit
            fbal:
        cmp ecx,0x37
        jne controlFiveExit
        mov edx, fbal_range*fbal_range
            controlFiveExit:
        nop
    ]],
    range_split_asm7 = [[
        cmp eax,0x12
        jne towerbal
        mov ebp, treb_range*treb_range
        jmp exit_point
            towerbal:
        mov ebp, towerbal_range*towerbal_range
            exit_point:
        nop
    ]],
    range_split_asm8 = [[
        cmp eax,0x12
        jne towerbal
        mov esi, treb_range*treb_range
        jmp exit_point
            towerbal:
        mov esi, towerbal_range*towerbal_range
            exit_point:
        nop
    ]],
    range_split_asm9 = [[
        cmp eax,0x12
        jne towerbal
        mov eax, treb_range*treb_range
        jmp exit_point
            towerbal:
        mov eax, towerbal_range*towerbal_range
            exit_point:
        nop
    ]],
    range_split_asm10 = [[
        cmp ecx,0x12
        jne towerbal
        mov edx, treb_range*treb_range
        jmp exit_point
            towerbal:
        mov edx, towerbal_range*towerbal_range
            exit_point:
        nop
    ]],
    range_split_asm11 = [[
        cmp ecx,0x02
        jne treb
        mov ecx, catapult_range
        jmp exit_point
            treb:
        mov ecx, treb_range
            exit_point:
        nop
    ]],
    range_split_asm12 = [[
        add edx,ecx
        cmp edx, firethrower_range*firethrower_range
    ]]
}
