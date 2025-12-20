; ════════════════════════════════════════════════════════════════════════════
; VFS_STATE.ASM - Virtual Filesystem shared state
; ════════════════════════════════════════════════════════════════════════════
; Single source of truth for current directory and entries
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; CURRENT STATE
; ════════════════════════════════════════════════════════════════════════════
vfs_current_path:   times VFS_MAX_PATH db 0
vfs_current_loc:    dd VFS_LOC_ROOT     ; Current location type
vfs_entry_count:    dd 0                ; Number of entries loaded
vfs_dirty:          db 1                ; Needs reload flag
vfs_initialized:    db 0                ; Init flag

; ════════════════════════════════════════════════════════════════════════════
; ENTRY CACHE (shared between desktop and files mode)
; ════════════════════════════════════════════════════════════════════════════
vfs_entries:        times (VFS_ENTRY_SIZE * VFS_MAX_ENTRIES) db 0

; ════════════════════════════════════════════════════════════════════════════
; TEMP BUFFER for fs_readdir (FS_DIRENT_SIZE = 64)
; ════════════════════════════════════════════════════════════════════════════
vfs_dirent_buf:     times (64 * VFS_MAX_ENTRIES) db 0

; ════════════════════════════════════════════════════════════════════════════
; PREDEFINED PATHS
; ════════════════════════════════════════════════════════════════════════════
vfs_path_root:      db "/", 0
vfs_path_desktop:   db "/desktop", 0
vfs_path_downloads: db "/download", 0
vfs_path_documents: db "/docs", 0

; ════════════════════════════════════════════════════════════════════════════
; LOCATION NAMES (for display)
; ════════════════════════════════════════════════════════════════════════════
vfs_name_root:      db "Root", 0
vfs_name_desktop:   db "Desktop", 0
vfs_name_downloads: db "Downloads", 0
vfs_name_documents: db "Documents", 0
