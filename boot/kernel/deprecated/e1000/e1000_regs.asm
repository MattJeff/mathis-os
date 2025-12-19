; ════════════════════════════════════════════════════════════════════════════
; E1000 NETWORK DRIVER - REGISTER DEFINITIONS
; Intel 82540EM Gigabit Ethernet Controller
; ════════════════════════════════════════════════════════════════════════════

; PCI Identification
E1000_VENDOR_ID     equ 0x8086      ; Intel
E1000_DEVICE_ID     equ 0x100E      ; 82540EM (QEMU default)

; ════════════════════════════════════════════════════════════════════════════
; CONTROL REGISTERS
; ════════════════════════════════════════════════════════════════════════════
E1000_CTRL          equ 0x0000      ; Device Control
E1000_STATUS        equ 0x0008      ; Device Status
E1000_EECD          equ 0x0010      ; EEPROM/Flash Control
E1000_EERD          equ 0x0014      ; EEPROM Read
E1000_CTRL_EXT      equ 0x0018      ; Extended Device Control
E1000_MDIC          equ 0x0020      ; MDI Control

; CTRL Register Bits
E1000_CTRL_FD       equ (1 << 0)    ; Full Duplex
E1000_CTRL_LRST     equ (1 << 3)    ; Link Reset
E1000_CTRL_ASDE     equ (1 << 5)    ; Auto-Speed Detection Enable
E1000_CTRL_SLU      equ (1 << 6)    ; Set Link Up
E1000_CTRL_ILOS     equ (1 << 7)    ; Invert Loss-of-Signal
E1000_CTRL_RST      equ (1 << 26)   ; Device Reset
E1000_CTRL_VME      equ (1 << 30)   ; VLAN Mode Enable
E1000_CTRL_PHY_RST  equ (1 << 31)   ; PHY Reset

; ════════════════════════════════════════════════════════════════════════════
; INTERRUPT REGISTERS
; ════════════════════════════════════════════════════════════════════════════
E1000_ICR           equ 0x00C0      ; Interrupt Cause Read
E1000_ITR           equ 0x00C4      ; Interrupt Throttling
E1000_ICS           equ 0x00C8      ; Interrupt Cause Set
E1000_IMS           equ 0x00D0      ; Interrupt Mask Set
E1000_IMC           equ 0x00D8      ; Interrupt Mask Clear

; Interrupt Bits
E1000_ICR_TXDW      equ (1 << 0)    ; TX Descriptor Written Back
E1000_ICR_TXQE      equ (1 << 1)    ; TX Queue Empty
E1000_ICR_LSC       equ (1 << 2)    ; Link Status Change
E1000_ICR_RXSEQ     equ (1 << 3)    ; RX Sequence Error
E1000_ICR_RXDMT0    equ (1 << 4)    ; RX Descriptor Minimum Threshold
E1000_ICR_RXO       equ (1 << 6)    ; RX Overrun
E1000_ICR_RXT0      equ (1 << 7)    ; RX Timer Interrupt

; ════════════════════════════════════════════════════════════════════════════
; RECEIVE REGISTERS
; ════════════════════════════════════════════════════════════════════════════
E1000_RCTL          equ 0x0100      ; RX Control
E1000_RDBAL         equ 0x2800      ; RX Descriptor Base Address Low
E1000_RDBAH         equ 0x2804      ; RX Descriptor Base Address High
E1000_RDLEN         equ 0x2808      ; RX Descriptor Length
E1000_RDH           equ 0x2810      ; RX Descriptor Head
E1000_RDT           equ 0x2818      ; RX Descriptor Tail
E1000_RDTR          equ 0x2820      ; RX Delay Timer
E1000_RXDCTL        equ 0x2828      ; RX Descriptor Control
E1000_RADV          equ 0x282C      ; RX Interrupt Absolute Delay
E1000_RSRPD         equ 0x2C00      ; RX Small Packet Detect

