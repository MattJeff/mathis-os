; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_SIMPLE.ASM - Desktop with window manager
; ════════════════════════════════════════════════════════════════════════════
; Modular structure:
;   - desktop_data.asm      : Constants and state
;   - desktop_bg.asm        : Background drawing
;   - desktop_taskbar.asm   : Taskbar drawing
;   - desktop_icons.asm     : Static icon drawing
;   - desktop_icons_dyn.asm : Dynamic icons from VFS
;   - desktop_click.asm     : Click handling
;   - desktop_manager.asm   : Main init/draw/input + window manager
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; Include all parts
%include "modes/desktop/parts/desktop_data.asm"
%include "modes/desktop/parts/desktop_bg.asm"
%include "modes/desktop/parts/desktop_taskbar.asm"
%include "modes/desktop/parts/desktop_icons.asm"
%include "modes/desktop/parts/desktop_icons_dyn.asm"
%include "modes/desktop/parts/desktop_click.asm"
%include "modes/desktop/parts/desktop_manager.asm"
