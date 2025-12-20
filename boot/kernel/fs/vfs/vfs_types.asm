; ════════════════════════════════════════════════════════════════════════════
; VFS_TYPES.ASM - Virtual Filesystem constants and structures
; ════════════════════════════════════════════════════════════════════════════
; Shared filesystem layer for desktop and files mode sync
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; VFS ENTRY FLAGS
; ════════════════════════════════════════════════════════════════════════════
VFS_FLAG_DIR        equ 0x01        ; Is directory
VFS_FLAG_FILE       equ 0x02        ; Is file
VFS_FLAG_HIDDEN     equ 0x04        ; Hidden entry
VFS_FLAG_SYSTEM     equ 0x08        ; System entry

; ════════════════════════════════════════════════════════════════════════════
; VFS ENTRY STRUCTURE (48 bytes)
; ════════════════════════════════════════════════════════════════════════════
VFS_ENTRY_SIZE      equ 48
VFS_E_NAME          equ 0           ; 32 bytes: filename
VFS_E_SIZE          equ 32          ; 4 bytes: file size
VFS_E_FLAGS         equ 36          ; 4 bytes: flags
VFS_E_CLUSTER       equ 40          ; 4 bytes: start cluster (FAT32)
VFS_E_RESERVED      equ 44          ; 4 bytes: reserved

; ════════════════════════════════════════════════════════════════════════════
; VFS LIMITS
; ════════════════════════════════════════════════════════════════════════════
VFS_MAX_ENTRIES     equ 64          ; Max entries per directory
VFS_MAX_PATH        equ 128         ; Max path length
VFS_MAX_NAME        equ 32          ; Max filename length

; ════════════════════════════════════════════════════════════════════════════
; VFS LOCATIONS (predefined paths)
; ════════════════════════════════════════════════════════════════════════════
VFS_LOC_ROOT        equ 0           ; "/"
VFS_LOC_DESKTOP     equ 1           ; "/desktop"
VFS_LOC_DOWNLOADS   equ 2           ; "/downloads"
VFS_LOC_DOCUMENTS   equ 3           ; "/documents"
