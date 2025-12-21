; ============================================================================
; FILES_CONST.ASM - Layout constants and colors
; ============================================================================
; Single Responsibility: Define all Files app constants
; ============================================================================

[BITS 64]

; Layout
WMF_SIDEBAR_W       equ 180               ; Wider sidebar like Finder
WMF_TOOLBAR_H       equ 40                ; Taller toolbar
WMF_ROW_H           equ 24
WMF_PADDING         equ 8
WMF_MAX_VISIBLE     equ 20

; Icon grid layout
WMF_ICON_SIZE       equ 64                ; Large folder icons
WMF_ICON_SPACING    equ 100               ; Grid spacing
WMF_ICON_LABEL_H    equ 32                ; Space for label

; Colors - Finder dark theme
WMF_COL_SIDEBAR     equ 0x00212125        ; Dark sidebar (#212125)
WMF_COL_TOOLBAR     equ 0x00323236        ; Toolbar (#323236)
WMF_COL_CONTENT     equ 0x001E1E22        ; Content area (#1E1E22)
WMF_COL_SEL         equ 0x00404050        ; Selection
WMF_COL_SEL_BLUE    equ 0x002D5A8A        ; Blue selection
WMF_COL_HOVER       equ 0x00353540
WMF_COL_BTN         equ 0x00454550
WMF_COL_BTN_HOV     equ 0x00555565
WMF_COL_TEXT        equ 0x00FFFFFF        ; White text
WMF_COL_TEXT_DIM    equ 0x00888898        ; Gray text
WMF_COL_TEXT_HEADER equ 0x00999999        ; Section headers
WMF_COL_FOLDER      equ 0x004FC3F7        ; Finder blue folder
WMF_COL_FILE        equ 0x00CCCCCC        ; Light gray file
WMF_COL_DIVIDER     equ 0x00404045        ; Subtle dividers

; History
WMF_HISTORY_MAX     equ 16
