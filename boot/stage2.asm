; ═══════════════════════════════════════════════════════════════════════════
; MATHIS OS STAGE2 - VESA 640x480 Edition
; Loads 512KB kernel, sets VESA mode, enters protected mode
; ═══════════════════════════════════════════════════════════════════════════

[BITS 16]
[ORG 0x7E00]

KERNEL_SECTORS  equ 1024        ; 512KB = 1024 sectors
KERNEL_LBA      equ 9           ; Kernel starts at LBA 9

; VESA mode preferences - we'll scan for a 32-bit mode
; Common 32-bit modes: 0x112 (640x480), 0x115 (800x600), 0x11B (1280x1024)
; If 32-bit not found, falls back to 24-bit
PREFERRED_WIDTH  equ 1024
PREFERRED_HEIGHT equ 768

start:
    mov si, msg_loading
    call print_string

    ; Save boot drive
    mov [boot_drive], dl

    ; Load kernel in 16 chunks of 64 sectors (32KB each)
    mov dword [current_lba], KERNEL_LBA
    mov word [current_seg], 0x1000   ; Load at 0x10000
    mov cx, 16                        ; 16 chunks = 512KB

.load_loop:
    push cx

    ; Setup DAP
    mov word [dap_sectors], 64
    mov ax, [current_seg]
    mov word [dap_segment], ax
    mov word [dap_offset], 0
    mov eax, [current_lba]
    mov dword [dap_lba_low], eax

    ; Read sectors using LBA
    mov si, dap
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; Print dot for progress
    mov al, '.'
    mov ah, 0x0E
    int 0x10

    ; Next chunk
    add dword [current_lba], 64
    add word [current_seg], 0x800    ; +32KB

    pop cx
    loop .load_loop

    ; Print OK
    mov si, msg_ok
    call print_string

    ; === Scan VESA modes for 32-bit ===
    mov si, msg_vesa
    call print_string

    ; First get VESA info block to find mode list pointer
    mov ax, 0x4F00              ; Get VESA info
    mov di, vesa_info           ; Buffer for VESA info
    mov dword [di], 'VBE2'      ; Request VBE 2.0+ info
    int 0x10
    cmp ax, 0x004F
    jne .vesa_fail

    ; Get pointer to mode list (offset 14 = segment:offset)
    mov si, [vesa_info + 14]    ; Offset of mode list
    mov ax, [vesa_info + 16]    ; Segment of mode list
    mov es, ax                  ; ES:SI = mode list pointer

    ; Initialize best mode tracking
    mov word [best_mode], 0xFFFF    ; No mode found yet
    mov byte [best_bpp], 0

.scan_modes:
    mov cx, [es:si]             ; Get mode number
    cmp cx, 0xFFFF              ; End of list?
    je .scan_done
    add si, 2                   ; Next mode in list

    ; Get info for this mode
    push es
    push si
    push cx

    push ds
    pop es                      ; ES = DS for mode_info buffer
    mov ax, 0x4F01              ; Get mode info
    mov di, mode_info
    int 0x10

    pop cx
    pop si
    pop es

    cmp ax, 0x004F              ; Success?
    jne .scan_modes

    ; Check if mode has LFB support (bit 7)
    mov ax, [mode_info]
    test ax, 0x80
    jz .scan_modes

    ; Check resolution matches our preference (or close)
    mov ax, [mode_info + 18]    ; Width
    cmp ax, PREFERRED_WIDTH
    jne .check_smaller_res
    mov ax, [mode_info + 20]    ; Height
    cmp ax, PREFERRED_HEIGHT
    jne .check_smaller_res
    jmp .resolution_ok

.check_smaller_res:
    ; Accept 800x600 or 640x480 as fallback
    mov ax, [mode_info + 18]
    cmp ax, 640
    jl .scan_modes              ; Too small
    cmp ax, 1280
    jg .scan_modes              ; Too big

.resolution_ok:
    ; Check BPP - prefer 32, accept 24
    mov al, [mode_info + 25]    ; BitsPerPixel
    cmp al, 32
    je .found_32bit
    cmp al, 24
    jne .scan_modes             ; Not 24 or 32, skip

    ; It's 24-bit - save if we don't have 32-bit yet
    cmp byte [best_bpp], 32
    je .scan_modes              ; Already have 32-bit, skip
    mov [best_mode], cx
    mov [best_bpp], al
    jmp .scan_modes

