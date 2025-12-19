; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_APP.ASM - Desktop Application using Widget System
; ════════════════════════════════════════════════════════════════════════════
; Phase 4+5: SOLID Refactor - Desktop with widgets + FS event listener
;
; Features:
;   - Widget-based UI (containers, buttons, labels)
;   - FS event listener: auto-refresh icons when files created/deleted
;
; Structure:
;   - Root container (fullscreen)
;     - Desktop area container (icons)
;       - Terminal icon (button)
;       - Files icon (button)
;       - 3D Demo icon (button)
;       - Dynamic file icons (from filesystem)
;     - Taskbar container (bottom bar)
;       - Start button
;       - Clock label
;   - Start menu container (popup, hidden by default)
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; CONSTANTS
; ════════════════════════════════════════════════════════════════════════════
DESKTOP_TASKBAR_H       equ 24
DESKTOP_ICON_W          equ 64
DESKTOP_ICON_H          equ 64
DESKTOP_ICON_SPACING    equ 80
DESKTOP_BG_COLOR        equ 0x00205080      ; Teal/cyan
DESKTOP_TASKBAR_COLOR   equ 0x00303030      ; Dark gray
DESKTOP_TASKBAR_HL      equ 0x00505050      ; Highlight

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP STATE
; ════════════════════════════════════════════════════════════════════════════
section .data

; Widget pointers
desktop_root:           dq 0    ; Root container
desktop_area:           dq 0    ; Desktop icons area
desktop_taskbar:        dq 0    ; Taskbar container
desktop_start_btn:      dq 0    ; Start button
desktop_clock_lbl:      dq 0    ; Clock label
desktop_icon_term:      dq 0    ; Terminal icon button
desktop_icon_files:     dq 0    ; Files icon button
desktop_icon_3d:        dq 0    ; 3D Demo icon button
desktop_start_menu:     dq 0    ; Start menu container (popup)

; Start menu items
desktop_menu_term:      dq 0    ; Menu: Terminal
desktop_menu_files:     dq 0    ; Menu: Files
desktop_menu_3d:        dq 0    ; Menu: 3D Demo
desktop_menu_about:     dq 0    ; Menu: About
desktop_menu_reboot:    dq 0    ; Menu: Reboot

; State
desktop_menu_open:      db 0    ; Start menu visibility
desktop_initialized:    db 0    ; Init flag
desktop_last_buttons:   db 0    ; Previous mouse button state (for click detection)
desktop_needs_refresh:  db 0    ; Set to 1 when FS event received
desktop_fs_registered:  db 0    ; 1 if FS listener registered

; Dynamic icons (files from root directory)
DESKTOP_MAX_FILE_ICONS  equ 8
desktop_file_icons:     times DESKTOP_MAX_FILE_ICONS dq 0  ; Pointers to file icon widgets
desktop_file_icon_count: db 0   ; Number of active file icons

; Icon grid layout
DESKTOP_ICON_START_X    equ 30      ; First column X
DESKTOP_ICON_START_Y    equ 270     ; Start Y (below static icons)
DESKTOP_ICON_GRID_W     equ 80      ; Grid cell width
DESKTOP_ICON_GRID_H     equ 80      ; Grid cell height
DESKTOP_ICONS_PER_ROW   equ 4       ; Icons per row

; FS readdir buffer
desktop_dirent_buf:     times (64 * DESKTOP_MAX_FILE_ICONS) db 0
desktop_root_path:      db "/", 0
desktop_name_bufs:      times (32 * DESKTOP_MAX_FILE_ICONS) db 0  ; Name string storage

; Strings
desktop_str_start:      db "Start", 0
desktop_str_clock:      db "12:00", 0
desktop_str_terminal:   db "Terminal", 0
desktop_str_files:      db "Files", 0
desktop_str_3d:         db "3D Demo", 0
desktop_str_about:      db "About", 0
desktop_str_reboot:     db "Reboot", 0

