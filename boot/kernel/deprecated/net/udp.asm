; ════════════════════════════════════════════════════════════════════════════
; UDP.ASM - User Datagram Protocol
; Connectionless, unreliable transport layer
; ════════════════════════════════════════════════════════════════════════════
; UDP Header Structure (8 bytes):
;   +0:  Source Port      (2 bytes, big-endian)
;   +2:  Destination Port (2 bytes, big-endian)
;   +4:  Length           (2 bytes, header + data)
;   +6:  Checksum         (2 bytes, optional for IPv4)
; ════════════════════════════════════════════════════════════════════════════

; UDP Header offsets
UDP_OFF_SRC_PORT    equ 0
UDP_OFF_DST_PORT    equ 2
UDP_OFF_LENGTH      equ 4
UDP_OFF_CHECKSUM    equ 6
UDP_HEADER_SIZE     equ 8

; UDP Socket states
UDP_SOCK_FREE       equ 0
UDP_SOCK_BOUND      equ 1

; Maximum UDP sockets
MAX_UDP_SOCKETS     equ 8
UDP_SOCKET_SIZE     equ 32      ; Socket structure size

; Receive buffer
UDP_RX_BUFFER_SIZE  equ 1024

; ════════════════════════════════════════════════════════════════════════════
; UDP_HANDLE_PACKET - Process received UDP packet
; Input: RSI = pointer to UDP packet, ECX = length
; ════════════════════════════════════════════════════════════════════════════
udp_handle_packet_impl:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Verify minimum length (8 bytes header)
    cmp ecx, UDP_HEADER_SIZE
    jl .udp_done

    ; Get destination port (big-endian)
    movzx eax, word [rsi + UDP_OFF_DST_PORT]
    xchg al, ah                 ; To little-endian
    mov edx, eax                ; EDX = dest port

    ; Get source port
    movzx ebx, word [rsi + UDP_OFF_SRC_PORT]
    xchg bl, bh

    ; Find socket listening on this port
    push rcx
    push rsi
    mov edi, edx                ; Port to find
    call udp_find_socket
    pop rsi
    pop rcx

    test rax, rax
    jz .udp_no_socket           ; No socket bound

    ; RAX = socket pointer
    mov rdi, rax

    ; Store received data in socket buffer
    ; Skip UDP header
    add rsi, UDP_HEADER_SIZE
    sub ecx, UDP_HEADER_SIZE

    ; Store sender info
    mov eax, [ip_last_src]
    mov [rdi + 8], eax          ; Sender IP
    mov [rdi + 12], bx          ; Sender port

    ; Copy data to socket receive buffer
    push rdi
    mov rdi, [rdi + 16]         ; RX buffer pointer
    test rdi, rdi
    jz .no_buffer

    ; Store length
    mov [rdi], ecx
    add rdi, 4

    ; Copy data
    push rcx
    rep movsb
    pop rcx

    ; Mark data available
    pop rdi
    mov byte [rdi + 4], 1       ; data_available flag
    mov [rdi + 6], cx           ; data length
    jmp .udp_done

.no_buffer:
    pop rdi
    jmp .udp_done

.udp_no_socket:
    inc dword [udp_no_socket_count]

.udp_done:
    inc dword [udp_rx_count]
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; UDP_SOCKET_CREATE - Create a UDP socket
; Output: RAX = socket handle (or 0 on error)
; ════════════════════════════════════════════════════════════════════════════
udp_socket_create:
    push rbx
    push rcx
    push rdi

    ; Find free socket slot
    mov rbx, udp_sockets
    mov ecx, MAX_UDP_SOCKETS

.find_slot:
    cmp byte [rbx], UDP_SOCK_FREE
    je .found_slot
    add rbx, UDP_SOCKET_SIZE
    dec ecx
    jnz .find_slot

    ; No free slot
    xor eax, eax
    jmp .create_done

