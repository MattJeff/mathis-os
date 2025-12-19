; ════════════════════════════════════════════════════════════════════════════
; TASKBAR.ASM - Taskbar Widget (SOLID - Single Responsibility)
; ════════════════════════════════════════════════════════════════════════════
; Bottom taskbar with start button, process indicator, and clock.
; Inherits from Widget base class.
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; TASKBAR STRUCTURE (extends Widget - 64 + 32 = 96 bytes)
; ════════════════════════════════════════════════════════════════════════════
; Offset  Size  Field            Description
; ──────────────────────────────────────────────────────────────────────────
;   0-63   64   base             Widget base structure
;  64       4   bg_color         Background color
;  68       4   border_color     Top border color
;  72       4   start_btn_x      Start button X position
;  76       4   start_btn_w      Start button width
;  80       1   start_menu_open  1 if menu is open
;  81       7   padding          Reserved
;  88       8   reserved         Future use
; ════════════════════════════════════════════════════════════════════════════

TASKBAR_WIDGET_SIZE     equ 96

; Structure offsets (after Widget base)
TB_BG_COLOR             equ 64
TB_BORDER_COLOR         equ 68
TB_START_BTN_X          equ 72
TB_START_BTN_W          equ 76
TB_START_MENU_OPEN      equ 80
TB_RESERVED             equ 88

; Default colors
TB_DEF_BG               equ 0x00303030      ; Dark gray
TB_DEF_BORDER           equ 0x00606060      ; Light gray
TB_DEF_START_BG         equ 0x00505050      ; Start button bg

; ════════════════════════════════════════════════════════════════════════════
; TASKBAR V-TABLE
; ════════════════════════════════════════════════════════════════════════════
taskbar_vtable:
    dq taskbar_draw             ; VT_DRAW
    dq taskbar_on_key           ; VT_ON_KEY
    dq taskbar_on_click         ; VT_ON_CLICK
    dq taskbar_on_focus         ; VT_ON_FOCUS
    dq taskbar_destroy_impl     ; VT_DESTROY

; ════════════════════════════════════════════════════════════════════════════
; TASKBAR_CREATE - Create a new taskbar widget
; Input:  none (auto-positions at bottom of screen)
; Output: RAX = taskbar pointer (or 0 on failure)
; ════════════════════════════════════════════════════════════════════════════
taskbar_create:
    push rbx

    ; Allocate taskbar
    mov rdi, TASKBAR_WIDGET_SIZE
    call kmalloc
    test rax, rax
    jz .fail

    mov rbx, rax                    ; rbx = taskbar

    ; Initialize widget base
    lea rax, [taskbar_vtable]
    mov qword [rbx + W_VTABLE], rax

    ; Position: full width at bottom
    mov dword [rbx + W_X], 0
    mov eax, [screen_height]
    sub eax, TASKBAR_H
    mov dword [rbx + W_Y], eax
    mov eax, [screen_width]
    mov dword [rbx + W_W], eax
    mov dword [rbx + W_H], TASKBAR_H

    mov dword [rbx + W_FLAGS], WF_VISIBLE | WF_ENABLED | WF_DIRTY
    mov dword [rbx + W_ID], 0
    mov qword [rbx + W_PARENT], 0
    mov qword [rbx + W_USERDATA], 0
    mov qword [rbx + W_CHILDREN], 0

    ; Generate unique ID
    mov eax, [widget_next_id]
    mov [rbx + W_ID], eax
    inc dword [widget_next_id]

    ; Initialize taskbar-specific fields
    mov dword [rbx + TB_BG_COLOR], TB_DEF_BG
    mov dword [rbx + TB_BORDER_COLOR], TB_DEF_BORDER
    mov dword [rbx + TB_START_BTN_X], 4
    mov dword [rbx + TB_START_BTN_W], 40
    mov byte [rbx + TB_START_MENU_OPEN], 0
    mov qword [rbx + TB_RESERVED], 0

    mov rax, rbx
    jmp .done