section .text

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_APP_INIT - Initialize desktop with widget system
; Output: EAX = 1 on success, 0 on failure
; ════════════════════════════════════════════════════════════════════════════
desktop_app_init:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Check if already initialized
    cmp byte [desktop_initialized], 1
    je .already_init

    ; Get screen dimensions
    mov r12d, [screen_width]
    mov r13d, [screen_height]

    ; ═══════════════════════════════════════════════════════════════════════
    ; CREATE ROOT CONTAINER (fullscreen)
    ; ═══════════════════════════════════════════════════════════════════════
    xor esi, esi                    ; x = 0
    xor edx, edx                    ; y = 0
    mov ecx, r12d                   ; w = screen_width
    mov r8d, r13d                   ; h = screen_height
    call container_create
    test rax, rax
    jz .fail
    mov [desktop_root], rax
    mov rbx, rax                    ; rbx = root

    ; Set background color for root
    mov rdi, rax
    mov esi, DESKTOP_BG_COLOR
    call container_set_bg_color

    ; ═══════════════════════════════════════════════════════════════════════
    ; CREATE DESKTOP AREA (icons area, above taskbar)
    ; ═══════════════════════════════════════════════════════════════════════
    xor esi, esi                    ; x = 0
    xor edx, edx                    ; y = 0
    mov ecx, r12d                   ; w = screen_width
    mov r8d, r13d
    sub r8d, DESKTOP_TASKBAR_H      ; h = screen_height - taskbar
    call container_create
    test rax, rax
    jz .fail
    mov [desktop_area], rax
    mov r14, rax                    ; r14 = desktop_area

    ; Add desktop_area to root
    mov rdi, rbx                    ; parent = root
    mov rsi, r14                    ; child = desktop_area
    call container_add_child

    ; ═══════════════════════════════════════════════════════════════════════
    ; CREATE DESKTOP ICONS (buttons with custom draw)
    ; ═══════════════════════════════════════════════════════════════════════
    ; Terminal icon at (30, 30)
    mov esi, 30                     ; x
    mov edx, 30                     ; y
    mov ecx, DESKTOP_ICON_W         ; w
    mov r8d, DESKTOP_ICON_H         ; h
    lea r9, [desktop_str_terminal]
    call button_create
    test rax, rax
    jz .fail
    mov [desktop_icon_term], rax

    ; Set callback
    mov rdi, rax
    lea rsi, [desktop_cb_terminal]
    call button_set_callback

    ; Hide button visually (only for click detection)
    mov rdi, [desktop_icon_term]
    mov eax, [rdi + W_FLAGS]
    and eax, ~WF_VISIBLE            ; Not visible, but still enabled for clicks
    mov [rdi + W_FLAGS], eax

    ; Add to desktop_area
    mov rdi, r14
    mov rsi, [desktop_icon_term]
    call container_add_child

    ; Files icon at (30, 110)
    mov esi, 30
    mov edx, 110
    mov ecx, DESKTOP_ICON_W
    mov r8d, DESKTOP_ICON_H
    lea r9, [desktop_str_files]
    call button_create
    test rax, rax
    jz .fail
    mov [desktop_icon_files], rax

    mov rdi, rax
    lea rsi, [desktop_cb_files]
    call button_set_callback

    ; Hide button visually (only for click detection)
    mov rdi, [desktop_icon_files]
    mov eax, [rdi + W_FLAGS]
    and eax, ~WF_VISIBLE
    mov [rdi + W_FLAGS], eax

    mov rdi, r14
    mov rsi, [desktop_icon_files]
    call container_add_child

    ; ═══════════════════════════════════════════════════════════════════════
    ; CREATE TASKBAR
    ; ═══════════════════════════════════════════════════════════════════════
    xor esi, esi                    ; x = 0
    mov edx, r13d
    sub edx, DESKTOP_TASKBAR_H      ; y = screen_height - taskbar
    mov ecx, r12d                   ; w = screen_width
    mov r8d, DESKTOP_TASKBAR_H      ; h = taskbar height
    call container_create
    test rax, rax
    jz .fail
    mov [desktop_taskbar], rax
    mov r15, rax                    ; r15 = taskbar

    ; Set taskbar background color
    mov rdi, r15
    mov esi, DESKTOP_TASKBAR_COLOR
    call container_set_bg_color

    ; Add taskbar to root
    mov rdi, rbx
    mov rsi, r15
    call container_add_child

    ; ═══════════════════════════════════════════════════════════════════════
    ; CREATE START BUTTON (in taskbar)
    ; ═══════════════════════════════════════════════════════════════════════
    mov esi, 4                      ; x = 4
    mov edx, r13d
    sub edx, DESKTOP_TASKBAR_H
    add edx, 2                      ; y = taskbar_y + 2
    mov ecx, 50                     ; w = 50
    mov r8d, 20                     ; h = 20
    lea r9, [desktop_str_start]
    call button_create
    test rax, rax
    jz .fail
    mov [desktop_start_btn], rax

    mov rdi, rax
    lea rsi, [desktop_cb_start]
    call button_set_callback

    ; Add to taskbar
    mov rdi, r15
    mov rsi, [desktop_start_btn]
    call container_add_child

    ; ═══════════════════════════════════════════════════════════════════════
    ; CREATE CLOCK LABEL (in taskbar, right side)
    ; ═══════════════════════════════════════════════════════════════════════
    mov esi, r12d
    sub esi, 50                     ; x = screen_width - 50
    mov edx, r13d
    sub edx, DESKTOP_TASKBAR_H
    add edx, 4                      ; y = taskbar_y + 4
    mov ecx, 45                     ; w = 45
    mov r8d, 16                     ; h = 16
    lea r9, [desktop_str_clock]
    call label_create
    test rax, rax
    jz .fail
    mov [desktop_clock_lbl], rax

    ; Set colors
    mov rdi, rax
    mov esi, 0x00FFFFFF             ; fg = white
    mov edx, 0x00000000             ; bg = transparent
    call label_set_color

    ; Add to taskbar
    mov rdi, r15
    mov rsi, [desktop_clock_lbl]
    call container_add_child

    ; ═══════════════════════════════════════════════════════════════════════
    ; CREATE START MENU (popup, initially hidden)
    ; ═══════════════════════════════════════════════════════════════════════
    mov esi, 4                      ; x = 4
    mov edx, r13d
    sub edx, DESKTOP_TASKBAR_H
    sub edx, 98                     ; y = above taskbar
    mov ecx, 100                    ; w = 100
    mov r8d, 96                     ; h = 96 (4 items)
    call container_create
    test rax, rax
    jz .fail
    mov [desktop_start_menu], rax

    ; Set start menu background color
    mov rdi, rax
    mov esi, DESKTOP_TASKBAR_HL
    call container_set_bg_color

    ; Set layout to vertical
    mov rdi, [desktop_start_menu]
    mov esi, LAYOUT_VERTICAL
    call container_set_layout

    ; Hide start menu initially
    mov rdi, [desktop_start_menu]
    mov eax, [rdi + W_FLAGS]
    and eax, ~WF_VISIBLE
    mov [rdi + W_FLAGS], eax

    ; Add menu items (buttons)
    ; Terminal
    mov esi, 4
    mov edx, 4
    mov ecx, 92
    mov r8d, 20
    lea r9, [desktop_str_terminal]
    call button_create
    test rax, rax
    jz .fail
    mov [desktop_menu_term], rax
    mov rdi, rax
    lea rsi, [desktop_cb_terminal]
    call button_set_callback
    mov rdi, [desktop_start_menu]
    mov rsi, [desktop_menu_term]
    call container_add_child

    ; Files
    mov esi, 4
    mov edx, 26
    mov ecx, 92
    mov r8d, 20
    lea r9, [desktop_str_files]
    call button_create
    test rax, rax
    jz .fail
    mov [desktop_menu_files], rax
    mov rdi, rax
    lea rsi, [desktop_cb_files]
    call button_set_callback
    mov rdi, [desktop_start_menu]
    mov rsi, [desktop_menu_files]
    call container_add_child

    ; About
    mov esi, 4
    mov edx, 48
    mov ecx, 92
    mov r8d, 20
    lea r9, [desktop_str_about]
    call button_create
    test rax, rax
    jz .fail
    mov [desktop_menu_about], rax
    mov rdi, rax
    lea rsi, [desktop_cb_about]
    call button_set_callback
    mov rdi, [desktop_start_menu]
    mov rsi, [desktop_menu_about]
    call container_add_child

    ; Reboot
    mov esi, 4
    mov edx, 70
    mov ecx, 92
    mov r8d, 20
    lea r9, [desktop_str_reboot]
    call button_create
    test rax, rax
    jz .fail
    mov [desktop_menu_reboot], rax
    mov rdi, rax
    lea rsi, [desktop_cb_reboot]
    call button_set_callback
    ; Red color for reboot
    mov rdi, [desktop_menu_reboot]
    mov esi, 0x00FF6060             ; fg = red
    mov edx, 0x00404040             ; bg
    mov ecx, 0x00606060             ; border
    call button_set_colors
    mov rdi, [desktop_start_menu]
    mov rsi, [desktop_menu_reboot]
    call container_add_child

    ; Mark as initialized
    mov byte [desktop_initialized], 1

    ; ═══════════════════════════════════════════════════════════════════════
    ; REGISTER FS EVENT LISTENER (Phase 5: Observer Pattern)
    ; ═══════════════════════════════════════════════════════════════════════
    cmp byte [desktop_fs_registered], 1
    je .already_init

    lea rdi, [desktop_on_fs_event]
    call fs_add_listener
    test eax, eax
    jz .skip_register              ; Failed to register, continue anyway
    mov byte [desktop_fs_registered], 1

