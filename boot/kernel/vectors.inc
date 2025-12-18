; ============================================================================
; KERNEL VECTORS - Jump table addresses
; ============================================================================
; Central jump table for all kernel functions
; This allows modules to grow without breaking call offsets
; ============================================================================

KERNEL_VECTORS  equ 0x10100     ; After entry point (256 bytes margin)

; ════════════════════════════════════════════════════════════════════════════
; DRAWING FUNCTIONS
; ════════════════════════════════════════════════════════════════════════════
vec_draw_text   equ KERNEL_VECTORS + 0x00
vec_draw_line   equ KERNEL_VECTORS + 0x08
vec_draw_rect   equ KERNEL_VECTORS + 0x10
vec_fill_rect   equ KERNEL_VECTORS + 0x18
vec_draw_pixel  equ KERNEL_VECTORS + 0x20
vec_draw_line_h equ KERNEL_VECTORS + 0x28

; ════════════════════════════════════════════════════════════════════════════
; INPUT FUNCTIONS
; ════════════════════════════════════════════════════════════════════════════
vec_keyboard_isr equ KERNEL_VECTORS + 0x30
vec_mouse_isr    equ KERNEL_VECTORS + 0x38
vec_mouse_init   equ KERNEL_VECTORS + 0x40

; ════════════════════════════════════════════════════════════════════════════
; MODE FUNCTIONS
; ════════════════════════════════════════════════════════════════════════════
vec_files_mode   equ KERNEL_VECTORS + 0x48
vec_shell_mode   equ KERNEL_VECTORS + 0x50
vec_gui_mode     equ KERNEL_VECTORS + 0x58
vec_gui3d_mode   equ KERNEL_VECTORS + 0x60
vec_graphics_mode equ KERNEL_VECTORS + 0x68

; ════════════════════════════════════════════════════════════════════════════
; SYSTEM FUNCTIONS
; ════════════════════════════════════════════════════════════════════════════
vec_scheduler_init equ KERNEL_VECTORS + 0x70
vec_heap_init      equ KERNEL_VECTORS + 0x78
vec_net_init       equ KERNEL_VECTORS + 0x80
vec_usb_init       equ KERNEL_VECTORS + 0x88
vec_acpi_init      equ KERNEL_VECTORS + 0x90
vec_fat32_init     equ KERNEL_VECTORS + 0x98

; ════════════════════════════════════════════════════════════════════════════
; UI FUNCTIONS
; ════════════════════════════════════════════════════════════════════════════
vec_draw_mouse_cursor equ KERNEL_VECTORS + 0xA0
vec_draw_clock        equ KERNEL_VECTORS + 0xA8
vec_draw_desktop      equ KERNEL_VECTORS + 0xB0
vec_draw_taskbar      equ KERNEL_VECTORS + 0xB8

; ════════════════════════════════════════════════════════════════════════════
; FILES MODE FUNCTIONS
; ════════════════════════════════════════════════════════════════════════════
vec_files_draw_list   equ KERNEL_VECTORS + 0xC0
vec_files_draw_entry  equ KERNEL_VECTORS + 0xC8
vec_files_draw_viewer equ KERNEL_VECTORS + 0xD0

; ════════════════════════════════════════════════════════════════════════════
; RESERVED FOR FUTURE (up to 256 entries = 2KB)
; ════════════════════════════════════════════════════════════════════════════
; vec_xxx equ KERNEL_VECTORS + 0xD8
; ...
; Max: KERNEL_VECTORS + 0x7F8 (entry 255)

KERNEL_VECTORS_END equ KERNEL_VECTORS + 0x800   ; 2KB table
