; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_DATA.ASM - Sidebar constants and data structures
; ════════════════════════════════════════════════════════════════════════════
; Finder-style sidebar with locations (Desktop, Root, Downloads, etc.)
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR DIMENSIONS
; ════════════════════════════════════════════════════════════════════════════
SIDEBAR_WIDTH       equ 150         ; Width in pixels
SIDEBAR_ITEM_H      equ 24          ; Height per item
SIDEBAR_PADDING     equ 8           ; Padding
SIDEBAR_ICON_SIZE   equ 16          ; Icon size

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR COLORS
; ════════════════════════════════════════════════════════════════════════════
SIDEBAR_BG          equ 0x002D2D2D  ; Dark gray background
SIDEBAR_HOVER       equ 0x003D3D3D  ; Hover highlight
SIDEBAR_SELECTED    equ 0x00007AFF  ; Blue selection
SIDEBAR_TEXT        equ 0x00FFFFFF  ; White text
SIDEBAR_TEXT_DIM    equ 0x00888888  ; Gray text for headers
SIDEBAR_BORDER      equ 0x00404040  ; Border color

; ════════════════════════════════════════════════════════════════════════════
; LOCATION TYPES
; ════════════════════════════════════════════════════════════════════════════
SB_LOC_HEADER       equ 0           ; Section header (not clickable)
SB_LOC_DESKTOP      equ 1           ; Desktop folder
SB_LOC_ROOT         equ 2           ; Root directory
SB_LOC_DOWNLOADS    equ 3           ; Downloads folder
SB_LOC_DOCUMENTS    equ 4           ; Documents folder
SB_LOC_CUSTOM       equ 5           ; User-added location

; ════════════════════════════════════════════════════════════════════════════
; LOCATION ENTRY (32 bytes)
; ════════════════════════════════════════════════════════════════════════════
SB_LOC_SIZE         equ 32
SB_LOC_TYPE_OFF     equ 0           ; 1 byte: location type
SB_LOC_FLAGS_OFF    equ 1           ; 1 byte: flags
SB_LOC_NAME_OFF     equ 2           ; 14 bytes: display name
SB_LOC_PATH_OFF     equ 16          ; 16 bytes: path

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR STATE
; ════════════════════════════════════════════════════════════════════════════
sidebar_x:          dd 0            ; X position
sidebar_y:          dd 0            ; Y position
sidebar_w:          dd SIDEBAR_WIDTH
sidebar_h:          dd 0            ; Height (set dynamically)
sidebar_selected:   dd 1            ; Selected index (0 = none)
sidebar_hover:      dd -1           ; Hover index (-1 = none)
sidebar_visible:    db 1            ; Visibility flag

; ════════════════════════════════════════════════════════════════════════════
; DEFAULT LOCATIONS
; ════════════════════════════════════════════════════════════════════════════
SB_MAX_LOCATIONS    equ 8

; Location 0: FAVORITES header
sb_loc_0_type:      db SB_LOC_HEADER
sb_loc_0_flags:     db 0
sb_loc_0_name:      db "FAVORITES", 0, 0, 0, 0, 0
sb_loc_0_path:      times 16 db 0

; Location 1: Desktop
sb_loc_1_type:      db SB_LOC_DESKTOP
sb_loc_1_flags:     db 0
sb_loc_1_name:      db "Desktop", 0, 0, 0, 0, 0, 0, 0
sb_loc_1_path:      db "/desktop", 0, 0, 0, 0, 0, 0, 0

; Location 2: Root
sb_loc_2_type:      db SB_LOC_ROOT
sb_loc_2_flags:     db 0
sb_loc_2_name:      db "Root", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
sb_loc_2_path:      db "/", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

; Location 3: Downloads
sb_loc_3_type:      db SB_LOC_DOWNLOADS
sb_loc_3_flags:     db 0
sb_loc_3_name:      db "Downloads", 0, 0, 0, 0, 0
sb_loc_3_path:      db "/downloads", 0, 0, 0, 0, 0

; Location 4: Documents
sb_loc_4_type:      db SB_LOC_DOCUMENTS
sb_loc_4_flags:     db 0
sb_loc_4_name:      db "Documents", 0, 0, 0, 0, 0
sb_loc_4_path:      db "/documents", 0, 0, 0, 0, 0

sidebar_loc_count:  dd 5            ; Current location count

; Callback for location change
sidebar_on_select:  dq 0            ; Callback(rdi = location index, rsi = path ptr)