.skip_register:
    ; Load initial file icons from filesystem
    call desktop_refresh_icons

.already_init:
    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_APP_DRAW - Draw the desktop
; ════════════════════════════════════════════════════════════════════════════
desktop_app_draw:
    push rbx

    ; Check if FS events triggered a refresh
    call desktop_check_refresh

    ; Draw root container (recursive)
    mov rdi, [desktop_root]
    test rdi, rdi
    jz .no_root
    call widget_draw

.no_root:
    ; Draw start menu if open
    cmp byte [desktop_menu_open], 1
    jne .no_menu
    mov rdi, [desktop_start_menu]
    test rdi, rdi
    jz .no_menu
    call widget_draw

.no_menu:
    ; Draw custom icons (graphical part)
    call desktop_draw_icons

    ; Draw mouse cursor (always on top)
    call draw_mouse_cursor

    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_DRAW_ICONS - Draw graphical icon representations
; ════════════════════════════════════════════════════════════════════════════
desktop_draw_icons:
    push rbx
    push r12

    ; Terminal icon graphic at (46, 38)
    mov edi, 46
    mov esi, 38
    mov edx, COL_CYAN
    call draw_icon_terminal

    ; Files icon graphic at (46, 118)
    mov edi, 46
    mov esi, 118
    mov edx, COL_YELLOW
    call draw_icon_folder

    ; Draw dynamic file icons
    movzx ecx, byte [desktop_file_icon_count]
    test ecx, ecx
    jz .no_file_icons

    xor r12d, r12d                  ; index
