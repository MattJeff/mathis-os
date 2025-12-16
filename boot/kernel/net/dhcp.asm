; ════════════════════════════════════════════════════════════════════════════
; DHCP.ASM - Dynamic Host Configuration Protocol Client
; Automatically obtains IP address, subnet mask, gateway, and DNS
; ════════════════════════════════════════════════════════════════════════════
; DHCP Process:
;   1. DISCOVER → Broadcast to find DHCP servers
;   2. OFFER    ← Server offers an IP address
;   3. REQUEST  → Client requests the offered IP
;   4. ACK      ← Server confirms the lease
; ════════════════════════════════════════════════════════════════════════════

; DHCP Ports
DHCP_SERVER_PORT    equ 67
DHCP_CLIENT_PORT    equ 68

; DHCP Message Types
DHCP_DISCOVER       equ 1
DHCP_OFFER          equ 2
DHCP_REQUEST        equ 3
DHCP_DECLINE        equ 4
DHCP_ACK            equ 5
DHCP_NAK            equ 6
DHCP_RELEASE        equ 7

; DHCP Options
DHCP_OPT_SUBNET     equ 1
DHCP_OPT_ROUTER     equ 3
DHCP_OPT_DNS        equ 6
DHCP_OPT_HOSTNAME   equ 12
DHCP_OPT_REQIP      equ 50
DHCP_OPT_LEASE      equ 51
DHCP_OPT_MSGTYPE    equ 53
DHCP_OPT_SERVER     equ 54
DHCP_OPT_PARAMLIST  equ 55
DHCP_OPT_END        equ 255

; DHCP Magic Cookie
DHCP_MAGIC_COOKIE   equ 0x63538263      ; 99.130.83.99 in little-endian

; DHCP Packet offsets
DHCP_OFF_OP         equ 0       ; 1 byte - op code
DHCP_OFF_HTYPE      equ 1       ; 1 byte - hardware type
DHCP_OFF_HLEN       equ 2       ; 1 byte - hardware address length
DHCP_OFF_HOPS       equ 3       ; 1 byte - hops
DHCP_OFF_XID        equ 4       ; 4 bytes - transaction ID
DHCP_OFF_SECS       equ 8       ; 2 bytes - seconds
DHCP_OFF_FLAGS      equ 10      ; 2 bytes - flags
DHCP_OFF_CIADDR     equ 12      ; 4 bytes - client IP
DHCP_OFF_YIADDR     equ 16      ; 4 bytes - your IP (offered)
DHCP_OFF_SIADDR     equ 20      ; 4 bytes - server IP
DHCP_OFF_GIADDR     equ 24      ; 4 bytes - gateway IP
DHCP_OFF_CHADDR     equ 28      ; 16 bytes - client hardware address
DHCP_OFF_SNAME      equ 44      ; 64 bytes - server name
DHCP_OFF_FILE       equ 108     ; 128 bytes - boot filename
DHCP_OFF_OPTIONS    equ 236     ; variable - options (after magic cookie)

DHCP_PACKET_SIZE    equ 576     ; Minimum DHCP packet size

; ════════════════════════════════════════════════════════════════════════════
; DHCP_INIT - Start DHCP client and obtain IP address
; Output: CF clear if success, set if failed
; ════════════════════════════════════════════════════════════════════════════
dhcp_init:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Generate transaction ID from tick count
    mov eax, [tick_count]
    mov [dhcp_xid], eax

    ; Clear offered values
    mov dword [dhcp_offered_ip], 0
    mov dword [dhcp_server_ip], 0
    mov dword [dhcp_subnet_mask], 0
    mov dword [dhcp_gateway], 0
    mov dword [dhcp_dns], 0

    ; Step 1: Send DHCP Discover
    call dhcp_send_discover
    jc .dhcp_failed

    ; Step 2: Wait for DHCP Offer
    mov ecx, 500                    ; 5 second timeout (10ms ticks)
    call dhcp_wait_offer
    jc .dhcp_failed

    ; Step 3: Send DHCP Request
    call dhcp_send_request
    jc .dhcp_failed

    ; Step 4: Wait for DHCP ACK
    mov ecx, 500
    call dhcp_wait_ack
    jc .dhcp_failed

    ; Apply configuration
    call dhcp_apply_config

    mov byte [dhcp_configured], 1
    clc
    jmp .dhcp_done

