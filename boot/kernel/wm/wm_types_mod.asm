; ============================================================================
; WM_TYPES_MOD.ASM - Window Manager Types and Constants
; ============================================================================
; Window structure definitions and constants
; ============================================================================

[BITS 64]

; ============================================================================
; WINDOW MANAGER LIMITS
; ============================================================================
WM_MAX_WINDOWS          equ 8

; ============================================================================
; WINDOW STRUCTURE OFFSETS
; ============================================================================
WIN_FLAGS               equ 0       ; Window flags
WIN_TYPE                equ 4       ; Window type (app)
WIN_X                   equ 8       ; X position
WIN_Y                   equ 12      ; Y position
WIN_W                   equ 16      ; Width
WIN_H                   equ 20      ; Height
WIN_TITLE               equ 24      ; Title string pointer
WIN_DRAW_CB             equ 32      ; Draw callback
WIN_INPUT_CB            equ 40      ; Input callback
WIN_DATA                equ 48      ; User data
WIN_STRUCT_SIZE         equ 56

; ============================================================================
; WINDOW FLAGS
; ============================================================================
WIN_FLAG_VISIBLE        equ 0x01
WIN_FLAG_ACTIVE         equ 0x02
WIN_FLAG_DRAGGING       equ 0x04
WIN_FLAG_RESIZING       equ 0x08
WIN_FLAG_MINIMIZED      equ 0x10
WIN_FLAG_MAXIMIZED      equ 0x20

; ============================================================================
; WINDOW TYPES
; ============================================================================
WIN_TYPE_NONE           equ 0
WIN_TYPE_CALC           equ 1
WIN_TYPE_CLOCK          equ 2
WIN_TYPE_EDITOR         equ 3
WIN_TYPE_FILES          equ 4
WIN_TYPE_TERMINAL       equ 5

; ============================================================================
; WINDOW CHROME SIZES
; ============================================================================
WIN_TITLE_HEIGHT        equ 24
WIN_BORDER_SIZE         equ 1
WIN_BUTTON_SIZE         equ 16
WIN_BUTTON_MARGIN       equ 4

; ============================================================================
; WINDOW COLORS
; ============================================================================
WIN_COLOR_TITLE_BG      equ 0x00404040
WIN_COLOR_TITLE_ACTIVE  equ 0x000066CC
WIN_COLOR_TITLE_TEXT    equ 0x00FFFFFF
WIN_COLOR_BG            equ 0x00F0F0F0
WIN_COLOR_BORDER        equ 0x00808080
WIN_COLOR_CLOSE         equ 0x00E04040
WIN_COLOR_MIN           equ 0x00E0A040
WIN_COLOR_MAX           equ 0x0040C040
