; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_DATA.ASM - Sidebar constants and state
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR DIMENSIONS
; ════════════════════════════════════════════════════════════════════════════
SIDEBAR_WIDTH       equ 150
SIDEBAR_ITEM_H      equ 24
SIDEBAR_ICON_SIZE   equ 12

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR COLORS
; ════════════════════════════════════════════════════════════════════════════
SIDEBAR_BG          equ 0x002D2D2D
SIDEBAR_HOVER       equ 0x003D3D3D
SIDEBAR_SELECTED    equ 0x00007AFF
SIDEBAR_TEXT        equ 0x00FFFFFF
SIDEBAR_TEXT_DIM    equ 0x00888888
SIDEBAR_BORDER      equ 0x00404040

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR STATE
; ════════════════════════════════════════════════════════════════════════════
sidebar_x:          dd 0
sidebar_y:          dd 0
sidebar_w:          dd SIDEBAR_WIDTH
sidebar_h:          dd 0
sidebar_selected:   dd 1            ; Default: Root (index 1)
sidebar_hover:      dd -1
sidebar_visible:    db 1

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR ITEMS (using VFS locations)
; ════════════════════════════════════════════════════════════════════════════
SB_ITEM_HEADER      equ 0
SB_ITEM_LOCATION    equ 1

; Item structure: type (1), vfs_loc (1), name ptr (8) = 10 bytes, pad to 16
SB_ITEM_SIZE        equ 16
SB_ITEM_TYPE        equ 0
SB_ITEM_LOC         equ 1
SB_ITEM_NAME        equ 8

sidebar_item_count: dd 5

; Item 0: FAVORITES header
sb_item_0:
    db SB_ITEM_HEADER       ; type
    db 0                    ; loc (unused)
    times 6 db 0            ; padding
    dq sb_str_favorites     ; name ptr

; Item 1: Root
sb_item_1:
    db SB_ITEM_LOCATION
    db VFS_LOC_ROOT
    times 6 db 0
    dq sb_str_root

; Item 2: Desktop
sb_item_2:
    db SB_ITEM_LOCATION
    db VFS_LOC_DESKTOP
    times 6 db 0
    dq sb_str_desktop

; Item 3: Downloads
sb_item_3:
    db SB_ITEM_LOCATION
    db VFS_LOC_DOWNLOADS
    times 6 db 0
    dq sb_str_downloads

; Item 4: Documents
sb_item_4:
    db SB_ITEM_LOCATION
    db VFS_LOC_DOCUMENTS
    times 6 db 0
    dq sb_str_documents

; Strings
sb_str_favorites:   db "FAVORITES", 0
sb_str_root:        db "Root", 0
sb_str_desktop:     db "Desktop", 0
sb_str_downloads:   db "Downloads", 0
sb_str_documents:   db "Documents", 0

; Callback
sidebar_on_select:  dq 0