; RCTL Register Bits
E1000_RCTL_EN       equ (1 << 1)    ; Receiver Enable
E1000_RCTL_SBP      equ (1 << 2)    ; Store Bad Packets
E1000_RCTL_UPE      equ (1 << 3)    ; Unicast Promiscuous Enable
E1000_RCTL_MPE      equ (1 << 4)    ; Multicast Promiscuous Enable
E1000_RCTL_LPE      equ (1 << 5)    ; Long Packet Enable
E1000_RCTL_LBM_NONE equ (0 << 6)    ; No Loopback
E1000_RCTL_LBM_MAC  equ (1 << 6)    ; MAC Loopback
E1000_RCTL_RDMTS_HALF equ (0 << 8)  ; RX Desc Min Threshold 1/2
E1000_RCTL_RDMTS_QRTR equ (1 << 8)  ; RX Desc Min Threshold 1/4
E1000_RCTL_RDMTS_EIGTH equ (2 << 8) ; RX Desc Min Threshold 1/8
E1000_RCTL_BAM      equ (1 << 15)   ; Broadcast Accept Mode
E1000_RCTL_BSIZE_2048 equ (0 << 16) ; Buffer Size 2048
E1000_RCTL_BSIZE_1024 equ (1 << 16) ; Buffer Size 1024
E1000_RCTL_BSIZE_512  equ (2 << 16) ; Buffer Size 512
E1000_RCTL_BSIZE_256  equ (3 << 16) ; Buffer Size 256
E1000_RCTL_VFE      equ (1 << 18)   ; VLAN Filter Enable
E1000_RCTL_CFIEN    equ (1 << 19)   ; Canonical Form Indicator Enable
E1000_RCTL_CFI      equ (1 << 20)   ; Canonical Form Indicator
E1000_RCTL_DPF      equ (1 << 22)   ; Discard Pause Frames
E1000_RCTL_PMCF     equ (1 << 23)   ; Pass MAC Control Frames
E1000_RCTL_SECRC    equ (1 << 26)   ; Strip Ethernet CRC

; ════════════════════════════════════════════════════════════════════════════
; TRANSMIT REGISTERS
; ════════════════════════════════════════════════════════════════════════════
E1000_TCTL          equ 0x0400      ; TX Control
E1000_TIPG          equ 0x0410      ; TX Inter-Packet Gap
E1000_TDBAL         equ 0x3800      ; TX Descriptor Base Address Low
E1000_TDBAH         equ 0x3804      ; TX Descriptor Base Address High
E1000_TDLEN         equ 0x3808      ; TX Descriptor Length
E1000_TDH           equ 0x3810      ; TX Descriptor Head
E1000_TDT           equ 0x3818      ; TX Descriptor Tail
E1000_TIDV          equ 0x3820      ; TX Interrupt Delay Value
E1000_TXDCTL        equ 0x3828      ; TX Descriptor Control
E1000_TADV          equ 0x382C      ; TX Interrupt Absolute Delay
E1000_TSPMT         equ 0x3830      ; TCP Segmentation Pad & Min Threshold

; TCTL Register Bits
E1000_TCTL_EN       equ (1 << 1)    ; Transmitter Enable
E1000_TCTL_PSP      equ (1 << 3)    ; Pad Short Packets
E1000_TCTL_CT_SHIFT equ 4           ; Collision Threshold
E1000_TCTL_COLD_SHIFT equ 12        ; Collision Distance
E1000_TCTL_SWXOFF   equ (1 << 22)   ; Software XOFF
E1000_TCTL_RTLC     equ (1 << 24)   ; Re-transmit on Late Collision

; TIPG Recommended Values
E1000_TIPG_IPGT     equ 10          ; IPG Transmit Time
E1000_TIPG_IPGR1    equ 8           ; IPG Receive Time 1
E1000_TIPG_IPGR2    equ 6           ; IPG Receive Time 2