.draw_file_icon_loop:
    cmp r12d, ecx
    jge .no_file_icons

    ; Get icon widget and call its draw method
    mov rdi, [desktop_file_icons + r12*8]
    test rdi, rdi
    jz .next_file_icon

    ; Call widget_draw (uses vtable)
    push rcx
    call widget_draw
    pop rcx

.next_file_icon:
    inc r12d
    jmp .draw_file_icon_loop

.no_file_icons:
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_APP_INPUT - Handle desktop input
; Input: ESI = scancode (keyboard) or mouse event
; Output: EAX = 1 if handled
; ════════════════════════════════════════════════════════════════════════════
desktop_app_input:
    push rbx

    ; Check for mouse click (detect rising edge of left button)
    mov al, [mouse_buttons]
    mov bl, [desktop_last_buttons]
    mov [desktop_last_buttons], al

    ; Check if left button just pressed (was 0, now 1)
    test bl, 1                      ; Was left button pressed before?
    jnz .check_key                  ; Yes, not a new click
    test al, 1                      ; Is left button pressed now?
    jz .check_key                   ; No, no click

    ; Get mouse position
    movzx eax, word [mouse_x]
    movzx ebx, word [mouse_y]

    ; Check start menu first if open
    cmp byte [desktop_menu_open], 1
    jne .check_start_btn

    ; Check if click is in start menu
    mov rdi, [desktop_start_menu]
    mov esi, eax                    ; x
    mov edx, ebx                    ; y
    call desktop_point_in_widget
    test eax, eax
    jz .close_menu

    ; Dispatch click to start menu
    mov rdi, [desktop_start_menu]
    movzx esi, word [mouse_x]
    movzx edx, word [mouse_y]
    mov ecx, 1                      ; left click
    call widget_on_click
    jmp .handled

