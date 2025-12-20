; ════════════════════════════════════════════════════════════════════════════
; VFS.ASM - Virtual Filesystem (main include)
; ════════════════════════════════════════════════════════════════════════════
; Shared filesystem layer between desktop and files mode
;
; Usage:
;   1. vfs_init() - Initialize VFS
;   2. vfs_goto("/desktop") or vfs_goto_loc(VFS_LOC_DESKTOP)
;   3. vfs_get_entries() - Get current directory entries
;   4. vfs_register(callback) - Listen for changes
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

%include "fs/vfs/vfs_types.asm"
%include "fs/vfs/vfs_state.asm"
%include "fs/vfs/vfs_notify.asm"
%include "fs/vfs/vfs_navigate.asm"
%include "fs/vfs/vfs_list.asm"

; ════════════════════════════════════════════════════════════════════════════
; VFS_INIT - Initialize VFS with root directory
; ════════════════════════════════════════════════════════════════════════════
vfs_init:
    cmp byte [vfs_initialized], 1
    je .done

    ; Set initial path to root
    lea rdi, [vfs_current_path]
    mov byte [rdi], '/'
    mov byte [rdi+1], 0

    mov dword [vfs_current_loc], VFS_LOC_ROOT
    mov byte [vfs_dirty], 1
    mov byte [vfs_initialized], 1

    ; Load initial directory
    call vfs_reload

.done:
    ret