.dhcp_failed:
    mov byte [dhcp_configured], 0
    stc

.dhcp_done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DHCP_SEND_DISCOVER - Send DHCP Discover broadcast
; ════════════════════════════════════════════════════════════════════════════
dhcp_send_discover:
    push rax
    push rbx
    push rcx
    push rdi
    push rsi

    ; Build DHCP Discover packet
    mov rdi, dhcp_packet_buffer
    call dhcp_build_base_packet

    ; Set message type option: Discover
    mov rdi, dhcp_packet_buffer + DHCP_OFF_OPTIONS + 4  ; After magic cookie
    mov byte [rdi], DHCP_OPT_MSGTYPE
    mov byte [rdi + 1], 1           ; Length
    mov byte [rdi + 2], DHCP_DISCOVER
    add rdi, 3

    ; Parameter request list
    mov byte [rdi], DHCP_OPT_PARAMLIST
    mov byte [rdi + 1], 4           ; Length
    mov byte [rdi + 2], DHCP_OPT_SUBNET
    mov byte [rdi + 3], DHCP_OPT_ROUTER
    mov byte [rdi + 4], DHCP_OPT_DNS
    mov byte [rdi + 5], DHCP_OPT_LEASE
    add rdi, 6

    ; End option
    mov byte [rdi], DHCP_OPT_END

    ; Send via UDP broadcast
    ; Source IP: 0.0.0.0, Dest IP: 255.255.255.255
    mov edi, 0xFFFFFFFF             ; Broadcast IP
    mov esi, DHCP_CLIENT_PORT       ; Source port
    mov edx, DHCP_SERVER_PORT       ; Dest port
    mov r8, dhcp_packet_buffer
    mov r9d, DHCP_PACKET_SIZE
    call dhcp_send_udp_broadcast

    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    clc
    ret

; ════════════════════════════════════════════════════════════════════════════
; DHCP_SEND_REQUEST - Send DHCP Request for offered IP
; ════════════════════════════════════════════════════════════════════════════
dhcp_send_request:
    push rax
    push rbx
    push rcx
    push rdi
    push rsi

    ; Build DHCP Request packet
    mov rdi, dhcp_packet_buffer
    call dhcp_build_base_packet

    ; Set options
    mov rdi, dhcp_packet_buffer + DHCP_OFF_OPTIONS + 4

    ; Message type: Request
    mov byte [rdi], DHCP_OPT_MSGTYPE
    mov byte [rdi + 1], 1
    mov byte [rdi + 2], DHCP_REQUEST
    add rdi, 3

    ; Requested IP address
    mov byte [rdi], DHCP_OPT_REQIP
    mov byte [rdi + 1], 4
    mov eax, [dhcp_offered_ip]
    mov [rdi + 2], eax
    add rdi, 6

    ; Server identifier
    mov byte [rdi], DHCP_OPT_SERVER
    mov byte [rdi + 1], 4
    mov eax, [dhcp_server_ip]
    mov [rdi + 2], eax
    add rdi, 6

    ; Parameter request list
    mov byte [rdi], DHCP_OPT_PARAMLIST
    mov byte [rdi + 1], 4
    mov byte [rdi + 2], DHCP_OPT_SUBNET
    mov byte [rdi + 3], DHCP_OPT_ROUTER
    mov byte [rdi + 4], DHCP_OPT_DNS
    mov byte [rdi + 5], DHCP_OPT_LEASE
    add rdi, 6

    ; End
    mov byte [rdi], DHCP_OPT_END

    ; Send broadcast
    mov edi, 0xFFFFFFFF
    mov esi, DHCP_CLIENT_PORT
    mov edx, DHCP_SERVER_PORT
    mov r8, dhcp_packet_buffer
    mov r9d, DHCP_PACKET_SIZE
    call dhcp_send_udp_broadcast

    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    clc
    ret