.close_menu:
    mov byte [desktop_menu_open], 0
    ; Hide menu
    mov rdi, [desktop_start_menu]
    mov eax, [rdi + W_FLAGS]
    and eax, ~WF_VISIBLE
    mov [rdi + W_FLAGS], eax
    jmp .handled

.check_start_btn:
    ; Check if click on start button
    mov rdi, [desktop_start_btn]
    movzx esi, word [mouse_x]
    movzx edx, word [mouse_y]
    call desktop_point_in_widget
    test eax, eax
    jz .check_icons

    ; Toggle start menu
    xor byte [desktop_menu_open], 1
    ; Update visibility
    mov rdi, [desktop_start_menu]
    mov eax, [rdi + W_FLAGS]
    cmp byte [desktop_menu_open], 1
    jne .hide_menu
    or eax, WF_VISIBLE
    jmp .set_vis
.hide_menu:
    and eax, ~WF_VISIBLE
.set_vis:
    mov [rdi + W_FLAGS], eax
    jmp .handled

.check_icons:
    ; Check terminal icon
    mov rdi, [desktop_icon_term]
    movzx esi, word [mouse_x]
    movzx edx, word [mouse_y]
    call desktop_point_in_widget
    test eax, eax
    jz .check_files_icon
    call desktop_cb_terminal
    jmp .handled

.check_files_icon:
    mov rdi, [desktop_icon_files]
    movzx esi, word [mouse_x]
    movzx edx, word [mouse_y]
    call desktop_point_in_widget
    test eax, eax
    jz .not_handled
    call desktop_cb_files
    jmp .handled

.check_key:
    ; Handle keyboard shortcuts here if needed
    jmp .not_handled

.handled:
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_POINT_IN_WIDGET - Check if point is inside widget
; Input: RDI = widget, ESI = x, EDX = y
; Output: EAX = 1 if inside, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
desktop_point_in_widget:
    test rdi, rdi
    jz .outside

    ; Check x bounds
    cmp esi, [rdi + W_X]
    jl .outside
    mov eax, [rdi + W_X]
    add eax, [rdi + W_W]
    cmp esi, eax
    jge .outside

    ; Check y bounds
    cmp edx, [rdi + W_Y]
    jl .outside
    mov eax, [rdi + W_Y]
    add eax, [rdi + W_H]
    cmp edx, eax
    jge .outside

    mov eax, 1
    ret

.outside:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; CALLBACKS - Desktop action handlers
; ════════════════════════════════════════════════════════════════════════════

desktop_cb_start:
    ; Toggle start menu (handled in input)
    ret

desktop_cb_terminal:
    ; Switch to terminal mode
    mov byte [desktop_menu_open], 0
    mov byte [mode_flag], 1         ; MODE_TERMINAL
    ret

desktop_cb_files:
    ; Switch to files mode
    mov byte [desktop_menu_open], 0
    mov byte [mode_flag], 4         ; MODE_FILES
    ret

desktop_cb_about:
    ; Show about dialog (TODO: implement dialog)
    mov byte [desktop_menu_open], 0
    ret

desktop_cb_reboot:
    ; Reboot system
    mov al, 0xFE
    out 0x64, al
    hlt
    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_APP_CLEANUP - Free desktop resources
