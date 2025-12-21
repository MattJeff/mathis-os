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
    push rbx
    push rdi
    push rcx

    ; ══════════════════════════════════════════════════════════════════
    ; 1. Setup CPU exceptions (INT 0x00 - 0x1F) with BSOD handlers
    ; ══════════════════════════════════════════════════════════════════
    call setup_exception_handlers

    ; ══════════════════════════════════════════════════════════════════
    ; 2. Hardware IRQs (0x20-0x2F)
    ; ══════════════════════════════════════════════════════════════════
    mov rdi, idt64 + 0x20 * 16      ; IRQ0 (timer)
    mov rax, timer_isr64
    call set_idt_entry

    mov rdi, idt64 + 0x21 * 16      ; IRQ1 (keyboard)
    mov rax, keyboard_isr64
    call set_idt_entry

    mov rdi, idt64 + 0x2C * 16      ; IRQ12 (mouse)
    mov rax, mouse_isr64
    call set_idt_entry

    mov rdi, idt64 + 0x80 * 16      ; INT 0x80 (syscall)
    mov rax, syscall_isr64
    call set_idt_entry_user

    lidt [idt64_ptr]

    pop rcx
    pop rdi
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; SETUP_EXCEPTION_HANDLERS - Install all CPU exception handlers
; ════════════════════════════════════════════════════════════════════════════
setup_exception_handlers:
    push rax
    push rdi

    ; Exceptions without error code
    mov rdi, idt64 + 0x00 * 16
    mov rax, exc_handler_00         ; #DE Divide Error
    call set_idt_entry

    mov rdi, idt64 + 0x01 * 16
    mov rax, exc_handler_01         ; #DB Debug
    call set_idt_entry

    mov rdi, idt64 + 0x02 * 16
    mov rax, exc_handler_02         ; NMI
    call set_idt_entry

    mov rdi, idt64 + 0x03 * 16
    mov rax, exc_handler_03         ; #BP Breakpoint
    call set_idt_entry

    mov rdi, idt64 + 0x04 * 16
    mov rax, exc_handler_04         ; #OF Overflow
    call set_idt_entry

    mov rdi, idt64 + 0x05 * 16
    mov rax, exc_handler_05         ; #BR Bound Range
    call set_idt_entry

    mov rdi, idt64 + 0x06 * 16
    mov rax, exc_handler_06         ; #UD Invalid Opcode
    call set_idt_entry

    mov rdi, idt64 + 0x07 * 16
    mov rax, exc_handler_07         ; #NM No FPU
    call set_idt_entry

    ; Exception 8: Double Fault - uses IST1 for separate stack
    mov rdi, idt64 + 0x08 * 16
    mov rax, exc_handler_08         ; #DF Double Fault
    mov cl, 1                       ; IST1
    call set_idt_entry_ist

    mov rdi, idt64 + 0x09 * 16
    mov rax, exc_handler_09         ; FPU Segment Overrun
    call set_idt_entry

    ; Exceptions with error code
    mov rdi, idt64 + 0x0A * 16
    mov rax, exc_handler_0a         ; #TS Invalid TSS
    call set_idt_entry

    mov rdi, idt64 + 0x0B * 16
    mov rax, exc_handler_0b         ; #NP Segment Not Present
    call set_idt_entry

    mov rdi, idt64 + 0x0C * 16
    mov rax, exc_handler_0c         ; #SS Stack Fault
    call set_idt_entry

    mov rdi, idt64 + 0x0D * 16
    mov rax, exc_handler_0d         ; #GP General Protection
    call set_idt_entry

    mov rdi, idt64 + 0x0E * 16
    mov rax, exc_handler_0e         ; #PF Page Fault
    call set_idt_entry

    ; Remaining exceptions (0x0F - 0x1F)
    mov rdi, idt64 + 0x0F * 16
    mov rax, exc_handler_0f
    call set_idt_entry

    mov rdi, idt64 + 0x10 * 16
    mov rax, exc_handler_10         ; #MF FPU Error
    call set_idt_entry

    mov rdi, idt64 + 0x11 * 16
    mov rax, exc_handler_11         ; #AC Alignment Check
    call set_idt_entry

    mov rdi, idt64 + 0x12 * 16
    mov rax, exc_handler_12         ; #MC Machine Check
    call set_idt_entry

    mov rdi, idt64 + 0x13 * 16
    mov rax, exc_handler_13         ; #XM SIMD Error
    call set_idt_entry

    mov rdi, idt64 + 0x14 * 16
    mov rax, exc_handler_14         ; Virtualization
    call set_idt_entry

    ; Fill remaining with default handler
    mov rdi, idt64 + 0x15 * 16
    mov rax, default_exception_handler
    mov rcx, 11                     ; 0x15 to 0x1F
.fill_remaining:
    push rcx
    call set_idt_entry
    add rdi, 16
    pop rcx
    loop .fill_remaining

    pop rdi
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DEFAULT EXCEPTION HANDLER - Catch-all to prevent triple fault
; Simply halts the CPU instead of rebooting
; ════════════════════════════════════════════════════════════════════════════
default_exception_handler:
    cli                             ; Disable interrupts
.halt_loop:
    hlt                             ; Halt CPU
    jmp .halt_loop                  ; Loop forever if NMI wakes us

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
; SET_IDT_ENTRY_IST - IDT entry with Interrupt Stack Table
; Input: rdi = IDT entry address, rax = ISR address, cl = IST index (1-7)
; ════════════════════════════════════════════════════════════════════════════
set_idt_entry_ist:
    mov word [rdi], ax
    mov word [rdi + 2], 0x08        ; Kernel code selector
    mov byte [rdi + 4], cl          ; IST index (1-7)
    mov byte [rdi + 5], 0x8E        ; Present, DPL=0, Interrupt Gate
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