; ════════════════════════════════════════════════════════════════════════════
; DHCP_BUILD_BASE_PACKET - Build base DHCP packet structure
; Input: RDI = buffer
; ════════════════════════════════════════════════════════════════════════════
dhcp_build_base_packet:
    push rax
    push rcx
    push rdi
    push rsi

    ; Clear buffer
    push rdi
    mov rcx, DHCP_PACKET_SIZE
    xor al, al
    rep stosb
    pop rdi

    ; OP = 1 (BOOTREQUEST)
    mov byte [rdi + DHCP_OFF_OP], 1

    ; HTYPE = 1 (Ethernet)
    mov byte [rdi + DHCP_OFF_HTYPE], 1

    ; HLEN = 6 (MAC address length)
    mov byte [rdi + DHCP_OFF_HLEN], 6

    ; HOPS = 0
    mov byte [rdi + DHCP_OFF_HOPS], 0

    ; XID (transaction ID)
    mov eax, [dhcp_xid]
    mov [rdi + DHCP_OFF_XID], eax

    ; SECS = 0
    mov word [rdi + DHCP_OFF_SECS], 0

    ; FLAGS = 0x8000 (broadcast)
    mov word [rdi + DHCP_OFF_FLAGS], 0x0080     ; Big-endian 0x8000

    ; CIADDR = 0.0.0.0 (no IP yet)
    mov dword [rdi + DHCP_OFF_CIADDR], 0

    ; CHADDR = our MAC address
    push rdi
    add rdi, DHCP_OFF_CHADDR
    mov rsi, e1000_mac
    mov ecx, 6
    rep movsb
    pop rdi

    ; Magic cookie at start of options
    mov dword [rdi + DHCP_OFF_OPTIONS], DHCP_MAGIC_COOKIE

    pop rsi
    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DHCP_WAIT_OFFER - Wait for DHCP Offer
; Input: ECX = timeout in ticks
; Output: CF set if timeout
; ════════════════════════════════════════════════════════════════════════════
dhcp_wait_offer:
    push rax
    push rbx
    push rdx
    push rdi
    push rsi

    mov ebx, ecx                    ; Save timeout

.wait_loop:
    ; Poll network
    call net_poll

    ; Check if we received a DHCP packet
    call dhcp_check_received
    test eax, eax
    jz .no_packet

    ; Parse and check if it's an Offer
    call dhcp_parse_response
    cmp al, DHCP_OFFER
    je .got_offer

.no_packet:
    ; Small delay
    push rcx
    mov ecx, 10000
.delay:
    pause
    dec ecx
    jnz .delay
    pop rcx

    dec ebx
    jnz .wait_loop

    ; Timeout
    stc
    jmp .wait_done

.got_offer:
    clc

.wait_done:
    pop rsi
    pop rdi
    pop rdx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DHCP_WAIT_ACK - Wait for DHCP ACK
; Input: ECX = timeout in ticks
; Output: CF set if timeout or NAK
; ════════════════════════════════════════════════════════════════════════════
dhcp_wait_ack:
    push rax
    push rbx
    push rdx
    push rdi
    push rsi

    mov ebx, ecx

.wait_loop:
    call net_poll

    call dhcp_check_received
    test eax, eax
    jz .no_packet

    call dhcp_parse_response
    cmp al, DHCP_ACK
    je .got_ack
    cmp al, DHCP_NAK
    je .got_nak

.no_packet:
    push rcx
    mov ecx, 10000
.delay:
    pause
    dec ecx
    jnz .delay
    pop rcx

    dec ebx
    jnz .wait_loop

    stc
    jmp .wait_done

.got_nak:
    stc
    jmp .wait_done

.got_ack:
    clc

.wait_done:
    pop rsi
    pop rdi
    pop rdx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DHCP_CHECK_RECEIVED - Check if DHCP packet received
; Output: EAX = 1 if packet available, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
dhcp_check_received:
    push rbx
    push rcx
    push rdi
    push rsi

    ; Check UDP socket for DHCP client port
    mov edi, DHCP_CLIENT_PORT
    call udp_find_socket
    test rax, rax
    jz .no_socket

    ; Check if data available
    cmp byte [rax + 4], 1           ; data_available flag
    jne .no_data

    ; Copy data to our buffer
    mov rdi, rax
    mov rsi, dhcp_rx_buffer
    mov edx, 576
    call udp_recv

    test eax, eax
    jz .no_data

    mov eax, 1
    jmp .check_done

.no_socket:
.no_data:
    xor eax, eax

