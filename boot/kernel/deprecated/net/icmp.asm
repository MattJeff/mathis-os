; ════════════════════════════════════════════════════════════════════════════
; ICMP.ASM - Internet Control Message Protocol
; Implements ping (echo request/reply)
; ════════════════════════════════════════════════════════════════════════════
; ICMP Header Structure (8+ bytes):
;   +0:  Type            (1 byte)
;   +1:  Code            (1 byte)
;   +2:  Checksum        (2 bytes)
;   +4:  Identifier      (2 bytes) - for echo
;   +6:  Sequence        (2 bytes) - for echo
;   +8:  Data            (variable)
; ════════════════════════════════════════════════════════════════════════════

; ICMP Types
ICMP_ECHO_REPLY         equ 0
ICMP_DEST_UNREACHABLE   equ 3
ICMP_ECHO_REQUEST       equ 8
ICMP_TIME_EXCEEDED      equ 11

; ICMP Codes for Destination Unreachable
ICMP_NET_UNREACHABLE    equ 0
ICMP_HOST_UNREACHABLE   equ 1
ICMP_PORT_UNREACHABLE   equ 3

; ════════════════════════════════════════════════════════════════════════════
; ICMP_HANDLE_PACKET - Process received ICMP packet
; Input: RSI = pointer to ICMP packet, ECX = length
; ════════════════════════════════════════════════════════════════════════════
icmp_handle_packet_impl:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Verify minimum length (8 bytes header)
    cmp ecx, 8
    jl .icmp_done

    ; Verify checksum
    push rcx
    mov edx, ecx
    add edx, 1
    shr edx, 1                  ; Number of 16-bit words
    push rsi
    call icmp_verify_checksum
    pop rsi
    pop rcx
    test eax, eax
    jnz .icmp_done              ; Bad checksum

    ; Get ICMP type
    movzx eax, byte [rsi]

    ; Dispatch based on type
    cmp al, ICMP_ECHO_REQUEST
    je .handle_echo_request
    cmp al, ICMP_ECHO_REPLY
    je .handle_echo_reply

    ; Unknown/unhandled type
    jmp .icmp_done

.handle_echo_request:
    ; Respond with echo reply
    call icmp_send_echo_reply
    inc dword [icmp_echo_requests]
    jmp .icmp_done

.handle_echo_reply:
    ; Mark that we received a reply
    mov byte [icmp_reply_received], 1
    ; Copy reply data for ping command
    mov eax, [rsi + 4]          ; Identifier + Sequence
    mov [icmp_last_reply_id], eax
    inc dword [icmp_echo_replies]
    jmp .icmp_done

.icmp_done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ICMP_SEND_ECHO_REPLY - Send echo reply
; Input: RSI = original echo request packet, ECX = length
; Uses ip_last_src as destination
; ════════════════════════════════════════════════════════════════════════════
icmp_send_echo_reply:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    mov r8d, ecx                ; Save length

    ; Build echo reply in icmp_packet_buffer
    mov rdi, icmp_packet_buffer

    ; Type = Echo Reply (0)
    mov byte [rdi], ICMP_ECHO_REPLY

    ; Code = 0
    mov byte [rdi + 1], 0

    ; Checksum = 0 (calculate later)
    mov word [rdi + 2], 0

    ; Copy Identifier and Sequence from request
    mov eax, [rsi + 4]
    mov [rdi + 4], eax

    ; Copy data from request (after 8-byte header)
    push rdi
    add rdi, 8
    add rsi, 8
    mov ecx, r8d
    sub ecx, 8                  ; Data length
    jle .no_data
    rep movsb
.no_data:
    pop rdi

    ; Calculate checksum
    push rdi
    mov rsi, rdi
    mov ecx, r8d
    add ecx, 1
    shr ecx, 1                  ; Number of words
    call icmp_calculate_checksum
    pop rdi
    mov [rdi + 2], ax

    ; Send via IP
    mov al, IP_PROTO_ICMP
    mov rsi, icmp_packet_buffer
    mov ecx, r8d
    call ip_send_reply

    inc dword [icmp_replies_sent]

    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ICMP_SEND_ECHO_REQUEST - Send ping request
