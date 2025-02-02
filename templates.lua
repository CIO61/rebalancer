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
    ]]
}
