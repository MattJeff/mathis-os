; ============================================================================
; PRIORITY_CONST.ASM - Priority level constants
; ============================================================================
; Single responsibility: Define priority values
; ============================================================================

[BITS 64]

; Priority levels (lower number = higher priority)
PRIO_REALTIME   equ 0       ; System critical tasks
PRIO_HIGH       equ 64      ; Interactive/UI
PRIO_NORMAL     equ 128     ; Default user processes
PRIO_LOW        equ 192     ; Background tasks
PRIO_IDLE       equ 255     ; Only runs when nothing else ready
