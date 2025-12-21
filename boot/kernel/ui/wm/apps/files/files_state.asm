; ============================================================================
; FILES_STATE.ASM - State variables
; ============================================================================
; Single Responsibility: Store all Files app state
; ============================================================================

[BITS 64]

; Selection state
wmf_scroll_pos:     dd 0
wmf_selected:       dd 0
wmf_entry_count:    dd 0

; UI state
wmf_sidebar_hover:  dd -1
wmf_btn_hover:      dd 0

; Window geometry (set by draw)
wmf_win_x:          dd 0
wmf_win_y:          dd 0
wmf_win_w:          dd 0
wmf_win_h:          dd 0

; History stack
wmf_history:        times WMF_HISTORY_MAX dd 0
wmf_history_pos:    dd 0
wmf_history_len:    dd 0

; Temp storage
wmf_vfs_ptr:        dq 0
wmf_loop_idx:       dd 0
wmf_cur_y:          dd 0
wmf_temp_loc:       dd 0

; Icon grid layout
wmf_cols:           dd 0
wmf_icon_x:         dd 0
wmf_icon_y:         dd 0

; Path buffer for new folder
wmf_new_path:       times 128 db 0

; Dialog state
wmf_dialog_mode:    dd 0            ; 0=none, 1=new, 2=delete, 3=rename
wmf_dialog_select:  dd 0            ; 0=folder, 1=file
wmf_dialog_input:   times 32 db 0   ; Input buffer for filename
wmf_dialog_cursor:  dd 0            ; Cursor position in input
