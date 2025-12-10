; ═══════════════════════════════════════════════════════════════════════════
; MATHIS OS STAGE2 - Hard Disk LBA Edition
; Loads 256KB kernel, enters protected mode
; ═══════════════════════════════════════════════════════════════════════════

[BITS 16]
[ORG 0x7E00]

KERNEL_SECTORS  equ 512         ; 256KB = 512 sectors
KERNEL_LBA      equ 9           ; Kernel starts at LBA 9

start:
    mov si, msg_loading
    call print_string

    ; Save boot drive
    mov [boot_drive], dl

    ; Load kernel in 8 chunks of 64 sectors (32KB each)
    mov dword [current_lba], KERNEL_LBA
    mov word [current_seg], 0x1000   ; Load at 0x10000
    mov cx, 8                         ; 8 chunks

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

    ; Set VGA mode 13h
    mov ax, 0x0013
    int 0x10

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

; DAP for LBA read
align 4
dap:
    db 0x10, 0
dap_sectors:    dw 0
dap_offset:     dw 0
dap_segment:    dw 0
dap_lba_low:    dd 0
dap_lba_high:   dd 0

msg_loading: db "MATHIS OS [256KB]", 0
msg_ok:      db " OK", 13, 10, 0
msg_error:   db " ERR!", 0

[BITS 32]
pm_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000

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
