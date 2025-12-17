; ============================================================================
; MathisOS - System Setup Functions
; ============================================================================
; Hardware initialization: IDT, TSS, PIC, PIT
; Called once at boot time from long_mode_entry
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; SETUP IDT - Interrupt Descriptor Table
; ════════════════════════════════════════════════════════════════════════════
setup_idt64:
    push rax
    push rdi
    push rcx

    ; Clear IDT
    mov rdi, idt64
    mov rcx, 512
    xor rax, rax
    rep stosq

    ; IRQ0 (timer) at 0x20
    mov rdi, idt64 + 0x20 * 16
    mov rax, timer_isr64
    call set_idt_entry

    ; IRQ1 (keyboard) at 0x21
    mov rdi, idt64 + 0x21 * 16
    mov rax, keyboard_isr64
    call set_idt_entry

    ; IRQ12 (mouse) at 0x2C
    mov rdi, idt64 + 0x2C * 16
    mov rax, mouse_isr64
    call set_idt_entry

    ; INT 0x80 (syscall) - Ring 3 callable
    mov rdi, idt64 + 0x80 * 16
    mov rax, syscall_isr64
    call set_idt_entry_user        ; DPL=3 so user can call it

    lidt [idt64_ptr]

    pop rcx
    pop rdi
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; SET_IDT_ENTRY - Standard IDT entry (DPL=0, kernel only)
; Input: rdi = IDT entry address, rax = ISR address
; ════════════════════════════════════════════════════════════════════════════
set_idt_entry:
    mov word [rdi], ax
    mov word [rdi + 2], 0x08        ; Kernel code selector
    mov byte [rdi + 4], 0
    mov byte [rdi + 5], 0x8E        ; Present, DPL=0, Interrupt Gate
    shr rax, 16
    mov word [rdi + 6], ax
    shr rax, 16
    mov dword [rdi + 8], eax
    mov dword [rdi + 12], 0
    ret

; ════════════════════════════════════════════════════════════════════════════
; SET_IDT_ENTRY_USER - IDT entry callable from Ring 3 (DPL=3)
; Input: rdi = IDT entry address, rax = ISR address
; ════════════════════════════════════════════════════════════════════════════
set_idt_entry_user:
    mov word [rdi], ax
    mov word [rdi + 2], 0x08        ; Kernel code selector
    mov byte [rdi + 4], 0
    mov byte [rdi + 5], 0xEE        ; Present, DPL=3, Interrupt Gate
    shr rax, 16
    mov word [rdi + 6], ax
    shr rax, 16
    mov dword [rdi + 8], eax
    mov dword [rdi + 12], 0
    ret

; ════════════════════════════════════════════════════════════════════════════
; SETUP TSS - Task State Segment for Ring 3 → Ring 0 transitions
; ════════════════════════════════════════════════════════════════════════════
setup_tss64:
    push rax
    push rbx
    push rcx

    ; Patch TSS base address into GDT descriptor (at offset 0x28)
    ; TSS descriptor is 16 bytes at gdt64 + 0x28
    mov rax, tss64                  ; Get TSS address

    ; Patch Base 15:0 (offset +2 in TSS descriptor)
    mov rbx, gdt64
    add rbx, 0x28                   ; Point to TSS descriptor
    mov word [rbx + 2], ax          ; Base 15:0

    ; Patch Base 23:16 (offset +4)
    shr rax, 16
    mov byte [rbx + 4], al          ; Base 23:16

    ; Patch Base 31:24 (offset +7)
    shr rax, 8
    mov byte [rbx + 7], al          ; Base 31:24

    ; Patch Base 63:32 (offset +8)
    mov rax, tss64
    shr rax, 32
    mov dword [rbx + 8], eax        ; Base 63:32

    ; Note: Don't reload GDT here - gdt64_ptr is 32-bit format
    ; The GDT is already loaded and we just patched it in memory

    ; Load TSS
    mov ax, TSS_SEL
    ltr ax

    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; SETUP PIC - Programmable Interrupt Controller (8259A)
; Remaps IRQs to 0x20-0x2F to avoid CPU exception conflicts
; ════════════════════════════════════════════════════════════════════════════
setup_pic64:
    push rax

    ; ICW1: Initialize + ICW4 needed
    mov al, 0x11
    out 0x20, al                    ; Master PIC command
    out 0xA0, al                    ; Slave PIC command

    ; ICW2: Vector offsets
    mov al, 0x20                    ; Master: IRQ 0-7 -> INT 0x20-0x27
    out 0x21, al
    mov al, 0x28                    ; Slave: IRQ 8-15 -> INT 0x28-0x2F
    out 0xA1, al

    ; ICW3: Cascade configuration
    mov al, 0x04                    ; Master: Slave on IRQ2
    out 0x21, al
    mov al, 0x02                    ; Slave: Cascade identity
    out 0xA1, al

    ; ICW4: 8086 mode
    mov al, 0x01
    out 0x21, al
    out 0xA1, al

    ; OCW1: Interrupt masks
    mov al, 0xF8                    ; Master: Enable IRQ0, IRQ1, IRQ2 (cascade)
    out 0x21, al
    mov al, 0xEF                    ; Slave: Enable IRQ12 (mouse)
    out 0xA1, al

    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; SETUP PIT - Programmable Interval Timer (8254)
; Configures Channel 0 for ~100Hz system tick
; ════════════════════════════════════════════════════════════════════════════
setup_pit64:
    push rax

    ; Channel 0, Mode 3 (square wave), binary
    mov al, 0x36
    out 0x43, al

    ; Divisor = 1193182 / 100 = 11932 (0x2E9C) for ~100Hz
    mov al, 0x9C                    ; Low byte
    out 0x40, al
    mov al, 0x2E                    ; High byte
    out 0x40, al

    pop rax
    ret
