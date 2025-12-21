; ============================================================================
; COLORS_MOD.ASM - Color Palette Constants
; ============================================================================
; Standard UI colors in ARGB format
; ============================================================================

[BITS 64]

; ============================================================================
; SYSTEM COLORS
; ============================================================================
COLOR_BLACK             equ 0x00000000
COLOR_WHITE             equ 0x00FFFFFF
COLOR_RED               equ 0x00FF0000
COLOR_GREEN             equ 0x0000FF00
COLOR_BLUE              equ 0x000000FF
COLOR_YELLOW            equ 0x00FFFF00
COLOR_CYAN              equ 0x0000FFFF
COLOR_MAGENTA           equ 0x00FF00FF

; ============================================================================
; GRAY SCALE
; ============================================================================
COLOR_GRAY_DARK         equ 0x00333333
COLOR_GRAY              equ 0x00808080
COLOR_GRAY_LIGHT        equ 0x00C0C0C0
COLOR_GRAY_LIGHTER      equ 0x00E0E0E0

; ============================================================================
; DESKTOP COLORS
; ============================================================================
COLOR_DESKTOP_BG        equ 0x003366AA  ; Blue background
COLOR_TASKBAR_BG        equ 0x002D2D2D  ; Dark gray
COLOR_TASKBAR_HOVER     equ 0x00404040  ; Lighter gray

; ============================================================================
; WINDOW COLORS
; ============================================================================
COLOR_WINDOW_BG         equ 0x00F0F0F0  ; Light gray
COLOR_WINDOW_TITLE      equ 0x00404040  ; Dark title bar
COLOR_WINDOW_TITLE_ACT  equ 0x000066CC  ; Active title bar
COLOR_WINDOW_BORDER     equ 0x00808080  ; Border

; ============================================================================
; BUTTON COLORS
; ============================================================================
COLOR_BUTTON_BG         equ 0x00E0E0E0
COLOR_BUTTON_HOVER      equ 0x00D0D0D0
COLOR_BUTTON_PRESSED    equ 0x00A0A0A0
COLOR_BUTTON_BORDER     equ 0x00808080
COLOR_BUTTON_TEXT       equ 0x00000000

; ============================================================================
; TEXT COLORS
; ============================================================================
COLOR_TEXT_DEFAULT      equ 0x00000000
COLOR_TEXT_DISABLED     equ 0x00808080
COLOR_TEXT_HIGHLIGHT    equ 0x00FFFFFF
COLOR_TEXT_LINK         equ 0x000066CC

; ============================================================================
; SELECTION COLORS
; ============================================================================
COLOR_SELECT_BG         equ 0x000066CC
COLOR_SELECT_TEXT       equ 0x00FFFFFF

; ============================================================================
; ICON COLORS
; ============================================================================
COLOR_ICON_FOLDER       equ 0x00DAA520  ; Goldenrod
COLOR_ICON_FILE         equ 0x00808080  ; Gray
COLOR_ICON_TERMINAL     equ 0x00333333  ; Dark gray
COLOR_ICON_CALC         equ 0x00336699  ; Blue-gray
