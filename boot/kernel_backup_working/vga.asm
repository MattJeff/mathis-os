; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - VGA MODULE
; Display functions
; ════════════════════════════════════════════════════════════════════════════

vga_clear:
    push eax
    push ecx
    push edi
    mov edi, 0xB8000
    mov ecx, 2000
    mov eax, 0x0720
    rep stosd
    pop edi
    pop ecx
    pop eax
    ret

vga_banner:
    push eax
    push esi
    push edi
    
    mov esi, banner_line1
    mov edi, 0xB8000
    mov ah, 0x0A
    call print_string
    
    mov esi, banner_line2
    mov edi, 0xB80A0
    call print_string
    
    mov esi, banner_line3
    mov edi, 0xB8140
    call print_string
    
    mov esi, banner_line4
    mov edi, 0xB81E0
    call print_string
    
    mov esi, banner_line5
    mov edi, 0xB8280
    call print_string
    
    mov esi, banner_line6
    mov edi, 0xB8320
    call print_string
    
    ; Info message
    mov esi, msg_info
    mov edi, 0xB8460
    mov ah, 0x07
    call print_string
    
    pop edi
    pop esi
    pop eax
    ret

vga_print_line:
    ; Print ESI at current prompt_line, color in AH
    push ebx
    push edi
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    call print_string
    pop edi
    pop ebx
    ret

vga_newline:
    inc dword [prompt_line]
    ret
