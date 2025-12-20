; ════════════════════════════════════════════════════════════════════════════
; FILES_APP.ASM - Files Application (SOLID Architecture)
; ════════════════════════════════════════════════════════════════════════════
; Modular structure for maintainability:
;   - parts/files_state.asm   : Constants and state variables
;   - parts/files_init.asm    : Initialization
;   - parts/files_loader.asm  : Directory loading from filesystem
;   - parts/files_render.asm  : Drawing functions
;   - parts/files_input.asm   : Keyboard handling
;   - parts/files_editor.asm  : Editor functions
;   - parts/files_path.asm    : Path building for current directory
;   - parts/files_dialogs.asm : Dialog callbacks
;   - parts/files_crud.asm    : Save/refresh operations
;   - parts/files_cleanup.asm : Cleanup functions
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; Include all parts
%include "modes/files/parts/files_state.asm"
%include "modes/files/parts/files_loader.asm"
%include "modes/files/parts/files_init.asm"
%include "modes/files/parts/files_render.asm"
%include "modes/files/parts/files_editor.asm"
%include "modes/files/parts/files_path.asm"
%include "modes/files/parts/files_dialogs.asm"
%include "modes/files/parts/files_crud.asm"
%include "modes/files/parts/files_input.asm"
%include "modes/files/parts/files_cleanup.asm"
