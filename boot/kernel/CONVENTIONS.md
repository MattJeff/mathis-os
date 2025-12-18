# MATHIS OS - Calling Conventions

## x86-64 System V ABI (Linux/macOS compatible)

```
════════════════════════════════════════════════════════════════════════════════
                         CALLING CONVENTION MATHIS OS
════════════════════════════════════════════════════════════════════════════════

ARGUMENTS (in order):
    1st: RDI
    2nd: RSI
    3rd: RDX
    4th: RCX
    5th: R8
    6th: R9
    7th+: Stack (push right-to-left)

RETURN VALUE:
    RAX (64-bit)
    RAX:RDX (128-bit)

CALLER-SAVED (scratch - may be destroyed by callee):
    RAX, RCX, RDX, RSI, RDI, R8, R9, R10, R11

CALLEE-SAVED (preserved - must be restored if used):
    RBX, RBP, R12, R13, R14, R15

STACK:
    RSP must be 16-byte aligned BEFORE call instruction
    (call pushes 8-byte return address, so callee sees RSP % 16 == 8)

════════════════════════════════════════════════════════════════════════════════
```

## Golden Rules

### Rule 1: Save your data in PRESERVED registers
```asm
; BAD - r10 is SCRATCH, will be destroyed by any call
mov r10d, [some_value]
call some_function      ; r10 is now GARBAGE
mov eax, r10d           ; BUG!

; GOOD - r12 is PRESERVED, safe across calls
mov r12d, [some_value]
call some_function      ; r12 is still valid
mov eax, r12d           ; OK!
```

### Rule 2: Save PRESERVED registers if you use them
```asm
my_function:
    push r12            ; Save before using
    push r13

    mov r12d, edi       ; Now safe to use r12, r13
    mov r13d, esi

    ; ... do work ...

    pop r13             ; Restore in reverse order
    pop r12
    ret
```

### Rule 3: Align stack before calls
```asm
; If you pushed an odd number of 8-byte values, align before call
my_function:
    push rbx            ; 1 push = 8 bytes, stack now misaligned
    sub rsp, 8          ; Align to 16 bytes

    call other_function ; Stack is aligned

    add rsp, 8
    pop rbx
    ret
```

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│  REGISTER    │  PURPOSE         │  SAVE BEFORE CALL?       │
├─────────────────────────────────────────────────────────────┤
│  RAX         │  Return value    │  NO (scratch)            │
│  RBX         │  General         │  YES (preserved)         │
│  RCX         │  Arg 4           │  NO (scratch)            │
│  RDX         │  Arg 3           │  NO (scratch)            │
│  RSI         │  Arg 2           │  NO (scratch)            │
│  RDI         │  Arg 1           │  NO (scratch)            │
│  RBP         │  Frame pointer   │  YES (preserved)         │
│  RSP         │  Stack pointer   │  YES (special)           │
│  R8          │  Arg 5           │  NO (scratch)            │
│  R9          │  Arg 6           │  NO (scratch)            │
│  R10         │  Scratch         │  NO (scratch)            │
│  R11         │  Scratch         │  NO (scratch)            │
│  R12-R15     │  General         │  YES (preserved)         │
└─────────────────────────────────────────────────────────────┘
```

## Common Patterns

### Pattern: Loop with function calls
```asm
; Need to preserve: loop counter, array pointer
my_loop:
    push r12
    push r13
    mov r12d, ecx           ; loop count -> PRESERVED
    mov r13, rdi            ; array ptr -> PRESERVED

.loop:
    mov rdi, [r13]          ; arg1 from array
    call process_item       ; may destroy rdi, rsi, etc.
    add r13, 8              ; next item (r13 safe!)
    dec r12d                ; counter (r12 safe!)
    jnz .loop

    pop r13
    pop r12
    ret
```

### Pattern: Multiple parameters to preserve
```asm
draw_rect:
    ; Args: edi=x, esi=y, edx=w, ecx=h, r8d=color
    push r12
    push r13
    push r14
    push r15
    push rbx

    mov r12d, edi           ; x
    mov r13d, esi           ; y
    mov r14d, edx           ; w
    mov r15d, ecx           ; h
    mov ebx, r8d            ; color

    ; Now call other functions freely
    ; r12-r15 and rbx are safe

    pop rbx
    pop r15
    pop r14
    pop r13
    pop r12
    ret
```

## ISR (Interrupt Service Routines)

```
SPECIAL RULES FOR ISRs:
- Save ALL registers you use (CPU doesn't save them)
- Use IRETQ instead of RET
- Keep it SHORT - interrupts are disabled
- Don't call complex functions from ISRs
```

```asm
timer_isr:
    push rax
    push rcx
    push rdx
    ; ... minimal work ...
    mov al, 0x20
    out 0x20, al            ; EOI
    pop rdx
    pop rcx
    pop rax
    iretq
```
