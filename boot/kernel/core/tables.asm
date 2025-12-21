; ============================================================================
; TABLES.ASM - Descriptor Tables Module
; ============================================================================
; Contains: GDT64, IDT64, TSS64, and setup functions
; All tables and helper functions for interrupt handling
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
IST1_STACK_TOP      equ 0x8F000

KERNEL_CODE_SEL     equ 0x08
KERNEL_DATA_SEL     equ 0x10
USER_CODE_SEL       equ 0x1B
USER_DATA_SEL       equ 0x23
TSS_SEL             equ 0x28

; ============================================================================
; EXPORTS
; ============================================================================
global setup_idt64
global setup_tss64
global setup_pic64
global setup_pit64
global idt64
global idt64_ptr
global tss64
global gdt64_full
global gdt64_full_ptr
global set_idt_entry
global default_exception_handler

; ============================================================================
; IMPORTS
; ============================================================================
extern tick_count
extern keyboard_isr64
extern mouse_isr64
extern mouse_init

; ============================================================================
; CODE SECTION
; ============================================================================
section .text

; ============================================================================
; SETUP_IDT64 - Initialize Interrupt Descriptor Table
; ============================================================================
setup_idt64:
    push rax
    push rbx
    push rdi
    push rcx

    ; Fill all entries with default handler first
    mov rdi, idt64
    mov rax, default_exception_handler
    mov rcx, 256
.fill_all:
    push rcx
    call set_idt_entry
    add rdi, 16
    pop rcx
    loop .fill_all

    ; Timer (IRQ0 -> INT 0x20)
    mov rdi, idt64 + 0x20 * 16
    mov rax, timer_isr64
    call set_idt_entry

    ; Keyboard (IRQ1 -> INT 0x21)
    mov rdi, idt64 + 0x21 * 16
    mov rax, keyboard_isr64
    call set_idt_entry

    ; Mouse (IRQ12 -> INT 0x2C)
    mov rdi, idt64 + 0x2C * 16
    mov rax, mouse_isr64
    call set_idt_entry

    ; Load IDT
    lidt [idt64_ptr]

    pop rcx
    pop rdi
    pop rbx
    pop rax
    ret

; ============================================================================
; SET_IDT_ENTRY - Create IDT entry
; Input: rdi = entry address, rax = handler address
; ============================================================================
set_idt_entry:
    mov word [rdi], ax              ; Offset 15:0
    mov word [rdi + 2], 0x08        ; Kernel code selector
    mov byte [rdi + 4], 0           ; IST = 0
    mov byte [rdi + 5], 0x8E        ; Present, DPL=0, Interrupt Gate
    shr rax, 16
    mov word [rdi + 6], ax          ; Offset 31:16
    shr rax, 16
    mov dword [rdi + 8], eax        ; Offset 63:32
    mov dword [rdi + 12], 0         ; Reserved
    ret

; ============================================================================
; DEFAULT_EXCEPTION_HANDLER - Catch-all handler
; ============================================================================
default_exception_handler:
    cli
.halt:
    hlt
    jmp .halt

; ============================================================================
; SETUP_TSS64 - Initialize Task State Segment
; ============================================================================
setup_tss64:
    push rax
    push rbx

    ; First reload GDT with full version (includes TSS descriptor)
    lgdt [gdt64_full_ptr]

    ; Patch TSS base address into GDT descriptor at offset 0x28
    mov rax, tss64
    mov rbx, gdt64_full + 0x28

    ; Base 15:0
    mov word [rbx + 2], ax
    shr rax, 16

    ; Base 23:16
    mov byte [rbx + 4], al
    shr rax, 8

    ; Base 31:24
    mov byte [rbx + 7], al

    ; Base 63:32
    mov rax, tss64
    shr rax, 32
    mov dword [rbx + 8], eax

    ; Load TSS
    mov ax, TSS_SEL
    ltr ax

    pop rbx
    pop rax
    ret

; ============================================================================
; SETUP_PIC64 - Initialize 8259A PIC
; ============================================================================
setup_pic64:
    push rax

    ; ICW1
    mov al, 0x11
    out 0x20, al
    out 0xA0, al

    ; ICW2 - Vector offsets
    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al

    ; ICW3 - Cascade
    mov al, 0x04
    out 0x21, al
    mov al, 0x02
    out 0xA1, al

    ; ICW4 - 8086 mode
    mov al, 0x01
    out 0x21, al
    out 0xA1, al

    ; Enable timer, keyboard (master) and mouse (slave IRQ12)
    mov al, 0xF8                ; 11111000 = enable IRQ0,1,2 (cascade)
    out 0x21, al
    mov al, 0xEF                ; 11101111 = enable IRQ12 (mouse)
    out 0xA1, al

    ; Initialize mouse
    call mouse_init

    pop rax
    ret

; ============================================================================
; SETUP_PIT64 - Initialize 8254 PIT at 100Hz
; ============================================================================
setup_pit64:
    push rax

    ; Channel 0, Mode 3, binary
    mov al, 0x36
    out 0x43, al

    ; Divisor = 11932 for ~100Hz
    mov al, 0x9C
    out 0x40, al
    mov al, 0x2E
    out 0x40, al

    pop rax
    ret

; ============================================================================
; TIMER_ISR64 - Timer interrupt handler
; ============================================================================
global timer_isr64
timer_isr64:
    push rax

    ; Increment tick counter
    inc qword [tick_count]

    ; Send EOI
    mov al, 0x20
    out 0x20, al

    pop rax
    iretq

; ============================================================================
; DATA SECTION
; ============================================================================
section .data

; IDT - 256 entries x 16 bytes = 4096 bytes
align 16
idt64:
    times 256 dq 0, 0

idt64_ptr:
    dw 256 * 16 - 1
    dq idt64

; Full GDT with Ring 3 and TSS support
align 16
gdt64_full:
    dq 0                            ; 0x00: Null
    dq 0x00209A0000000000           ; 0x08: Kernel Code
    dq 0x0000920000000000           ; 0x10: Kernel Data
    dq 0x0020FA0000000000           ; 0x18: User Code
    dq 0x0000F20000000000           ; 0x20: User Data
    ; 0x28: TSS descriptor (16 bytes)
    dw 104                          ; Limit
    dw 0                            ; Base 15:0 (patched)
    db 0                            ; Base 23:16
    db 0x89                         ; Type: TSS Available
    db 0x00                         ; Flags
    db 0                            ; Base 31:24
    dd 0                            ; Base 63:32
    dd 0                            ; Reserved
gdt64_full_end:

gdt64_full_ptr:
    dw gdt64_full_end - gdt64_full - 1
    dq gdt64_full

; TSS - Task State Segment
align 16
tss64:
    dd 0                            ; Reserved
    dq 0x90000                      ; RSP0
    dq 0                            ; RSP1
    dq 0                            ; RSP2
    dq 0                            ; Reserved
    dq IST1_STACK_TOP               ; IST1
    dq 0                            ; IST2
    dq 0                            ; IST3
    dq 0                            ; IST4
    dq 0                            ; IST5
    dq 0                            ; IST6
    dq 0                            ; IST7
    dq 0                            ; Reserved
    dw 0                            ; Reserved
    dw 104                          ; IOPB
tss64_end:

; ============================================================================
; BSS SECTION
; ============================================================================
section .bss
