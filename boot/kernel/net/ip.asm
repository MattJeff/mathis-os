; ════════════════════════════════════════════════════════════════════════════
; IP.ASM - Internet Protocol v4
; ════════════════════════════════════════════════════════════════════════════
; IPv4 Header Structure (20 bytes minimum):
;   +0:  Version(4) + IHL(4)    - 0x45 for IPv4, 20 byte header
;   +1:  DSCP(6) + ECN(2)       - Usually 0
;   +2:  Total Length           - Header + Data (big-endian)
;   +4:  Identification         - Fragment ID
;   +6:  Flags(3) + FragOffset(13)
;   +8:  TTL                    - Time To Live (usually 64)
;   +9:  Protocol               - 1=ICMP, 6=TCP, 17=UDP
;   +10: Header Checksum        - One's complement
;   +12: Source IP              - 4 bytes
;   +16: Destination IP         - 4 bytes
; ════════════════════════════════════════════════════════════════════════════

; IP Protocol numbers
IP_PROTO_ICMP       equ 1
IP_PROTO_TCP        equ 6
IP_PROTO_UDP        equ 17

; IP Header offsets
IP_OFF_VER_IHL      equ 0
IP_OFF_TOS          equ 1
IP_OFF_TOTLEN       equ 2
IP_OFF_ID           equ 4
IP_OFF_FLAGS_FRAG   equ 6
IP_OFF_TTL          equ 8
IP_OFF_PROTO        equ 9
IP_OFF_CHECKSUM     equ 10
IP_OFF_SRC          equ 12
IP_OFF_DST          equ 16

; Default TTL
IP_DEFAULT_TTL      equ 64

; ════════════════════════════════════════════════════════════════════════════
; IP_HANDLE_PACKET - Process received IP packet
; Input: RSI = pointer to IP packet, RCX = length
; ════════════════════════════════════════════════════════════════════════════
ip_handle_packet:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Verify minimum length (20 bytes IP header)
    cmp rcx, 20
    jl .ip_done

    ; Check IP version (should be 4)
    mov al, [rsi]
    and al, 0xF0
    cmp al, 0x40                ; Version 4
    jne .ip_done

    ; Get header length (IHL * 4)
    mov al, [rsi]
    and eax, 0x0F
    shl eax, 2                  ; IHL * 4
    mov ebx, eax                ; EBX = header length

    cmp ebx, 20
    jl .ip_done                 ; Header too short
    cmp ebx, ecx
    jg .ip_done                 ; Header longer than packet

    ; Verify checksum
    push rcx
    mov ecx, ebx                ; Header length
    shr ecx, 1                  ; Number of 16-bit words
    call ip_verify_checksum
    pop rcx
    test eax, eax
    jnz .ip_done                ; Checksum failed

    ; Check destination IP (should be ours or broadcast)
    mov eax, [rsi + IP_OFF_DST]
    cmp eax, [our_ip]
    je .ip_for_us
    cmp eax, 0xFFFFFFFF         ; Broadcast
    je .ip_for_us
    ; Check subnet broadcast
    mov edx, [our_ip]
    or edx, [subnet_mask]
    xor edx, 0xFFFFFFFF         ; Invert mask
    or edx, [our_ip]
    cmp eax, edx
    jne .ip_done                ; Not for us

.ip_for_us:
    ; Get total length
    movzx edx, word [rsi + IP_OFF_TOTLEN]
    xchg dl, dh                 ; Big-endian to little-endian

    ; Calculate payload offset and length
    mov rdi, rsi
    add rdi, rbx                ; RDI = payload start
    sub edx, ebx                ; EDX = payload length

    ; Get protocol
    movzx eax, byte [rsi + IP_OFF_PROTO]

    ; Save source IP for replies
    mov r8d, [rsi + IP_OFF_SRC]
    mov [ip_last_src], r8d

    ; Dispatch based on protocol
    cmp al, IP_PROTO_ICMP
    je .handle_icmp
    cmp al, IP_PROTO_UDP
    je .handle_udp
    cmp al, IP_PROTO_TCP
    je .handle_tcp

    ; Unknown protocol
    inc dword [ip_unknown_proto]
    jmp .ip_done

.handle_icmp:
    push rsi
    mov rsi, rdi                ; RSI = ICMP packet
    mov ecx, edx                ; ECX = ICMP length
    call icmp_handle_packet
    pop rsi
    inc dword [ip_icmp_count]
    jmp .ip_done

.handle_udp:
    push rsi
    mov rsi, rdi
    mov ecx, edx
    call udp_handle_packet
    pop rsi
    inc dword [ip_udp_count]
    jmp .ip_done

.handle_tcp:
    push rsi
    mov rsi, rdi
    mov ecx, edx
    call tcp_handle_packet
    pop rsi
    inc dword [ip_tcp_count]
    jmp .ip_done

.ip_done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; IP_SEND - Send IP packet
; Input: EDI = destination IP, AL = protocol, RSI = payload, ECX = payload length
; Output: CF set on error
; ════════════════════════════════════════════════════════════════════════════
ip_send:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11

    mov r10d, edi               ; Save dest IP
    mov r11b, al                ; Save protocol
    mov r8, rsi                 ; Save payload pointer
    mov r9d, ecx                ; Save payload length

    ; Determine MAC address for destination
    ; If same subnet, ARP directly; else use gateway
    mov eax, [our_ip]
    xor eax, r10d
    and eax, [subnet_mask]
    jz .same_subnet

    ; Different subnet - use gateway
    mov edi, [gateway_ip]
    jmp .resolve_mac

.same_subnet:
    mov edi, r10d

