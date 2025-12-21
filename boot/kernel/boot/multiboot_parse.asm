; ============================================================================
; MULTIBOOT PARSE - Parse multiboot_info structure from GRUB
; ============================================================================
; Called from kernel_entry when EAX = MULTIBOOT_BOOTLOADER_MAGIC.
; EBX contains pointer to multiboot_info structure.
;
; Writes video info to 0x500-0x514 (same format as stage2).
; ============================================================================

; ============================================================================
; MULTIBOOT INFO STRUCTURE OFFSETS
; ============================================================================

MB_INFO_FLAGS               equ 0
MB_INFO_MEM_LOWER           equ 4
MB_INFO_MEM_UPPER           equ 8
MB_INFO_FRAMEBUFFER_ADDR    equ 88
MB_INFO_FRAMEBUFFER_PITCH   equ 96
MB_INFO_FRAMEBUFFER_WIDTH   equ 100
MB_INFO_FRAMEBUFFER_HEIGHT  equ 104
MB_INFO_FRAMEBUFFER_BPP     equ 108

; Multiboot flags bits
MB_FLAG_MEMORY              equ (1 << 0)
MB_FLAG_FRAMEBUFFER         equ (1 << 12)

; Video info memory locations (shared with stage2)
VIDEO_INFO_FB               equ 0x500
VIDEO_INFO_W                equ 0x504
VIDEO_INFO_H                equ 0x508
VIDEO_INFO_VESA             equ 0x50C
VIDEO_INFO_PITCH            equ 0x510
VIDEO_INFO_BPP              equ 0x514

; VGA fallback constants
VGA_FRAMEBUFFER             equ 0xA0000
VGA_WIDTH                   equ 320
VGA_HEIGHT                  equ 200
VGA_PITCH                   equ 320
VGA_BPP                     equ 8

; ============================================================================
; MULTIBOOT_PARSE_INFO
; ============================================================================
; Input:  EBX = pointer to multiboot_info structure
; Output: Video info written to 0x500-0x514
; ============================================================================

multiboot_parse_info:
    push ebx
    push esi

    ; Save multiboot info pointer
    mov [multiboot_info_ptr], ebx
    mov byte [boot_mode], 1         ; 1 = multiboot

    ; Check if framebuffer info is available (flag bit 12)
    mov eax, [ebx + MB_INFO_FLAGS]
    test eax, MB_FLAG_FRAMEBUFFER
    jz .use_vga_fallback

    ; Copy framebuffer address (use low 32 bits)
    mov eax, [ebx + MB_INFO_FRAMEBUFFER_ADDR]
    mov [VIDEO_INFO_FB], eax

    ; Copy width
    mov eax, [ebx + MB_INFO_FRAMEBUFFER_WIDTH]
    mov [VIDEO_INFO_W], eax

    ; Copy height
    mov eax, [ebx + MB_INFO_FRAMEBUFFER_HEIGHT]
    mov [VIDEO_INFO_H], eax

    ; Copy pitch (bytes per scanline)
    mov eax, [ebx + MB_INFO_FRAMEBUFFER_PITCH]
    mov [VIDEO_INFO_PITCH], eax

    ; Copy bits per pixel
    movzx eax, byte [ebx + MB_INFO_FRAMEBUFFER_BPP]
    mov [VIDEO_INFO_BPP], eax

    ; Mark VESA mode enabled
    mov dword [VIDEO_INFO_VESA], 1

    jmp .done

.use_vga_fallback:
    ; VGA 320x200x8 fallback
    mov dword [VIDEO_INFO_FB], VGA_FRAMEBUFFER
    mov dword [VIDEO_INFO_W], VGA_WIDTH
    mov dword [VIDEO_INFO_H], VGA_HEIGHT
    mov dword [VIDEO_INFO_PITCH], VGA_PITCH
    mov dword [VIDEO_INFO_BPP], VGA_BPP
    mov dword [VIDEO_INFO_VESA], 0

.done:
    pop esi
    pop ebx
    ret

; ============================================================================
; DATA
; ============================================================================

section .data

boot_mode:          db 0    ; 0 = legacy, 1 = multiboot
multiboot_info_ptr: dd 0    ; Pointer to multiboot_info structure