; Input: EDI = destination IP
; Output: EAX = sequence number used
; ════════════════════════════════════════════════════════════════════════════
icmp_send_echo_request:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    mov r8d, edi                ; Save dest IP

    ; Build echo request in icmp_packet_buffer
    mov rdi, icmp_packet_buffer

    ; Type = Echo Request (8)
    mov byte [rdi], ICMP_ECHO_REQUEST

    ; Code = 0
    mov byte [rdi + 1], 0

    ; Checksum = 0 (calculate later)
    mov word [rdi + 2], 0

    ; Identifier (use our PID or constant)
    mov word [rdi + 4], 0x1234

    ; Sequence number
    mov ax, [icmp_sequence]
    inc word [icmp_sequence]
    mov [rdi + 6], ax
    push rax                    ; Save sequence for return

    ; Add some data (8 bytes: timestamp-like)
    mov rax, [tick_count]
    mov [rdi + 8], rax

    ; Calculate checksum
    push rdi
    mov rsi, rdi
    mov ecx, 8                  ; 16 bytes / 2 = 8 words
    call icmp_calculate_checksum
    pop rdi
    mov [rdi + 2], ax

    ; Clear reply flag
    mov byte [icmp_reply_received], 0

    ; Send via IP
    push rdi
    mov edi, r8d                ; Destination IP
    mov al, IP_PROTO_ICMP
    mov rsi, icmp_packet_buffer
    mov ecx, 16                 ; 8 header + 8 data
    call ip_send
    pop rdi

    inc dword [icmp_requests_sent]

    pop rax                     ; Return sequence number
    movzx eax, ax

    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; ICMP_PING - Send ping and wait for reply
; Input: EDI = destination IP
; Output: EAX = round-trip time in ticks (or -1 if timeout)
; ════════════════════════════════════════════════════════════════════════════
icmp_ping:
    push rbx
    push rcx
    push rdx
    push rdi

    mov ebx, edi                ; Save dest IP

    ; Record start time
    mov rdx, [tick_count]

    ; Send echo request
    mov edi, ebx
    call icmp_send_echo_request
    mov ecx, eax                ; Save sequence

    ; Wait for reply (3 second timeout)
    mov eax, 300                ; 300 ticks = 3 seconds

.ping_wait:
    push rax

    ; Poll network
    call net_poll

    ; Check if reply received
    cmp byte [icmp_reply_received], 1
    je .ping_got_reply

    ; Small delay
    push rcx
    mov rcx, 1000
.ping_delay:
    pause
    dec rcx
    jnz .ping_delay
    pop rcx

    pop rax
    dec eax
    jnz .ping_wait

    ; Timeout
    mov eax, -1
    jmp .ping_done

.ping_got_reply:
    pop rax                     ; Clean stack

    ; Calculate round-trip time
    mov rax, [tick_count]
    sub rax, rdx                ; Current - start

.ping_done:
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; ICMP_CALCULATE_CHECKSUM - Calculate ICMP checksum
; Input: RSI = buffer, ECX = number of 16-bit words
; Output: AX = checksum
; ════════════════════════════════════════════════════════════════════════════
icmp_calculate_checksum:
    push rbx
    push rcx
    push rsi

    xor eax, eax

.checksum_loop:
    movzx ebx, word [rsi]
    add eax, ebx
    add rsi, 2
    dec ecx
    jnz .checksum_loop

    ; Fold to 16-bit
    mov ebx, eax
    shr ebx, 16
    and eax, 0xFFFF
    add eax, ebx

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
; ICMP_VERIFY_CHECKSUM - Verify ICMP checksum
; Input: RSI = buffer, EDX = number of 16-bit words
; Output: EAX = 0 if valid
; ════════════════════════════════════════════════════════════════════════════
icmp_verify_checksum:
    push rbx
    push rcx
    push rsi

    xor eax, eax
    mov ecx, edx

.verify_loop:
    movzx ebx, word [rsi]
    add eax, ebx
    add rsi, 2
    dec ecx
    jnz .verify_loop

    ; Fold
    mov ebx, eax
    shr ebx, 16
    and eax, 0xFFFF
    add eax, ebx

    mov ebx, eax
    shr ebx, 16
    add eax, ebx
    and eax, 0xFFFF

    ; Should be 0xFFFF
    cmp ax, 0xFFFF
    je .verify_ok
    mov eax, 1
    jmp .verify_done

.verify_ok:
    xor eax, eax

.verify_done:
    pop rsi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; ICMP DATA
; ════════════════════════════════════════════════════════════════════════════
align 8

; ICMP packet buffer
icmp_packet_buffer: times 128 db 0

; Ping state
icmp_sequence:          dw 0
icmp_reply_received:    db 0
                        db 0    ; padding
icmp_last_reply_id:     dd 0

; Statistics
icmp_echo_requests:     dd 0
icmp_echo_replies:      dd 0
icmp_requests_sent:     dd 0
icmp_replies_sent:      dd 0
