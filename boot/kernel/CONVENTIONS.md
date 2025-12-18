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

## V-Table (Object-Oriented) Conventions

### Object Structure

```
┌─────────────────────────────────────────────────────────────┐
│  OBJECT MEMORY LAYOUT                                       │
├─────────────────────────────────────────────────────────────┤
│  Offset 0:   vtable pointer (8 bytes)                       │
│  Offset 8:   object data...                                 │
└─────────────────────────────────────────────────────────────┘
```

### V-Table Calling Convention

```asm
; ═══════════════════════════════════════════════════════════════
; CALLING A METHOD VIA V-TABLE
; ═══════════════════════════════════════════════════════════════
; 1. rdi = self (object pointer) - ALWAYS first argument
; 2. Other args in rsi, rdx, rcx, r8, r9
; 3. Get vtable from object
; 4. Call method at correct offset

; Example: call object->draw(self)
call_draw:
    ; rdi = object pointer (self)
    mov rax, [rdi]              ; rax = vtable pointer
    call [rax + VT_DRAW]        ; call draw method
    ret

; Example: call object->on_click(self, x, y)
call_click:
    ; rdi = object, esi = x, edx = y
    mov rax, [rdi]              ; rax = vtable pointer
    call [rax + VT_ON_CLICK]    ; call on_click method
    ret
```

### Standard V-Table Offsets

```
┌─────────────────────────────────────────────────────────────┐
│  WIDGET V-TABLE STANDARD                                    │
├─────────────────────────────────────────────────────────────┤
│  Offset 0:   draw(self)                                     │
│  Offset 8:   on_click(self, x, y)                           │
│  Offset 16:  on_key(self, scancode)                         │
│  Offset 24:  on_focus(self, focused)                        │
│  Offset 32:  destroy(self)                                  │
│  Offset 40:  get_size(self) -> eax=w, edx=h                 │
└─────────────────────────────────────────────────────────────┘
```

### Object Creation Pattern

```asm
; ═══════════════════════════════════════════════════════════════
; OBJECT CREATION (Constructor)
; ═══════════════════════════════════════════════════════════════
button_create:
    push rbx
    push r12

    ; 1. Allocate memory
    mov rdi, BUTTON_SIZE
    call kmalloc
    test rax, rax
    jz .fail
    mov rbx, rax                ; rbx = new object

    ; 2. Set vtable pointer (FIRST!)
    lea rax, [button_vtable]
    mov [rbx], rax

    ; 3. Initialize fields
    mov dword [rbx + WIDGET_X], 0
    mov dword [rbx + WIDGET_Y], 0
    mov dword [rbx + WIDGET_FLAGS], WIDGET_VISIBLE

    ; 4. Return object
    mov rax, rbx
    pop r12
    pop rbx
    ret

.fail:
    xor eax, eax
    pop r12
    pop rbx
    ret
```

### Object Destruction Pattern

```asm
; ═══════════════════════════════════════════════════════════════
; OBJECT DESTRUCTION (Destructor)
; ═══════════════════════════════════════════════════════════════
button_destroy:
    push rbx
    mov rbx, rdi                ; Save self

    ; 1. Destroy children first (if any)
    mov rdi, [rbx + WIDGET_CHILDREN]
    test rdi, rdi
    jz .no_children
    call destroy_children
.no_children:

    ; 2. Free own resources
    ; (nothing for simple button)

    ; 3. Free self
    mov rdi, rbx
    call kfree

    pop rbx
    ret
```

## Service Pattern

### Service Registration

```asm
; At boot time, drivers register themselves:
driver_init:
    mov edi, SVC_VIDEO          ; Service ID
    lea rsi, [vesa_vtable]      ; Implementation vtable
    call register_service
    ret
```

### Service Usage

```asm
; Always check service availability:
use_video:
    mov edi, SVC_VIDEO
    call get_service
    test rax, rax
    jz .no_video_service        ; Handle gracefully!

    ; Use service via vtable
    mov rdi, rax                ; vtable in rdi
    mov esi, 0x00FF0000         ; color arg
    call [rdi + VIDEO_CLEAR]    ; call clear(color)
    ret

.no_video_service:
    ; Log error or fallback
    ret
```

## Memory Ownership Rules

```
┌─────────────────────────────────────────────────────────────┐
│  WHO OWNS WHAT?                                             │
├─────────────────────────────────────────────────────────────┤
│  1. Creator is responsible for destruction                  │
│  2. Parent widgets own their children                       │
│  3. Strings: caller owns unless documented otherwise        │
│  4. Callbacks: caller ensures validity                      │
│  5. Services: kernel owns, never free                       │
└─────────────────────────────────────────────────────────────┘
```

### Example: Ownership Transfer

```asm
; When adding child to parent, parent takes ownership:
window_add_child:
    ; rdi = parent, rsi = child
    ; After this call, parent owns child
    ; Parent will destroy child when destroyed
    ...
    ret

; Caller should NOT free child after adding:
    call button_create
    mov rsi, rax                ; child = new button
    mov rdi, [my_window]        ; parent
    call window_add_child
    ; DON'T call button_destroy here!
    ; Parent will do it when window closes
```