.fail:
    xor eax, eax

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TASKBAR_DRAW - Draw the taskbar
; Input:  RDI = taskbar pointer
; ════════════════════════════════════════════════════════════════════════════
taskbar_draw:
    push rbx
    push r12
    push r13

    mov rbx, rdi                    ; rbx = taskbar

    ; Get position
    mov r12d, [rbx + W_X]           ; x
    mov r13d, [rbx + W_Y]           ; y

    ; Draw background
    mov edi, r12d
    mov esi, r13d
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, [rbx + TB_BG_COLOR]
    call fill_rect

    ; Draw top border (highlight)
    mov edi, r12d
    mov esi, r13d
    mov edx, [rbx + W_W]
    mov ecx, 1                      ; 1 pixel high
    mov r8d, [rbx + TB_BORDER_COLOR]
    call fill_rect

    ; Draw Start button
    mov edi, [rbx + TB_START_BTN_X]
    mov esi, r13d
    add esi, 2
    mov edx, [rbx + TB_START_BTN_W]
    mov ecx, TASKBAR_H
    sub ecx, 4
    mov r8d, TB_DEF_START_BG
    call fill_rect

    ; "Start" text
    mov edi, [rbx + TB_START_BTN_X]
    add edi, 4
    mov esi, r13d
    add esi, 4
    mov rdx, str_start
    mov ecx, COL_TEXT
    call video_text

    ; Process indicator at x=55
    mov edi, 55
    mov esi, r13d
    add esi, 4
    call taskbar_draw_proc_indicator

    ; Clock on right side
    mov edi, [rbx + W_W]
    sub edi, 45
    mov esi, r13d
    add esi, 4
    call taskbar_draw_clock

    ; Draw start menu if open
    cmp byte [rbx + TB_START_MENU_OPEN], 1
    jne .no_menu
    call taskbar_draw_start_menu

.no_menu:
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TASKBAR_DRAW_PROC_INDICATOR - Draw process count
; Input:  EDI = x, ESI = y
; ════════════════════════════════════════════════════════════════════════════
taskbar_draw_proc_indicator:
    push rax
    push rbx
    push rdx
    push rdi
    push rsi

    mov rbx, rdi                    ; x
    mov r8d, esi                    ; y

    ; Get process count
    call get_process_count
    add al, '0'
    mov [tb_proc_buf + 1], al

    ; Draw text
    mov edi, ebx
    mov esi, r8d
    mov rdx, tb_proc_buf
    mov ecx, COL_TEXT
    call video_text

    pop rsi
    pop rdi
    pop rdx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; TASKBAR_DRAW_CLOCK - Draw HH:MM clock
; Input:  EDI = x, ESI = y
; ════════════════════════════════════════════════════════════════════════════
taskbar_draw_clock:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    mov r8d, edi                    ; Save x
    mov r9d, esi                    ; Save y

    ; Calculate time from ticks
    mov rax, [tick_count]
    xor rdx, rdx
    mov rbx, 100
    div rbx                         ; rax = seconds

    xor rdx, rdx
    mov rbx, 60
    div rbx                         ; rax = minutes, rdx = seconds
    push rdx

    xor rdx, rdx
    mov rbx, 60
    div rbx                         ; rax = hours, rdx = minutes
    push rdx

    ; Hours mod 24
    xor rdx, rdx
    mov rbx, 24
    div rbx
    mov rax, rdx

    ; Build "HH:MM"
    xor rdx, rdx
    mov rbx, 10
    div rbx
    add al, '0'
    mov [tb_clock_buf], al
    add dl, '0'
    mov [tb_clock_buf + 1], dl

    mov byte [tb_clock_buf + 2], ':'

    pop rax                         ; minutes
    xor rdx, rdx
    mov rbx, 10
    div rbx
    add al, '0'
    mov [tb_clock_buf + 3], al
    add dl, '0'
    mov [tb_clock_buf + 4], dl

    pop rdx                         ; discard seconds

    ; Draw text
    mov edi, r8d
    mov esi, r9d
    mov rdx, tb_clock_buf
    mov ecx, COL_TEXT
    call video_text

    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; TASKBAR_DRAW_START_MENU - Draw the start menu
; ════════════════════════════════════════════════════════════════════════════
taskbar_draw_start_menu:
    push rbx
    push r12

    ; Menu position
    mov r12d, [screen_height]
    sub r12d, TASKBAR_H
    sub r12d, 70

    ; Background
    mov edi, 4
    mov esi, r12d
    mov edx, 80
    mov ecx, 68
    mov r8d, TB_DEF_START_BG
    call fill_rect

    ; Border
    mov edi, 4
    mov esi, r12d
    mov edx, 80
    mov ecx, 68
    mov r8d, TB_DEF_BORDER
    call draw_rect

    ; Menu items
    ; Terminal
    mov edi, 12
    lea esi, [r12d + 6]
    mov rdx, str_menu_term
    mov ecx, COL_TEXT
    call video_text

    ; Files
    mov edi, 12
    lea esi, [r12d + 20]
    mov rdx, str_menu_files
    mov ecx, COL_TEXT
    call video_text

    ; 3D
    mov edi, 12
    lea esi, [r12d + 34]
    mov rdx, str_menu_3d
    mov ecx, COL_TEXT
    call video_text

    ; About
    mov edi, 12
    lea esi, [r12d + 48]
    mov rdx, str_menu_about
    mov ecx, COL_TEXT
    call video_text

    ; Reboot
    mov edi, 12
    lea esi, [r12d + 62]
    mov rdx, str_menu_reboot
    mov ecx, COL_CLOSE_BTN
    call video_text

    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TASKBAR_ON_KEY - Handle key input
