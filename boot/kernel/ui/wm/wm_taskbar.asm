; ============================================================================
; WM_TASKBAR.ASM - Window manager taskbar integration
; ============================================================================
; Single Responsibility: Draw and handle minimized windows in taskbar
; ============================================================================

[BITS 64]

; Taskbar item constants
WM_TB_ITEM_W        equ 100         ; Width of each taskbar item
WM_TB_ITEM_H        equ 20          ; Height
WM_TB_ITEM_MARGIN   equ 4           ; Margin between items
WM_TB_START_X       equ 60          ; After "Start" button

; ============================================================================
; WM_DRAW_TASKBAR_ITEMS - Draw minimized windows in taskbar
; Input: ESI = taskbar_y
; ============================================================================
wm_draw_taskbar_items:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r15d, esi                   ; r15 = taskbar_y
    add r15d, 4                     ; Padding

    mov r14d, WM_TB_START_X         ; r14 = current x position

    mov r13d, [wm_window_count]
    test r13d, r13d
    jz .done

    xor r12d, r12d                  ; r12 = index

.loop:
    cmp r12d, r13d
    jge .done

    mov eax, r12d
    imul eax, WM_ENT_SIZE
    lea rbx, [wm_windows + rax]

    ; Check if minimized (has MINIMIZED flag)
    test dword [rbx + WM_ENT_FLAGS], WM_WIN_MINIMIZED
    jz .next

    ; Draw taskbar item background
    mov edi, r14d
    mov esi, r15d
    mov edx, WM_TB_ITEM_W
    mov ecx, WM_TB_ITEM_H
    mov r8d, 0x00505050             ; Gray background
    call fill_rect

    ; Draw border
    mov edi, r14d
    mov esi, r15d
    mov edx, WM_TB_ITEM_W
    mov ecx, WM_TB_ITEM_H
    mov r8d, 0x00707070
    call draw_rect

    ; Draw title (truncated)
    mov edi, r14d
    add edi, 6
    mov esi, r15d
    add esi, 4
    mov rdx, [rbx + WM_ENT_TITLE]
    test rdx, rdx
    jz .no_title
    mov ecx, 0x00FFFFFF
    call video_text
.no_title:

    ; Advance x position
    add r14d, WM_TB_ITEM_W
    add r14d, WM_TB_ITEM_MARGIN

.next:
    inc r12d
    jmp .loop

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; WM_TASKBAR_CLICK - Handle click on taskbar
; Input: EDI = x, ESI = y
; Output: EAX = 1 if handled (window restored)
; ============================================================================
wm_taskbar_click:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, edi                   ; r12 = click_x

    ; Check if click is in taskbar items area
    cmp r12d, WM_TB_START_X
    jl .not_handled

    mov r14d, WM_TB_START_X         ; r14 = current x position

    mov r13d, [wm_window_count]
    test r13d, r13d
    jz .not_handled

    xor ebx, ebx                    ; ebx = index

.loop:
    cmp ebx, r13d
    jge .not_handled

    mov eax, ebx
    imul eax, WM_ENT_SIZE
    push rbx
    lea rbx, [wm_windows + rax]

    ; Check if minimized
    test dword [rbx + WM_ENT_FLAGS], WM_WIN_MINIMIZED
    jz .next_pop

    ; Check if click is in this item's bounds
    cmp r12d, r14d
    jl .next_pop
    mov eax, r14d
    add eax, WM_TB_ITEM_W
    cmp r12d, eax
    jge .advance

    ; Click hit this item - restore window
    ; Clear MINIMIZED, set VISIBLE
    and dword [rbx + WM_ENT_FLAGS], ~WM_WIN_MINIMIZED
    or dword [rbx + WM_ENT_FLAGS], WM_WIN_VISIBLE

    ; Focus this window
    pop rbx
    mov edi, ebx
    call wm_focus_window
    mov byte [wm_dirty], 1
    mov eax, 1
    jmp .done

.advance:
    ; Advance x for next item
    add r14d, WM_TB_ITEM_W
    add r14d, WM_TB_ITEM_MARGIN

.next_pop:
    pop rbx

.next:
    inc ebx
    jmp .loop

.not_handled:
    xor eax, eax

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