; ════════════════════════════════════════════════════════════════════════════
desktop_app_cleanup:
    ; Destroy root (will recursively destroy children)
    mov rdi, [desktop_root]
    test rdi, rdi
    jz .done
    call widget_destroy

    ; Clear pointers
    mov qword [desktop_root], 0
    mov qword [desktop_area], 0
    mov qword [desktop_taskbar], 0
    mov byte [desktop_initialized], 0

.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_ON_FS_EVENT - Callback for filesystem events (Observer Pattern)
; ════════════════════════════════════════════════════════════════════════════
; Input: EDI = event type (FS_EVT_*), RSI = path (null-terminated)
; Called when files are created, deleted, renamed, etc.
; ════════════════════════════════════════════════════════════════════════════
desktop_on_fs_event:
    push rbx
    push r12

    mov r12d, edi                   ; Save event type

    ; Only care about CREATE, DELETE, MKDIR events for root folder
    cmp edi, FS_EVT_CREATE
    je .mark_refresh
    cmp edi, FS_EVT_DELETE
    je .mark_refresh
    cmp edi, FS_EVT_MKDIR
    je .mark_refresh
    jmp .done

.mark_refresh:
    ; Mark that desktop needs icon refresh
    mov byte [desktop_needs_refresh], 1

    ; If currently in desktop mode, mark root for redraw
    cmp byte [mode_flag], 2         ; MODE_DESKTOP
    jne .done

    mov rdi, [desktop_root]
    test rdi, rdi
    jz .done
    or dword [rdi + W_FLAGS], WF_DIRTY

.done:
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_CHECK_REFRESH - Check if refresh needed and perform it
; ════════════════════════════════════════════════════════════════════════════
; Call this from desktop_app_draw to handle pending refreshes
; ════════════════════════════════════════════════════════════════════════════
desktop_check_refresh:
    cmp byte [desktop_needs_refresh], 0
    je .done

    ; Clear flag
    mov byte [desktop_needs_refresh], 0

    ; Refresh file icons from filesystem
    call desktop_refresh_icons

    ; Trigger full redraw
    mov rdi, [desktop_root]
    test rdi, rdi
    jz .done
    or dword [rdi + W_FLAGS], WF_DIRTY

.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_REFRESH_ICONS - Refresh file icons from filesystem
; ════════════════════════════════════════════════════════════════════════════
; Scans root directory and creates icon widgets for each file/folder
; ════════════════════════════════════════════════════════════════════════════
desktop_refresh_icons:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; ═══════════════════════════════════════════════════════════════════════
    ; STEP 1: Clear existing dynamic icons
    ; ═══════════════════════════════════════════════════════════════════════
    movzx ecx, byte [desktop_file_icon_count]
    test ecx, ecx
    jz .no_clear

    xor ebx, ebx                    ; index
.clear_loop:
    cmp ebx, ecx
    jge .clear_done

    ; Get icon pointer
    mov rdi, [desktop_file_icons + rbx*8]
    test rdi, rdi
    jz .next_clear

    ; Free the widget (kfree)
    call kfree
    mov qword [desktop_file_icons + rbx*8], 0

.next_clear:
    inc ebx
    jmp .clear_loop

.clear_done:
    mov byte [desktop_file_icon_count], 0

.no_clear:
    ; ═══════════════════════════════════════════════════════════════════════
    ; STEP 2: Get filesystem service
    ; ═══════════════════════════════════════════════════════════════════════
    mov edi, SVC_FS
    call get_service
    test rax, rax
    jz .refresh_done                ; No FS service

    mov r15, rax                    ; r15 = fs_vtable

    ; ═══════════════════════════════════════════════════════════════════════
    ; STEP 3: Read root directory
    ; ═══════════════════════════════════════════════════════════════════════
    lea rdi, [desktop_root_path]    ; path = "/"
    lea rsi, [desktop_dirent_buf]   ; buffer
    mov edx, DESKTOP_MAX_FILE_ICONS ; max entries
    call [r15 + FS_READDIR]

    cmp eax, -1
    je .refresh_done                ; Error
    test eax, eax
    jz .refresh_done                ; No entries

    mov r14d, eax                   ; r14 = entry count

    ; ═══════════════════════════════════════════════════════════════════════
    ; STEP 4: Create icon for each entry
    ; ═══════════════════════════════════════════════════════════════════════
    xor r12d, r12d                  ; r12 = index
    lea r13, [desktop_dirent_buf]   ; r13 = current dirent