; Input:  RDI = taskbar, ESI = scancode
; Output: EAX = 1 if handled, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
taskbar_on_key:
    xor eax, eax                    ; Not handled
    ret

; ════════════════════════════════════════════════════════════════════════════
; TASKBAR_ON_CLICK - Handle mouse click
; Input:  RDI = taskbar, ESI = x, EDX = y, ECX = button
; Output: EAX = 1 if handled, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
taskbar_on_click:
    push rbx
    push r12
    push r13

    mov rbx, rdi                    ; taskbar
    mov r12d, esi                   ; click x
    mov r13d, edx                   ; click y

    ; Only handle left click
    cmp ecx, 1
    jne .not_handled

    ; Check if click is on Start button
    mov eax, [rbx + TB_START_BTN_X]
    cmp r12d, eax
    jl .check_menu

    add eax, [rbx + TB_START_BTN_W]
    cmp r12d, eax
    jge .check_menu

    ; Start button clicked - toggle menu
    xor byte [rbx + TB_START_MENU_OPEN], 1
    ; Also toggle global start_menu_open for compatibility
    xor byte [start_menu_open], 1
    or dword [rbx + W_FLAGS], WF_DIRTY
    mov eax, 1
    jmp .done

.check_menu:
    ; Check if start menu is open and click is inside it
    cmp byte [rbx + TB_START_MENU_OPEN], 0
    je .not_handled

    ; Menu bounds: x=4-84, y=(screen_height - TASKBAR_H - 70) to (screen_height - TASKBAR_H)
    cmp r12d, 4
    jl .close_menu
    cmp r12d, 84
    jge .close_menu

    mov eax, [screen_height]
    sub eax, TASKBAR_H
    sub eax, 70
    cmp r13d, eax
    jl .close_menu

    mov eax, [screen_height]
    sub eax, TASKBAR_H
    cmp r13d, eax
    jge .close_menu

    ; Inside menu - determine which item clicked
    mov eax, [screen_height]
    sub eax, TASKBAR_H
    sub eax, 70
    sub r13d, eax                   ; r13d = offset from menu top

    ; Item 1: Terminal (0-13)
    cmp r13d, 14
    jl .click_terminal

    ; Item 2: Files (14-27)
    cmp r13d, 28
    jl .click_files

    ; Item 3: 3D (28-41)
    cmp r13d, 42
    jl .click_3d

    ; Item 4: About (42-55)
    cmp r13d, 56
    jl .click_about

    ; Item 5: Reboot (56-68)
    jmp .click_reboot

.click_terminal:
    mov byte [mode_flag], 1         ; Terminal mode
    jmp .close_menu

.click_files:
    mov byte [mode_flag], 4         ; Files mode
    jmp .close_menu

.click_3d:
    mov byte [mode_flag], 3         ; 3D mode
    jmp .close_menu

.click_about:
    ; TODO: Show about dialog
    jmp .close_menu

.click_reboot:
    ; Triple fault reboot
    lidt [.null_idt]
    int 0
.null_idt:
    dw 0
    dd 0

.close_menu:
    mov byte [rbx + TB_START_MENU_OPEN], 0
    mov byte [start_menu_open], 0
    or dword [rbx + W_FLAGS], WF_DIRTY
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TASKBAR_ON_FOCUS - Handle focus change
; Input:  RDI = taskbar, ESI = gained (1/0)
; ════════════════════════════════════════════════════════════════════════════
taskbar_on_focus:
    ret

; ════════════════════════════════════════════════════════════════════════════
; TASKBAR_DESTROY_IMPL - Cleanup
; Input:  RDI = taskbar
; ════════════════════════════════════════════════════════════════════════════
taskbar_destroy_impl:
    ret

; ════════════════════════════════════════════════════════════════════════════
; TASKBAR_TOGGLE_MENU - Toggle start menu visibility
; Input:  RDI = taskbar
; ════════════════════════════════════════════════════════════════════════════
taskbar_toggle_menu:
    test rdi, rdi
    jz .done
    xor byte [rdi + TB_START_MENU_OPEN], 1
    xor byte [start_menu_open], 1
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
tb_proc_buf:    db 'P0', 0
tb_clock_buf:   db '00:00', 0