.found_slot:
    ; Initialize socket
    mov byte [rbx], UDP_SOCK_BOUND      ; State (will be set properly on bind)
    mov word [rbx + 2], 0               ; Local port
    mov byte [rbx + 4], 0               ; Data available flag
    mov word [rbx + 6], 0               ; Data length
    mov dword [rbx + 8], 0              ; Remote IP
    mov word [rbx + 12], 0              ; Remote port

    ; Allocate receive buffer (use static buffer for simplicity)
    ; Calculate buffer address based on socket index
    mov rax, rbx
    sub rax, udp_sockets
    mov rcx, UDP_SOCKET_SIZE
    xor edx, edx
    div rcx                             ; RAX = socket index

    imul rax, UDP_RX_BUFFER_SIZE
    add rax, udp_rx_buffers
    mov [rbx + 16], rax                 ; Store buffer pointer

    mov rax, rbx                        ; Return socket handle

.create_done:
    pop rdi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; UDP_SOCKET_BIND - Bind socket to local port
; Input: RDI = socket handle, ESI = port
; Output: EAX = 0 on success, -1 on error
; ════════════════════════════════════════════════════════════════════════════
udp_socket_bind:
    push rbx

    ; Validate socket
    test rdi, rdi
    jz .bind_error

    ; Check if port already in use
    push rdi
    mov edi, esi
    call udp_find_socket
    pop rdi
    test rax, rax
    jnz .bind_error             ; Port already bound

    ; Bind socket
    mov byte [rdi], UDP_SOCK_BOUND
    mov [rdi + 2], si           ; Local port

    xor eax, eax
    jmp .bind_done

.bind_error:
    mov eax, -1

.bind_done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; UDP_SOCKET_CLOSE - Close UDP socket
; Input: RDI = socket handle
; ════════════════════════════════════════════════════════════════════════════
udp_socket_close:
    test rdi, rdi
    jz .close_done

    mov byte [rdi], UDP_SOCK_FREE
    mov word [rdi + 2], 0

.close_done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; UDP_SEND - Send UDP datagram
; Input: RDI = socket, ESI = dest IP, EDX = dest port, R8 = data, R9 = length
; Output: EAX = bytes sent or -1 on error
; ════════════════════════════════════════════════════════════════════════════
udp_send:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11

    mov r10d, esi               ; Save dest IP
    mov r11d, edx               ; Save dest port

    ; Build UDP packet in udp_tx_buffer
    mov rbx, udp_tx_buffer

    ; Source port (from socket)
    movzx eax, word [rdi + 2]
    xchg al, ah                 ; To big-endian
    mov [rbx + UDP_OFF_SRC_PORT], ax

    ; Destination port
    mov eax, r11d
    xchg al, ah
    mov [rbx + UDP_OFF_DST_PORT], ax

    ; Length (header + data)
    mov eax, r9d
    add eax, UDP_HEADER_SIZE
    xchg al, ah
    mov [rbx + UDP_OFF_LENGTH], ax

    ; Checksum (0 = disabled for IPv4)
    mov word [rbx + UDP_OFF_CHECKSUM], 0

    ; Copy data after header
    lea rdi, [rbx + UDP_HEADER_SIZE]
    mov rsi, r8
    mov ecx, r9d
    rep movsb

    ; Send via IP
    mov edi, r10d               ; Dest IP
    mov al, IP_PROTO_UDP
    mov rsi, udp_tx_buffer
    mov ecx, r9d
    add ecx, UDP_HEADER_SIZE
    call ip_send

    jc .send_error

    mov eax, r9d                ; Return bytes sent
    inc dword [udp_tx_count]
    jmp .send_done

.send_error:
    mov eax, -1

.send_done:
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
; UDP_RECV - Receive UDP datagram (non-blocking)
; Input: RDI = socket, RSI = buffer, EDX = max length
; Output: EAX = bytes received (0 if none), ECX = sender IP, R8 = sender port
; ════════════════════════════════════════════════════════════════════════════
udp_recv:
    push rbx
    push rdi

    ; Check if data available
    cmp byte [rdi + 4], 0
    je .no_data

    ; Get data length
    movzx eax, word [rdi + 6]
    cmp eax, edx
    jle .copy_data
    mov eax, edx                ; Truncate to buffer size