.resolve_mac:
    call arp_resolve
    test rax, rax
    jz .ip_send_error           ; ARP failed

    mov r12, rax                ; R12 = destination MAC pointer

    ; Build IP header in ip_packet_buffer
    mov rdi, ip_packet_buffer

    ; Version + IHL (0x45 = IPv4, 20 byte header)
    mov byte [rdi + IP_OFF_VER_IHL], 0x45

    ; TOS (0)
    mov byte [rdi + IP_OFF_TOS], 0

    ; Total length (header + payload) - big-endian
    mov eax, r9d
    add eax, 20                 ; Add header length
    xchg al, ah                 ; To big-endian
    mov [rdi + IP_OFF_TOTLEN], ax

    ; Identification
    mov ax, [ip_packet_id]
    inc word [ip_packet_id]
    xchg al, ah
    mov [rdi + IP_OFF_ID], ax

    ; Flags + Fragment offset (0x4000 = Don't Fragment)
    mov word [rdi + IP_OFF_FLAGS_FRAG], 0x0040

    ; TTL
    mov byte [rdi + IP_OFF_TTL], IP_DEFAULT_TTL

    ; Protocol
    mov [rdi + IP_OFF_PROTO], r11b

    ; Checksum (0 for now, calculate after)
    mov word [rdi + IP_OFF_CHECKSUM], 0

    ; Source IP
    mov eax, [our_ip]
    mov [rdi + IP_OFF_SRC], eax

    ; Destination IP
    mov [rdi + IP_OFF_DST], r10d

    ; Calculate IP header checksum
    push rcx
    mov rsi, rdi
    mov ecx, 10                 ; 10 words (20 bytes)
    call ip_calculate_checksum
    mov [rdi + IP_OFF_CHECKSUM], ax
    pop rcx

    ; Copy payload after header
    push rdi
    add rdi, 20                 ; After IP header
    mov rsi, r8                 ; Payload source
    mov rcx, r9                 ; Payload length
    rep movsb
    pop rdi

    ; Send via Ethernet
    ; e1000_send_raw: RSI=src MAC, RDI=dst MAC, DX=EtherType, R8=payload, R9=len
    mov rsi, e1000_mac          ; Source MAC
    push rdi
    mov rdi, r12                ; Destination MAC
    mov dx, ETHERTYPE_IPV4      ; EtherType (0x0800)
    mov r8, ip_packet_buffer    ; IP packet
    mov r9d, r9d
    add r9d, 20                 ; Total length (header + payload)
    call e1000_send_raw
    pop rdi

    inc dword [ip_tx_count]
    clc
    jmp .ip_send_done

.ip_send_error:
    inc dword [ip_tx_failed]
    stc

.ip_send_done:
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; IP_SEND_REPLY - Send IP packet in response to received packet
; Input: AL = protocol, RSI = payload, ECX = payload length
; Uses ip_last_src as destination
; ════════════════════════════════════════════════════════════════════════════
ip_send_reply:
    push rdi
    mov edi, [ip_last_src]
    call ip_send
    pop rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; IP_CALCULATE_CHECKSUM - Calculate IP checksum
; Input: RSI = buffer, ECX = number of 16-bit words
; Output: AX = checksum
; ════════════════════════════════════════════════════════════════════════════
ip_calculate_checksum:
    push rbx
    push rcx
    push rsi

    xor eax, eax                ; Accumulator
    xor ebx, ebx

.checksum_loop:
    movzx ebx, word [rsi]
    add eax, ebx
    add rsi, 2
    dec ecx
    jnz .checksum_loop

    ; Fold 32-bit sum to 16-bit
    mov ebx, eax
    shr ebx, 16
    and eax, 0xFFFF
    add eax, ebx

    ; Fold again if needed
    mov ebx, eax
    shr ebx, 16
    add eax, ebx
    and eax, 0xFFFF

    ; One's complement
    not ax

    pop rsi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; IP_VERIFY_CHECKSUM - Verify IP checksum
; Input: RSI = buffer, ECX = number of 16-bit words
; Output: EAX = 0 if valid, non-zero if invalid
; ════════════════════════════════════════════════════════════════════════════
ip_verify_checksum:
    push rbx
    push rcx
    push rsi

    xor eax, eax
    xor ebx, ebx

.verify_loop:
    movzx ebx, word [rsi]
    add eax, ebx
    add rsi, 2
    dec ecx
    jnz .verify_loop

    ; Fold to 16-bit
    mov ebx, eax
    shr ebx, 16
    and eax, 0xFFFF
    add eax, ebx

    mov ebx, eax
    shr ebx, 16
    add eax, ebx
    and eax, 0xFFFF

    ; Should be 0xFFFF if valid
    cmp ax, 0xFFFF
    je .checksum_valid
    mov eax, 1
    jmp .verify_done

.checksum_valid:
    xor eax, eax

.verify_done:
    pop rsi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; Protocol handlers (redirect to implementations)
; ════════════════════════════════════════════════════════════════════════════
icmp_handle_packet:
    jmp icmp_handle_packet_impl     ; Implemented in icmp.asm

udp_handle_packet:
    jmp udp_handle_packet_impl      ; Implemented in udp.asm

tcp_handle_packet:
    jmp tcp_handle_packet_impl      ; Implemented in tcp.asm

; ════════════════════════════════════════════════════════════════════════════
; IP DATA
; ════════════════════════════════════════════════════════════════════════════
align 8

; IP packet buffer (max 1500 bytes)
ip_packet_buffer:   times 1520 db 0

; Packet ID counter
ip_packet_id:       dw 0

; Last received source IP (for replies)
ip_last_src:        dd 0

; Statistics
ip_rx_count:        dd 0
ip_tx_count:        dd 0
ip_tx_failed:       dd 0
ip_icmp_count:      dd 0
ip_udp_count:       dd 0
ip_tcp_count:       dd 0
ip_unknown_proto:   dd 0