.check_done:
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DHCP_PARSE_RESPONSE - Parse DHCP response packet
; Output: AL = message type (OFFER, ACK, NAK)
; ════════════════════════════════════════════════════════════════════════════
dhcp_parse_response:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    mov rsi, dhcp_rx_buffer

    ; Verify OP = 2 (BOOTREPLY)
    cmp byte [rsi + DHCP_OFF_OP], 2
    jne .invalid

    ; Verify XID matches
    mov eax, [rsi + DHCP_OFF_XID]
    cmp eax, [dhcp_xid]
    jne .invalid

    ; Verify magic cookie
    cmp dword [rsi + DHCP_OFF_OPTIONS], DHCP_MAGIC_COOKIE
    jne .invalid

    ; Get offered IP (YIADDR)
    mov eax, [rsi + DHCP_OFF_YIADDR]
    mov [dhcp_offered_ip], eax

    ; Get server IP (SIADDR)
    mov eax, [rsi + DHCP_OFF_SIADDR]
    mov [dhcp_server_ip], eax

    ; Parse options
    lea rdi, [rsi + DHCP_OFF_OPTIONS + 4]   ; Skip magic cookie
    mov ecx, 312                            ; Max options length

    xor eax, eax                            ; Message type

.parse_options:
    movzx edx, byte [rdi]                   ; Option code

    cmp dl, DHCP_OPT_END
    je .parse_done

    cmp dl, 0                               ; Padding
    je .skip_pad

    ; Get option length
    movzx ebx, byte [rdi + 1]

    ; Check option type
    cmp dl, DHCP_OPT_MSGTYPE
    je .opt_msgtype
    cmp dl, DHCP_OPT_SUBNET
    je .opt_subnet
    cmp dl, DHCP_OPT_ROUTER
    je .opt_router
    cmp dl, DHCP_OPT_DNS
    je .opt_dns
    cmp dl, DHCP_OPT_SERVER
    je .opt_server
    cmp dl, DHCP_OPT_LEASE
    je .opt_lease
    jmp .skip_option

.opt_msgtype:
    movzx eax, byte [rdi + 2]
    jmp .skip_option

.opt_subnet:
    mov edx, [rdi + 2]
    mov [dhcp_subnet_mask], edx
    jmp .skip_option

.opt_router:
    mov edx, [rdi + 2]
    mov [dhcp_gateway], edx
    jmp .skip_option

.opt_dns:
    mov edx, [rdi + 2]
    mov [dhcp_dns], edx
    jmp .skip_option

.opt_server:
    mov edx, [rdi + 2]
    mov [dhcp_server_ip], edx
    jmp .skip_option

.opt_lease:
    mov edx, [rdi + 2]
    bswap edx                               ; Convert to little-endian
    mov [dhcp_lease_time], edx
    jmp .skip_option

.skip_option:
    add rdi, 2
    add rdi, rbx
    sub ecx, ebx
    sub ecx, 2
    jg .parse_options
    jmp .parse_done

.skip_pad:
    inc rdi
    dec ecx
    jg .parse_options
    jmp .parse_done

.invalid:
    xor eax, eax

.parse_done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DHCP_APPLY_CONFIG - Apply DHCP configuration to network stack
; ════════════════════════════════════════════════════════════════════════════
dhcp_apply_config:
    push rax

    ; Set our IP
    mov eax, [dhcp_offered_ip]
    mov [our_ip], eax

    ; Set subnet mask
    mov eax, [dhcp_subnet_mask]
    test eax, eax
    jz .default_mask
    mov [subnet_mask], eax
    jmp .set_gateway

.default_mask:
    mov dword [subnet_mask], 0x00FFFFFF     ; 255.255.255.0

.set_gateway:
    ; Set gateway
    mov eax, [dhcp_gateway]
    test eax, eax
    jz .config_done
    mov [gateway_ip], eax