.found_32bit:
    ; Found 32-bit mode - this is what we want!
    mov [best_mode], cx
    mov byte [best_bpp], 32
    ; Keep scanning in case there's a better 32-bit mode
    jmp .scan_modes

.scan_done:
    ; Restore ES to data segment
    push ds
    pop es

    ; Check if we found a suitable mode
    cmp word [best_mode], 0xFFFF
    je .vesa_fail

    ; Get final mode info for the best mode we found
    mov ax, 0x4F01
    mov cx, [best_mode]
    mov di, mode_info
    int 0x10

    ; Set the VESA mode with LFB
    mov ax, 0x4F02
    mov bx, [best_mode]
    or bx, 0x4000               ; Enable LFB
    int 0x10
    cmp ax, 0x004F
    jne .vesa_fail

    ; Success! Get LFB address and dimensions
    mov eax, [mode_info + 40]   ; PhysBasePtr at offset 40
    mov [framebuffer_addr], eax

    mov ax, [mode_info + 18]    ; XResolution at offset 18
    mov [screen_width], ax

    mov ax, [mode_info + 20]    ; YResolution at offset 20
    mov [screen_height], ax

    mov ax, [mode_info + 16]    ; BytesPerScanLine at offset 16
    mov [screen_pitch], ax

    mov al, [mode_info + 25]    ; BitsPerPixel at offset 25
    mov [screen_bpp], al

    mov byte [vesa_mode], 1

    mov si, msg_vesa_ok
    call print_string
    jmp .video_done

.vesa_fail:
    ; Fallback to VGA 320x200
    mov si, msg_vga
    call print_string
    mov ax, 0x0013
    int 0x10
    mov dword [framebuffer_addr], 0xA0000
    mov word [screen_width], 320
    mov word [screen_height], 200
    mov word [screen_pitch], 320
    mov byte [vesa_mode], 0

.video_done:
    ; Enable A20
    in al, 0x92
    or al, 2
    and al, 0xFE
    out 0x92, al

    cli
    lgdt [gdt_ptr]

    ; Enter protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x08:pm_entry

disk_error:
    mov si, msg_error
    call print_string
    cli
    hlt

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done:
    ret

; Variables
boot_drive:     db 0
current_lba:    dd 0
current_seg:    dw 0
framebuffer_addr: dd 0xA0000
screen_width:   dw 320
screen_height:  dw 200
screen_pitch:   dw 320
screen_bpp:     db 8            ; Bits per pixel (8, 24, or 32)
vesa_mode:      db 0
best_mode:      dw 0xFFFF       ; Best VESA mode found during scan
best_bpp:       db 0            ; Best BPP found (prefer 32)

; DAP for LBA read
align 4
dap:
    db 0x10, 0
dap_sectors:    dw 0
dap_offset:     dw 0
dap_segment:    dw 0
dap_lba_low:    dd 0
dap_lba_high:   dd 0

msg_loading: db "MATHIS OS", 0
msg_ok:      db " OK", 13, 10, 0
msg_error:   db " ERR!", 0
msg_vesa:    db "VESA...", 0
msg_vesa_ok: db "OK!", 13, 10, 0
msg_vga:     db "VGA 320x200", 13, 10, 0

; VESA info buffers
align 16
vesa_info: times 512 db 0       ; VBE info block (512 bytes for VBE 2.0+)
mode_info: times 256 db 0       ; Mode info block (256 bytes)

[BITS 32]
pm_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000

    ; Pass video info to kernel at fixed memory location 0x500
    mov eax, [framebuffer_addr]
    mov [0x500], eax              ; Framebuffer address
    movzx eax, word [screen_width]
    mov [0x504], eax              ; Screen width
    movzx eax, word [screen_height]
    mov [0x508], eax              ; Screen height
    movzx eax, byte [vesa_mode]
    mov [0x50C], eax              ; VESA mode flag
    movzx eax, word [screen_pitch]
    mov [0x510], eax              ; Screen pitch (bytes per line)
    movzx eax, byte [screen_bpp]
    mov [0x514], eax              ; Bits per pixel (8, 24, or 32)

    jmp 0x08:0x10000

; GDT
align 16
gdt:
    dq 0
    dq 0x00CF9A000000FFFF   ; Code
    dq 0x00CF92000000FFFF   ; Data
gdt_end:

gdt_ptr:
    dw gdt_end - gdt - 1
    dd gdt

times 4096 - ($ - $$) db 0