.copy_data:
    push rax
    mov rbx, rdi                ; Save socket

    ; Get sender info
    mov ecx, [rbx + 8]          ; Sender IP
    movzx r8d, word [rbx + 12]  ; Sender port

    ; Copy data from receive buffer
    mov rdi, rsi                ; Destination
    mov rsi, [rbx + 16]         ; Source (RX buffer)
    add rsi, 4                  ; Skip length field
    mov edx, eax
    push rcx
    mov ecx, edx
    rep movsb
    pop rcx

    ; Clear data available flag
    mov byte [rbx + 4], 0

    pop rax
    jmp .recv_done

.no_data:
    xor eax, eax
    xor ecx, ecx
    xor r8d, r8d

.recv_done:
    pop rdi
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; UDP_FIND_SOCKET - Find socket bound to port
; Input: EDI = port
; Output: RAX = socket pointer or 0
; ════════════════════════════════════════════════════════════════════════════
udp_find_socket:
    push rbx
    push rcx

    mov rbx, udp_sockets
    mov ecx, MAX_UDP_SOCKETS

.search:
    cmp byte [rbx], UDP_SOCK_FREE
    je .next

    cmp [rbx + 2], di
    je .found

.next:
    add rbx, UDP_SOCKET_SIZE
    dec ecx
    jnz .search

    xor eax, eax
    jmp .find_done

.found:
    mov rax, rbx

.find_done:
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; UDP_SENDTO - Send UDP datagram (socket-less interface)
; Input: EDI = dest IP, ESI = src port, EDX = dest port, R8 = data, R9 = length
; Output: EAX = bytes sent or -1
; ════════════════════════════════════════════════════════════════════════════
udp_sendto:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11

    mov r10d, edi               ; Dest IP
    mov r11d, edx               ; Dest port

    ; Build UDP packet
    mov rbx, udp_tx_buffer

    ; Source port
    mov eax, esi
    xchg al, ah
    mov [rbx + UDP_OFF_SRC_PORT], ax

    ; Destination port
    mov eax, r11d
    xchg al, ah
    mov [rbx + UDP_OFF_DST_PORT], ax

    ; Length
    mov eax, r9d
    add eax, UDP_HEADER_SIZE
    xchg al, ah
    mov [rbx + UDP_OFF_LENGTH], ax

    ; Checksum (0)
    mov word [rbx + UDP_OFF_CHECKSUM], 0

    ; Copy data
    lea rdi, [rbx + UDP_HEADER_SIZE]
    mov rsi, r8
    mov ecx, r9d
    rep movsb

    ; Send via IP
    mov edi, r10d
    mov al, IP_PROTO_UDP
    mov rsi, udp_tx_buffer
    mov ecx, r9d
    add ecx, UDP_HEADER_SIZE
    call ip_send

    jc .sendto_error

    mov eax, r9d
    inc dword [udp_tx_count]
    jmp .sendto_done

.sendto_error:
    mov eax, -1

.sendto_done:
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
; UDP DATA
; ════════════════════════════════════════════════════════════════════════════
align 8

; UDP sockets table
; Structure per socket:
;   +0:  state (1 byte)
;   +2:  local_port (2 bytes)
;   +4:  data_available (1 byte)
;   +6:  data_length (2 bytes)
;   +8:  remote_ip (4 bytes)
;   +12: remote_port (2 bytes)
;   +16: rx_buffer_ptr (8 bytes)
;   +24: reserved (8 bytes)
udp_sockets:    times MAX_UDP_SOCKETS * UDP_SOCKET_SIZE db 0

; Transmit buffer
udp_tx_buffer:  times 1500 db 0

; Receive buffers (one per socket)
udp_rx_buffers: times MAX_UDP_SOCKETS * UDP_RX_BUFFER_SIZE db 0

; Statistics
udp_rx_count:       dd 0
udp_tx_count:       dd 0
udp_no_socket_count: dd 0
