; ════════════════════════════════════════════════════════════════════════════
; DEBUG KEYBOARD ISR - STEP 2: LOCAL DATA
; ════════════════════════════════════════════════════════════════════════════

keyboard_isr:
    pushad
    
    ; Read scancode
    in al, 0x60
    mov bl, al
    
    ; Send EOI immediately
    mov al, 0x20
    out 0x20, al
    
    ; Ignore key release (bit 7 set)
    test bl, 0x80
    jnz .done
    
    ; Lookup char in LOCAL table
    movzx eax, bl
    cmp eax, 58
    jge .done
    
    ; Use CS override to read from code segment (where this table is)
    mov al, [cs:local_scancode_table + eax]
    test al, al
    jz .done
    
    ; Write to video memory
    ; Use CS override for local variable
    mov edi, [cs:local_cursor]
    
    ; Safety check for video memory bounds (0-4000)
    cmp edi, 4000
    jl .safe
    mov edi, 0
    mov [cs:local_cursor], edi
.safe:
    
    mov ah, 0x0F    ; White on Black
    
    ; Calculate absolute address: 0xB8000 + edi*2
    lea edx, [edi*2]
    add edx, 0xB8000
    mov [edx], ax
    
    ; Increment cursor
    inc edi
    mov [cs:local_cursor], edi
    
.done:
    popad
    iret

; ════════════════════════════════════════════════════════════════════════════
; LOCAL DATA (Embedded in Code Segment)
; ════════════════════════════════════════════════════════════════════════════

local_cursor: dd 0

local_scancode_table:
    db 0, 27, '1234567890-=', 8, 9
    db 'qwertyuiop[]', 13, 0
    db 'asdfghjkl', 0x3B, 0x27, '`', 0, '\'
    db 'zxcvbnm,./', 0, '*', 0, ' '
    times 70 db 0