.config_done:
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DHCP_SEND_UDP_BROADCAST - Send UDP packet with source IP 0.0.0.0
; Input: EDI = dest IP, ESI = src port, EDX = dst port, R8 = data, R9 = len
; ════════════════════════════════════════════════════════════════════════════
dhcp_send_udp_broadcast:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11

    mov r10d, edi                   ; Dest IP
    mov r11d, esi                   ; Src port

    ; Build UDP header
    mov rbx, dhcp_udp_buffer

    ; Source port (big-endian)
    mov eax, r11d
    xchg al, ah
    mov [rbx], ax

    ; Dest port (big-endian)
    mov eax, edx
    xchg al, ah
    mov [rbx + 2], ax

    ; Length (header + data)
    mov eax, r9d
    add eax, 8                      ; UDP header size
    xchg al, ah
    mov [rbx + 4], ax

    ; Checksum (0 = disabled)
    mov word [rbx + 6], 0

    ; Copy data after header
    lea rdi, [rbx + 8]
    mov rsi, r8
    mov ecx, r9d
    rep movsb

    ; Now build IP header and send
    ; For broadcast, we need to send directly via Ethernet
    ; with destination MAC FF:FF:FF:FF:FF:FF

    ; Build IP header in dhcp_ip_buffer
    mov rdi, dhcp_ip_buffer

    ; Version + IHL
    mov byte [rdi], 0x45

    ; TOS
    mov byte [rdi + 1], 0

    ; Total length
    mov eax, r9d
    add eax, 8 + 20                 ; UDP + IP headers
    xchg al, ah
    mov [rdi + 2], ax

    ; ID
    mov ax, [ip_packet_id]
    inc word [ip_packet_id]
    xchg al, ah
    mov [rdi + 4], ax

    ; Flags + Fragment
    mov word [rdi + 6], 0x0040      ; Don't fragment

    ; TTL
    mov byte [rdi + 8], 64

    ; Protocol = UDP
    mov byte [rdi + 9], 17

    ; Checksum (0 for now)
    mov word [rdi + 10], 0

    ; Source IP = 0.0.0.0
    mov dword [rdi + 12], 0

    ; Dest IP
    mov [rdi + 16], r10d

    ; Calculate IP checksum
    push rdi
    mov rsi, rdi
    mov ecx, 10                     ; 10 words
    call ip_calculate_checksum
    pop rdi
    mov [rdi + 10], ax

    ; Copy UDP packet after IP header
    push rdi
    add rdi, 20
    mov rsi, dhcp_udp_buffer
    mov ecx, r9d
    add ecx, 8
    rep movsb
    pop rdi

    ; Total packet size
    mov r9d, r9d
    add r9d, 8 + 20                 ; UDP + IP

    ; Send via Ethernet to broadcast MAC
    mov rsi, e1000_mac              ; Source MAC
    mov rdi, broadcast_mac          ; Dest MAC (FF:FF:FF:FF:FF:FF)
    mov dx, 0x0800                  ; EtherType IPv4
    mov r8, dhcp_ip_buffer
    call e1000_send_raw

    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DHCP_SETUP_SOCKET - Create UDP socket for DHCP
; ════════════════════════════════════════════════════════════════════════════
dhcp_setup_socket:
    push rax
    push rdi
    push rsi

    ; Create UDP socket
    call udp_socket_create
    test rax, rax
    jz .setup_done

    mov rdi, rax
    mov [dhcp_socket], rdi

    ; Bind to port 68
    mov esi, DHCP_CLIENT_PORT
    call udp_socket_bind

.setup_done:
    pop rsi
    pop rdi
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DHCP_STATUS - Check if DHCP configured
; Output: AL = 1 if configured, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
dhcp_status:
    mov al, [dhcp_configured]
    ret

; ════════════════════════════════════════════════════════════════════════════
; DHCP_GET_DNS - Get DNS server IP
; Output: EAX = DNS IP
; ════════════════════════════════════════════════════════════════════════════
dhcp_get_dns:
    mov eax, [dhcp_dns]
    ret

; ════════════════════════════════════════════════════════════════════════════
; DHCP DATA
; ════════════════════════════════════════════════════════════════════════════
align 8

dhcp_configured:    db 0
                    times 3 db 0    ; padding

dhcp_xid:           dd 0
dhcp_offered_ip:    dd 0
dhcp_server_ip:     dd 0
dhcp_subnet_mask:   dd 0
dhcp_gateway:       dd 0
dhcp_dns:           dd 0
dhcp_lease_time:    dd 0

dhcp_socket:        dq 0

; Packet buffers
dhcp_packet_buffer: times 576 db 0
dhcp_rx_buffer:     times 576 db 0
dhcp_udp_buffer:    times 600 db 0
dhcp_ip_buffer:     times 620 db 0
