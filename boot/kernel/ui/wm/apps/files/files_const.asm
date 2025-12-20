; ============================================================================
; FILES_CONST.ASM - Layout constants and colors
; ============================================================================
; Single Responsibility: Define all Files app constants
; ============================================================================

[BITS 64]

; Layout
WMF_SIDEBAR_W       equ 120
WMF_TOOLBAR_H       equ 32
WMF_ROW_H           equ 22
WMF_PADDING         equ 6
WMF_MAX_VISIBLE     equ 20

; Colors
WMF_COL_SIDEBAR     equ 0x002D2D3A
WMF_COL_TOOLBAR     equ 0x003A3A4A
WMF_COL_CONTENT     equ 0x00252530
WMF_COL_SEL         equ 0x00404060
WMF_COL_HOVER       equ 0x00505070
WMF_COL_BTN         equ 0x00505060
WMF_COL_BTN_HOV     equ 0x00606080
WMF_COL_TEXT        equ 0x00FFFFFF
WMF_COL_TEXT_DIM    equ 0x00888888
WMF_COL_FOLDER      equ 0x0066AAFF
WMF_COL_FILE        equ 0x00AAAAAA

; History
WMF_HISTORY_MAX     equ 16