.create_loop:
    cmp r12d, r14d
    jge .refresh_done
    cmp r12d, DESKTOP_MAX_FILE_ICONS
    jge .refresh_done

    ; Calculate position in grid
    ; x = DESKTOP_ICON_START_X + (index % ICONS_PER_ROW) * GRID_W
    ; y = DESKTOP_ICON_START_Y + (index / ICONS_PER_ROW) * GRID_H
    mov eax, r12d
    xor edx, edx
    mov ecx, DESKTOP_ICONS_PER_ROW
    div ecx                         ; eax = row, edx = col

    imul eax, DESKTOP_ICON_GRID_H
    add eax, DESKTOP_ICON_START_Y
    mov r8d, eax                    ; r8d = y

    imul edx, DESKTOP_ICON_GRID_W
    add edx, DESKTOP_ICON_START_X   ; edx = x

    ; Determine icon type from flags
    mov eax, [r13 + FS_DIRENT_FLAGS]
    test eax, FS_ENTRY_DIR
    jz .is_file
    mov ecx, ICON_TYPE_FOLDER       ; Directory
    jmp .have_type
.is_file:
    mov ecx, ICON_TYPE_FILE         ; Regular file
.have_type:

    ; Copy name to our buffer
    mov eax, r12d
    shl eax, 5                      ; * 32 bytes per name
    lea rbx, [desktop_name_bufs + rax]

    push rcx
    push rdx
    push r8
    mov rdi, rbx                    ; dest
    lea rsi, [r13 + FS_DIRENT_NAME] ; src
    mov ecx, 31
.copy_name:
    lodsb
    stosb
    test al, al
    jz .name_done
    dec ecx
    jnz .copy_name
    mov byte [rdi], 0
.name_done:
    pop r8
    pop rdx
    pop rcx

    ; Create icon: dicon_create(x, y, type, text)
    mov esi, edx                    ; x
    mov edx, r8d                    ; y (was in r8d, now in edx for param)
    mov r8d, ecx                    ; icon_type
    mov r9, rbx                     ; text pointer
    call dicon_create

    test rax, rax
    jz .next_entry                  ; Failed to create

    ; Store icon pointer
    mov rbx, rax
    mov [desktop_file_icons + r12*8], rax
    inc byte [desktop_file_icon_count]

    ; Set callback to open file/folder
    mov rdi, rax
    lea rsi, [desktop_cb_file_icon]
    call dicon_set_callback

    ; Store path in userdata for callback
    mov rdi, rbx
    lea rax, [desktop_name_bufs]
    mov ecx, r12d
    shl ecx, 5
    add rax, rcx
    mov [rbx + W_USERDATA], rax

.next_entry:
    add r13, FS_DIRENT_SIZE         ; Next dirent
    inc r12d
    jmp .create_loop

.refresh_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_CB_FILE_ICON - Callback when file icon is double-clicked
; ════════════════════════════════════════════════════════════════════════════
; Input: RDI = icon widget pointer
; ════════════════════════════════════════════════════════════════════════════
desktop_cb_file_icon:
    push rbx
    mov rbx, rdi

    ; Get file/folder name from userdata
    mov rsi, [rbx + W_USERDATA]
    test rsi, rsi
    jz .cb_done

    ; Check if it's a directory (icon_type == FOLDER)
    cmp dword [rbx + DICON_TYPE], ICON_TYPE_FOLDER
    jne .open_file

    ; It's a folder - switch to files mode
    ; TODO: Could set current path in files_app
    mov byte [mode_flag], 4         ; MODE_FILES
    jmp .cb_done

.open_file:
    ; It's a file - switch to files mode to view it
    ; TODO: Open file in viewer
    mov byte [mode_flag], 4         ; MODE_FILES

.cb_done:
    pop rbx
    ret
