; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_MANAGER.ASM - Desktop manager (init + draw + input)
; ════════════════════════════════════════════════════════════════════════════
; Supports: static icons, dynamic VFS icons, floating windows
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_SIMPLE_INIT - Initialize desktop + window manager
; ════════════════════════════════════════════════════════════════════════════
desktop_simple_init:
    cmp byte [desktop_initialized], 1
    je .done

    ; Init window manager
    call wm_init

    ; Init VFS (already called elsewhere, but safe to call again)
    call vfs_init

    ; Register for VFS changes (skip if already registered)
    cmp byte [desktop_vfs_registered], 1
    je .skip_register
    mov rdi, desktop_on_vfs_change
    call vfs_register
    mov byte [desktop_vfs_registered], 1
.skip_register:

    mov byte [desktop_initialized], 1
    mov byte [desktop_menu_open], 0

.done:
    ret

desktop_vfs_registered: db 0

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_SIMPLE_DRAW - Draw desktop + windows
; ════════════════════════════════════════════════════════════════════════════
desktop_simple_draw:
    ; 1. Background
    call desktop_draw_bg

    ; 2. Static icons (Terminal, Files)
    call desktop_draw_icons

    ; 3. Dynamic icons from VFS
    call dicon_check_refresh
    call dicon_draw_all

    ; 4. Taskbar
    call desktop_draw_taskbar

    ; 5. Floating windows (on top)
    call wm_draw_all

    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_SIMPLE_INPUT - Handle input (windows first, then desktop)
; ════════════════════════════════════════════════════════════════════════════
desktop_simple_input:
    ; Handle keyboard first (if window is focused)
    ; Use im_key_ready which is set by input_manager_update
    cmp byte [im_key_ready], 0
    je .no_key

    ; Forward key to window manager
    movzx edi, byte [im_key_scancode]
    call wm_on_key
    test eax, eax
    jz .no_key

    ; Key was handled, clear ready flag
    mov byte [im_key_ready], 0

.no_key:
    ; Handle mouse drag if active
    cmp dword [wm_drag_idx], -1
    je .no_drag
    test byte [mouse_buttons], 1
    jz .end_drag
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    call wm_on_drag
    ret
.end_drag:
    call wm_on_release

.no_drag:
    ; Check for click
    test byte [mouse_buttons], 1
    jz .no_click
    cmp byte [desktop_click_lock], 1
    je .no_click
    mov byte [desktop_click_lock], 1

    ; Try windows first
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    call wm_on_click
    test eax, eax
    jnz .done

    ; Try dynamic icons
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    call desktop_handle_dicon_click
    test eax, eax
    jnz .done

    ; Try static icons
    call desktop_handle_click
    jmp .done

.no_click:
    test byte [mouse_buttons], 1
    jnz .done
    mov byte [desktop_click_lock], 0

.done:
    ret

; Click lock to prevent repeated clicks
desktop_click_lock: db 0

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_HANDLE_DICON_CLICK - Handle click on dynamic icon
; Input: EDI = x, ESI = y
; Output: EAX = 1 if handled
; ════════════════════════════════════════════════════════════════════════════
desktop_handle_dicon_click:
    push rbx
    push r12

    call dicon_hit_test
    cmp eax, -1
    je .not_handled

    mov r12d, eax               ; Icon index

    ; Get icon entry
    mov edi, r12d
    call dicon_get_entry
    test rax, rax
    jz .not_handled
    mov rbx, rax

    ; Check if folder
    cmp dword [rbx + DICON_ENT_TYPE], 1
    jne .open_file

    ; Open folder in Files window
    mov rdi, [rbx + DICON_ENT_NAME]
    call desktop_open_folder
    jmp .handled

.open_file:
    ; TODO: Open file
    jmp .handled

.handled:
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_OPEN_FOLDER - Open folder in Files window
; Input: RDI = folder name
; ════════════════════════════════════════════════════════════════════════════
desktop_open_folder:
    push rbx
    push r12

    mov r12, rdi                ; Save folder name

    ; Create Files window
    mov edi, WM_TYPE_FILES
    mov esi, 100                ; x
    mov edx, 50                 ; y
    mov ecx, WM_DEF_W           ; w
    mov r8d, WM_DEF_H           ; h
    lea r9, [desktop_str_files]
    call wm_create_window

    cmp eax, -1
    je .done

    mov ebx, eax                ; Window index

    ; Navigate VFS to folder
    mov rdi, r12
    call vfs_goto

    ; TODO: Create files widget and attach to window

.done:
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_OPEN_FILES - Open Files app window (from icon click)
; ════════════════════════════════════════════════════════════════════════════
desktop_open_files:
    push rbx

    ; Create Files window centered on screen
    mov edi, WM_TYPE_FILES
    ; x = (screen_width - WM_DEF_W) / 2
    mov esi, [screen_width]
    sub esi, WM_DEF_W
    shr esi, 1
    ; y = (screen_height - WM_DEF_H) / 2
    mov edx, [screen_height]
    sub edx, WM_DEF_H
    shr edx, 1
    mov ecx, WM_DEF_W
    mov r8d, WM_DEF_H
    lea r9, [desktop_str_files]
    call wm_create_window

    ; DEBUG: Skip vfs_goto_loc
    ; cmp eax, -1
    ; je .done
    ; mov edi, VFS_LOC_ROOT
    ; call vfs_goto_loc

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_ON_VFS_CHANGE - Called when VFS changes
; ════════════════════════════════════════════════════════════════════════════
desktop_on_vfs_change:
    ; Refresh dynamic icons
    call dicon_refresh
    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_HANDLE_KEY - Handle keyboard in desktop mode
; Input: EDI = scancode
; ════════════════════════════════════════════════════════════════════════════
desktop_handle_key:
    ; Forward to window manager
    call wm_on_key
    ret
