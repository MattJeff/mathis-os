; ============================================================================
; WM_DRAW.ASM - Draw all windows
; ============================================================================

[BITS 64]

; Colors
WM_COL_TITLE_BG     equ 0x00404040
WM_COL_TITLE_FG     equ 0x00FFFFFF
WM_COL_BORDER       equ 0x00606060
WM_COL_BG           equ 0x00282828
WM_COL_CLOSE        equ 0x00C04040
WM_COL_FOCUSED      equ 0x00007ACC

; ============================================================================
; WM_DRAW_ALL - Draw all visible windows (only if dirty)
; ============================================================================
wm_draw_all:
    ; Decrement close grace counter
    cmp byte [wm_close_grace], 0
    je .no_grace
    dec byte [wm_close_grace]
.no_grace:

    ; Always redraw if windows exist (desktop redraws background each frame)
    ; Skip only if no windows AND not dirty
    cmp dword [wm_window_count], 0
    jne .do_draw
    cmp byte [wm_dirty], 0
    je .skip
.do_draw:

    push rbx
    push r12
    push r13

    mov r13d, [wm_window_count] ; r13 = count (preserved across calls)
    test r13d, r13d
    jz .done

    xor r12d, r12d              ; r12 = index

.loop:
    cmp r12d, r13d
    jge .done

    ; Get window entry
    mov eax, r12d
    imul eax, WM_ENT_SIZE
    lea rbx, [wm_windows + rax]

    ; Skip if not visible
    test dword [rbx + WM_ENT_FLAGS], WM_WIN_VISIBLE
    jz .next

    ; Draw this window
    mov rdi, rbx
    call wm_draw_window

.next:
    inc r12d
    jmp .loop

.done:
    ; Clear dirty flag
    mov byte [wm_dirty], 0

    pop r13
    pop r12
    pop rbx
.skip:
    ret

; ============================================================================
; WM_DRAW_WINDOW - Draw single window
; Input: RDI = window entry pointer
; ============================================================================
wm_draw_window:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi

    mov r12d, [rbx + WM_ENT_X]
    mov r13d, [rbx + WM_ENT_Y]
    mov r14d, [rbx + WM_ENT_W]
    mov r15d, [rbx + WM_ENT_H]

    ; Draw window background
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, r15d
    mov r8d, WM_COL_BG
    call fill_rect

    ; Draw border (focused = blue, unfocused = gray)
    mov r8d, WM_COL_BORDER
    test dword [rbx + WM_ENT_FLAGS], WM_WIN_FOCUSED
    jz .draw_border
    mov r8d, WM_COL_FOCUSED
.draw_border:
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, r15d
    call draw_rect

    ; Draw title bar
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, WM_TITLE_H
    mov r8d, WM_COL_TITLE_BG
    call fill_rect

    ; Draw macOS-style control buttons (close/minimize/maximize)
    ; EBX = focused flag for button colors
    xor eax, eax
    test dword [rbx + WM_ENT_FLAGS], WM_WIN_FOCUSED
    jz .ctrl_unfocused
    mov eax, 1
.ctrl_unfocused:
    push rbx                    ; Save window ptr
    mov ebx, eax                ; focused flag
    call wm_draw_controls
    pop rbx                     ; Restore window ptr

    ; Draw title text (offset for buttons: 3 buttons + spacing)
    mov rdi, [rbx + WM_ENT_TITLE]
    test rdi, rdi
    jz .no_title
    mov edi, r12d
    add edi, 60                 ; After 3 buttons (10 + 12*3 + 8*2 = ~60)
    mov esi, r13d
    add esi, 6
    mov rdx, [rbx + WM_ENT_TITLE]
    mov ecx, WM_COL_TITLE_FG
    call video_text
.no_title:

    ; Draw save icon for editor windows (right side of title bar)
    cmp dword [rbx + WM_ENT_TYPE], WM_TYPE_EDITOR
    jne .no_save_icon
    call wm_draw_save_icon
.no_save_icon:

    ; Draw resize handle in bottom-right corner
    call wm_draw_resize_handle

    ; Draw content based on window type
    mov eax, [rbx + WM_ENT_TYPE]
    cmp eax, WM_TYPE_FILES
    jne .check_editor

    ; Files window content
    mov edi, r12d
    add edi, 2                  ; Border padding
    mov esi, r13d
    add esi, WM_TITLE_H         ; Below title bar
    mov edx, r14d
    sub edx, 4                  ; Content width (minus borders)
    mov ecx, r15d
    sub ecx, WM_TITLE_H
    sub ecx, 2                  ; Content height (minus title and border)
    call wmf_draw_content
    jmp .done

.check_editor:
    cmp eax, WM_TYPE_EDITOR
    jne .check_widget

    ; Editor window content
    mov edi, r12d
    add edi, 2
    mov esi, r13d
    add esi, WM_TITLE_H
    mov edx, r14d
    sub edx, 4
    mov ecx, r15d
    sub ecx, WM_TITLE_H
    sub ecx, 2
    call wme_draw_content
    jmp .done

.check_widget:
    ; Draw content via widget if set
    mov rdi, [rbx + WM_ENT_WIDGET]
    test rdi, rdi
    jz .done
    call widget_draw

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Include window controls module
%include "ui/wm/wm_controls.asm"
