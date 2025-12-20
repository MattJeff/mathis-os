; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_MANAGER.ASM - Desktop manager (coordinator)
; ════════════════════════════════════════════════════════════════════════════
; Single Responsibility: Coordinate desktop modules (init + draw)
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

    ; Init VFS
    call vfs_init

    ; Register for VFS changes
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

    ; 6. Desktop dialog (if open)
    call desktop_dlg_draw

    ret

; ════════════════════════════════════════════════════════════════════════════
; Include modular components
; ════════════════════════════════════════════════════════════════════════════
%include "modes/desktop/parts/desktop_input.asm"
%include "modes/desktop/parts/desktop_open.asm"
%include "modes/desktop/parts/desktop_dlg_state.asm"
%include "modes/desktop/parts/desktop_dlg_key.asm"
%include "modes/desktop/parts/desktop_dlg_confirm.asm"
%include "modes/desktop/parts/desktop_dlg_draw.asm"

