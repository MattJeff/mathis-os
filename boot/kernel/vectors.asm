; ============================================================================
; KERNEL VECTORS TABLE - The actual jump table
; ============================================================================
; This table contains pointers to all kernel functions
; Modules call functions via: call [vec_xxx]
; This allows code to grow without breaking offsets
; ============================================================================

%include "vectors.inc"

; ════════════════════════════════════════════════════════════════════════════
; JUMP TABLE DATA
; Must be placed at KERNEL_VECTORS (0x10100) in memory
; ════════════════════════════════════════════════════════════════════════════
align 8
kernel_jump_table:
    ; Drawing functions (0x00 - 0x28)
    dq draw_text              ; vec_draw_text   +0x00
    dq draw_line              ; vec_draw_line   +0x08
    dq draw_rect              ; vec_draw_rect   +0x10
    dq fill_rect              ; vec_fill_rect   +0x18
    dq 0                      ; vec_draw_pixel  +0x20 (TODO)
    dq draw_line_h            ; vec_draw_line_h +0x28

    ; Input functions (0x30 - 0x40)
    dq keyboard_isr64         ; vec_keyboard_isr +0x30
    dq mouse_isr64            ; vec_mouse_isr    +0x38
    dq mouse_init             ; vec_mouse_init   +0x40

    ; Mode functions (0x48 - 0x68)
    dq files_mode             ; vec_files_mode    +0x48
    dq shell_mode             ; vec_shell_mode    +0x50
    dq gui_mode               ; vec_gui_mode      +0x58
    dq gui3d_mode             ; vec_gui3d_mode    +0x60
    dq graphics_mode          ; vec_graphics_mode +0x68

    ; System functions (0x70 - 0x98)
    dq scheduler_init         ; vec_scheduler_init +0x70
    dq heap_init              ; vec_heap_init      +0x78
    dq net_init               ; vec_net_init       +0x80
    dq usb_init               ; vec_usb_init       +0x88
    dq acpi_init              ; vec_acpi_init      +0x90
    dq fat32_init             ; vec_fat32_init     +0x98

    ; UI functions (0xA0 - 0xB8)
    dq draw_mouse_cursor      ; vec_draw_mouse_cursor +0xA0
    dq draw_clock             ; vec_draw_clock        +0xA8
    dq 0                      ; vec_draw_desktop      +0xB0 (TODO)
    dq 0                      ; vec_draw_taskbar      +0xB8 (TODO)

    ; Files mode functions (0xC0 - 0xD0)
    dq files_draw_list        ; vec_files_draw_list   +0xC0
    dq files_draw_entry       ; vec_files_draw_entry  +0xC8
    dq files_draw_viewer      ; vec_files_draw_viewer +0xD0

    ; Padding to 2KB (256 entries)
    times (256 - 27) dq 0
kernel_jump_table_end:
