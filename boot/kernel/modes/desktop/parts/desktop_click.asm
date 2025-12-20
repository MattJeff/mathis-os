; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_CLICK.ASM - Handle desktop clicks
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_HANDLE_CLICK - Process click at current mouse position
; ════════════════════════════════════════════════════════════════════════════
desktop_handle_click:
    push rax
    push rbx
    push rcx
    push rdx

    movzx eax, word [mouse_x]
    movzx ebx, word [mouse_y]

    ; Check Terminal icon (30, 30, 48x48)
    cmp eax, 30
    jl .check_files
    cmp eax, 78                     ; 30 + 48
    jg .check_files
    cmp ebx, 30
    jl .check_files
    cmp ebx, 78
    jg .check_files
    ; Clicked Terminal - switch to shell mode
    mov byte [mode_flag], 1
    jmp .done

.check_files:
    ; Check Files icon (30, 120, 48x48)
    cmp eax, 30
    jl .check_start
    cmp eax, 78
    jg .check_start
    cmp ebx, 120
    jl .check_start
    cmp ebx, 168                    ; 120 + 48
    jg .check_start
    ; Clicked Files - open Files window
    call desktop_open_files
    jmp .done

.check_start:
    ; Check Start button (4, taskbar_y+4, 50x20)
    mov ecx, [screen_height]
    sub ecx, DESKTOP_TASKBAR_H
    add ecx, 4                      ; taskbar_y + 4
    cmp eax, 4
    jl .done
    cmp eax, 54                     ; 4 + 50
    jg .done
    cmp ebx, ecx
    jl .done
    add ecx, 20
    cmp ebx, ecx
    jg .done
    ; Clicked Start - toggle menu (TODO)
    xor byte [desktop_menu_open], 1

.done:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
