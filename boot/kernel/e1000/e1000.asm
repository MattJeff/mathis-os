; ════════════════════════════════════════════════════════════════════════════
; E1000 NETWORK DRIVER - MAIN MODULE
; Intel 82540EM Gigabit Ethernet Controller for QEMU
; ════════════════════════════════════════════════════════════════════════════
; Usage with QEMU:
;   qemu-system-x86_64 -drive file=mathis.img,format=raw \
;       -netdev user,id=net0,hostfwd=udp::5555-:5555 \
;       -device e1000,netdev=net0 -m 256M
; ════════════════════════════════════════════════════════════════════════════

; Include all E1000 modules
%include "e1000/e1000_init.asm"
%include "e1000/e1000_rx.asm"
%include "e1000/e1000_tx.asm"

; Include network protocol stack
%include "net/arp.asm"
%include "net/ip.asm"
%include "net/icmp.asm"
%include "net/udp.asm"
%include "net/tcp.asm"

; ════════════════════════════════════════════════════════════════════════════
; HIGH-LEVEL API
; ════════════════════════════════════════════════════════════════════════════

; ────────────────────────────────────────────────────────────────────────────
; NET_INIT - Initialize network stack
; Output: CF set if no network card found
; ────────────────────────────────────────────────────────────────────────────
net_init:
    call e1000_init
    jc .net_init_done           ; Skip ARP init if no E1000 found

    ; Initialize ARP
    call arp_init

.net_init_done:
    ret

; ────────────────────────────────────────────────────────────────────────────
; NET_SEND - Send an ethernet frame
; Input: RSI = source MAC, RDI = dest MAC, DX = EtherType
;        R8 = payload, R9 = payload length
; ────────────────────────────────────────────────────────────────────────────
net_send:
    call e1000_send_raw
    ret

; ────────────────────────────────────────────────────────────────────────────
; NET_RECV - Poll for received packet
; Output: RAX = length (0 if none), RDI = buffer
; ────────────────────────────────────────────────────────────────────────────
net_recv:
    call e1000_rx_poll
    ret

; ────────────────────────────────────────────────────────────────────────────
; NET_GET_MAC - Get our MAC address
; Input: RDI = buffer (6 bytes)
; ────────────────────────────────────────────────────────────────────────────
net_get_mac:
    call e1000_get_mac
    ret

; ────────────────────────────────────────────────────────────────────────────
; NET_STATUS - Check if network is available
; Output: AL = 1 if network available, 0 otherwise
; ────────────────────────────────────────────────────────────────────────────
net_status:
    mov al, [e1000_found]
    ret

; ────────────────────────────────────────────────────────────────────────────
; NET_GET_STATS - Get network statistics
; Input: RDI = stats buffer (16 bytes: rx_total, rx_dropped, tx_total, tx_dropped)
; ────────────────────────────────────────────────────────────────────────────
net_get_stats:
    push rax
    mov eax, [rx_total]
    mov [rdi], eax
    mov eax, [rx_dropped]
    mov [rdi + 4], eax
    mov eax, [tx_total]
    mov [rdi + 8], eax
    mov eax, [tx_dropped]
    mov [rdi + 12], eax
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; BROADCAST MAC
; ════════════════════════════════════════════════════════════════════════════
broadcast_mac:  db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