; ════════════════════════════════════════════════════════════════════════════
; MAC ADDRESS REGISTERS
; ════════════════════════════════════════════════════════════════════════════
E1000_RAL0          equ 0x5400      ; Receive Address Low
E1000_RAH0          equ 0x5404      ; Receive Address High
E1000_MTA           equ 0x5200      ; Multicast Table Array (128 entries)

; RAH Bits
E1000_RAH_AV        equ (1 << 31)   ; Address Valid

; ════════════════════════════════════════════════════════════════════════════
; STATISTICS REGISTERS (for debugging)
; ════════════════════════════════════════════════════════════════════════════
E1000_CRCERRS       equ 0x4000      ; CRC Error Count
E1000_ALGNERRC      equ 0x4004      ; Alignment Error Count
E1000_RXERRC        equ 0x400C      ; RX Error Count
E1000_MPC           equ 0x4010      ; Missed Packets Count
E1000_COLC          equ 0x4028      ; Collision Count
E1000_RNBC          equ 0x40A0      ; Receive No Buffers Count
E1000_TPR           equ 0x40D0      ; Total Packets RX
E1000_TPT           equ 0x40D4      ; Total Packets TX
E1000_GPRC          equ 0x4074      ; Good Packets RX Count
E1000_GPTC          equ 0x4080      ; Good Packets TX Count

; ════════════════════════════════════════════════════════════════════════════
; DESCRIPTOR STATUS BITS
; ════════════════════════════════════════════════════════════════════════════
; RX Descriptor Status
E1000_RXD_STAT_DD   equ (1 << 0)    ; Descriptor Done
E1000_RXD_STAT_EOP  equ (1 << 1)    ; End of Packet
E1000_RXD_STAT_IXSM equ (1 << 2)    ; Ignore Checksum
E1000_RXD_STAT_VP   equ (1 << 3)    ; VLAN Packet
E1000_RXD_STAT_TCPCS equ (1 << 5)   ; TCP Checksum
E1000_RXD_STAT_IPCS equ (1 << 6)    ; IP Checksum
E1000_RXD_STAT_PIF  equ (1 << 7)    ; Passed In-exact Filter

; TX Descriptor Command
E1000_TXD_CMD_EOP   equ (1 << 0)    ; End of Packet
E1000_TXD_CMD_IFCS  equ (1 << 1)    ; Insert FCS
E1000_TXD_CMD_IC    equ (1 << 2)    ; Insert Checksum
E1000_TXD_CMD_RS    equ (1 << 3)    ; Report Status
E1000_TXD_CMD_RPS   equ (1 << 4)    ; Report Packet Sent
E1000_TXD_CMD_DEXT  equ (1 << 5)    ; Extension
E1000_TXD_CMD_VLE   equ (1 << 6)    ; VLAN Packet Enable
E1000_TXD_CMD_IDE   equ (1 << 7)    ; Interrupt Delay Enable

; TX Descriptor Status
E1000_TXD_STAT_DD   equ (1 << 0)    ; Descriptor Done
E1000_TXD_STAT_EC   equ (1 << 1)    ; Excess Collisions
E1000_TXD_STAT_LC   equ (1 << 2)    ; Late Collision
E1000_TXD_STAT_TU   equ (1 << 3)    ; Transmit Underrun

; ════════════════════════════════════════════════════════════════════════════
; BUFFER SIZES
; ════════════════════════════════════════════════════════════════════════════
E1000_RX_DESC_COUNT equ 32          ; Number of RX descriptors
E1000_TX_DESC_COUNT equ 32          ; Number of TX descriptors
E1000_RX_BUFFER_SIZE equ 2048       ; RX buffer size per descriptor
E1000_TX_BUFFER_SIZE equ 2048       ; TX buffer size per descriptor

; Memory Layout (in kernel space)
E1000_RX_DESC_BASE  equ 0x40000     ; RX descriptor ring
E1000_TX_DESC_BASE  equ 0x41000     ; TX descriptor ring
E1000_RX_BUFFER_BASE equ 0x42000    ; RX packet buffers
E1000_TX_BUFFER_BASE equ 0x52000    ; TX packet buffers
