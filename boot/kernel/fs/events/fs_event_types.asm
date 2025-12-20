; ════════════════════════════════════════════════════════════════════════════
; FS_EVENT_TYPES.ASM - Filesystem event constants and structures
; ════════════════════════════════════════════════════════════════════════════
; Event-driven filesystem notifications for sync between desktop/files mode
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; EVENT TYPES
; ════════════════════════════════════════════════════════════════════════════
FS_EVT_NONE         equ 0           ; No event
FS_EVT_CREATE       equ 1           ; File/folder created
FS_EVT_DELETE       equ 2           ; File/folder deleted
FS_EVT_RENAME       equ 3           ; File/folder renamed
FS_EVT_MODIFY       equ 4           ; File content modified
FS_EVT_MOVE         equ 5           ; File/folder moved
FS_EVT_REFRESH      equ 6           ; Force refresh (mount/unmount)

; ════════════════════════════════════════════════════════════════════════════
; EVENT FLAGS
; ════════════════════════════════════════════════════════════════════════════
FS_EVT_FLAG_DIR     equ 0x01        ; Event is for directory
FS_EVT_FLAG_FILE    equ 0x02        ; Event is for file
FS_EVT_FLAG_DESKTOP equ 0x10        ; Event from desktop mode
FS_EVT_FLAG_FILES   equ 0x20        ; Event from files mode

; ════════════════════════════════════════════════════════════════════════════
; EVENT STRUCTURE (64 bytes)
; ════════════════════════════════════════════════════════════════════════════
; Offset | Size | Field
; ───────┼──────┼─────────────────────
;   0    |  1   | event_type
;   1    |  1   | flags
;   2    |  2   | reserved
;   4    |  4   | timestamp
;   8    | 32   | path (null-terminated)
;  40    | 24   | extra (new_name for rename, etc)
; ════════════════════════════════════════════════════════════════════════════

FS_EVT_SIZE         equ 64
FS_EVT_TYPE         equ 0
FS_EVT_FLAGS        equ 1
FS_EVT_TIMESTAMP    equ 4
FS_EVT_PATH         equ 8
FS_EVT_PATH_LEN     equ 32
FS_EVT_EXTRA        equ 40
FS_EVT_EXTRA_LEN    equ 24

; ════════════════════════════════════════════════════════════════════════════
; QUEUE CONSTANTS
; ════════════════════════════════════════════════════════════════════════════
FS_EVT_QUEUE_SIZE   equ 16          ; Max events in queue
