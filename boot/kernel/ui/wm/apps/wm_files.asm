; ============================================================================
; WM_FILES.ASM - Files app for window manager
; ============================================================================
; Finder-style file browser with sidebar, toolbar, and file list
;
; Architecture: SOLID modular design (<100 lines each)
;   - files_const.asm         : Layout constants and colors
;   - files_state.asm         : State variables
;   - files_history.asm       : Back/forward navigation
;   - files_actions.asm       : File operations (create/delete)
;   - files_draw_sidebar.asm  : Sidebar rendering
;   - files_draw_toolbar.asm  : Toolbar rendering
;   - files_draw_list.asm     : File list rendering
;   - files_draw.asm          : Main draw orchestration
;   - files_input_sidebar.asm : Sidebar click handler
;   - files_input_toolbar.asm : Toolbar click handler
;   - files_input_content.asm : Content area clicks
;   - files_input_key.asm     : Keyboard handling
;   - files_input.asm         : Input dispatcher
; ============================================================================

[BITS 64]

; Include modules in dependency order
%include "ui/wm/apps/files/files_const.asm"
%include "ui/wm/apps/files/files_state.asm"
%include "ui/wm/apps/files/files_dialog.asm"
%include "ui/wm/apps/files/files_dialog_new.asm"
%include "ui/wm/apps/files/files_dialog_delete.asm"
%include "ui/wm/apps/files/files_dialog_rename.asm"
%include "ui/wm/apps/files/files_dialog_key.asm"
%include "ui/wm/apps/files/files_dialog_draw.asm"
%include "ui/wm/apps/files/files_dialog_draw_parts.asm"
%include "ui/wm/apps/files/files_history.asm"
%include "ui/wm/apps/files/files_actions.asm"
%include "ui/wm/apps/files/files_draw_sidebar.asm"
%include "ui/wm/apps/files/files_draw_toolbar.asm"
%include "ui/wm/apps/files/files_draw_list.asm"
%include "ui/wm/apps/files/files_draw.asm"
%include "ui/wm/apps/files/files_input_sidebar.asm"
%include "ui/wm/apps/files/files_input_toolbar.asm"
%include "ui/wm/apps/files/files_input_content.asm"
%include "ui/wm/apps/files/files_open.asm"
%include "ui/wm/apps/files/files_input_key.asm"
%include "ui/wm/apps/files/files_input.asm"
