; ════════════════════════════════════════════════════════════════════════════
; EVENT.ASM - Event System Core Definitions
; ════════════════════════════════════════════════════════════════════════════
; SOLID Phase 5: Clean event-driven architecture
;
; Design principles:
;   - Single Responsibility: Each event type has one purpose
;   - Open/Closed: New event types can be added without modifying existing code
;   - Interface Segregation: Minimal event structure, type-specific data
;
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; EVENT TYPES
; ════════════════════════════════════════════════════════════════════════════
; Each type has specific data layout in event.data field

EVT_NONE            equ 0       ; Empty/invalid event
EVT_KEY_DOWN        equ 1       ; Key pressed
EVT_KEY_UP          equ 2       ; Key released
EVT_MOUSE_MOVE      equ 3       ; Mouse moved
EVT_MOUSE_DOWN      equ 4       ; Mouse button pressed
EVT_MOUSE_UP        equ 5       ; Mouse button released
EVT_MOUSE_SCROLL    equ 6       ; Mouse wheel
EVT_TIMER           equ 7       ; Timer tick (not queued, direct)
EVT_FOCUS_IN        equ 8       ; Widget gained focus
EVT_FOCUS_OUT       equ 9       ; Widget lost focus
EVT_RESIZE          equ 10      ; Window/widget resized
EVT_CLOSE           equ 11      ; Close request
EVT_CUSTOM          equ 128     ; User-defined events start here

EVT_TYPE_MAX        equ 256     ; Maximum event type ID

; ════════════════════════════════════════════════════════════════════════════
; EVENT STRUCTURE (32 bytes - cache-line friendly)
; ════════════════════════════════════════════════════════════════════════════
; Offset  Size  Field       Description
; ──────────────────────────────────────────────────────────────────────────
;   0      4    type        Event type (EVT_*)
;   4      4    flags       Event flags (EVF_*)
;   8      8    timestamp   Tick count when event occurred
;  16     16    data        Type-specific event data
; ════════════════════════════════════════════════════════════════════════════

EVENT_SIZE          equ 32

; Event structure offsets
EVT_TYPE            equ 0
EVT_FLAGS           equ 4
EVT_TIMESTAMP       equ 8
EVT_DATA            equ 16

; Event flags
EVF_NONE            equ 0x00
EVF_HANDLED         equ 0x01    ; Event was handled, stop propagation
EVF_BUBBLES         equ 0x02    ; Event bubbles up to parent
EVF_CANCELABLE      equ 0x04    ; Event can be cancelled
EVF_SYNTHETIC       equ 0x08    ; Programmatically generated

; ════════════════════════════════════════════════════════════════════════════
; KEY EVENT DATA (16 bytes at EVT_DATA offset)
; ════════════════════════════════════════════════════════════════════════════
; For EVT_KEY_DOWN, EVT_KEY_UP

KEVT_SCANCODE       equ 0       ; +0: Scancode (1 byte)
KEVT_ASCII          equ 1       ; +1: ASCII char (1 byte, 0 if special)
KEVT_MODIFIERS      equ 2       ; +2: Modifier flags (1 byte)
KEVT_RESERVED       equ 3       ; +3: Reserved (1 byte)
KEVT_REPEAT         equ 4       ; +4: Repeat count (4 bytes)

; Key modifiers
KMOD_NONE           equ 0x00
KMOD_SHIFT          equ 0x01
KMOD_CTRL           equ 0x02
KMOD_ALT            equ 0x04
KMOD_CAPS           equ 0x08
KMOD_NUM            equ 0x10

; ════════════════════════════════════════════════════════════════════════════
; MOUSE EVENT DATA (16 bytes at EVT_DATA offset)
; ════════════════════════════════════════════════════════════════════════════
; For EVT_MOUSE_MOVE, EVT_MOUSE_DOWN, EVT_MOUSE_UP, EVT_MOUSE_SCROLL

MEVT_X              equ 0       ; +0: X position (2 bytes)
MEVT_Y              equ 2       ; +2: Y position (2 bytes)
MEVT_DELTA_X        equ 4       ; +4: X delta/movement (2 bytes, signed)
MEVT_DELTA_Y        equ 6       ; +6: Y delta/movement (2 bytes, signed)
MEVT_BUTTONS        equ 8       ; +8: Button state (1 byte)
MEVT_BUTTON         equ 9       ; +9: Button that triggered event (1 byte)
MEVT_CLICKS         equ 10      ; +10: Click count for double-click (1 byte)
MEVT_RESERVED       equ 11      ; +11: Reserved (1 byte)
MEVT_SCROLL         equ 12      ; +12: Scroll delta (4 bytes, signed)

; Mouse buttons
MBTN_NONE           equ 0x00
MBTN_LEFT           equ 0x01
MBTN_RIGHT          equ 0x02
MBTN_MIDDLE         equ 0x04

; ════════════════════════════════════════════════════════════════════════════
; EVENT HELPER MACROS / FUNCTIONS
; ════════════════════════════════════════════════════════════════════════════

; ────────────────────────────────────────────────────────────────────────────
; EVENT_INIT - Initialize an event structure
; Input:  RDI = event pointer, ESI = event type
; ────────────────────────────────────────────────────────────────────────────
event_init:
    push rax
    push rcx
    push rdi

    ; Clear entire event
    mov rcx, EVENT_SIZE / 8
    xor eax, eax
    rep stosq

    ; Restore RDI and set type
    pop rdi
    push rdi
    mov dword [rdi + EVT_TYPE], esi

    ; Set timestamp
    mov rax, [tick_count]
    mov [rdi + EVT_TIMESTAMP], rax

    pop rdi
    pop rcx
    pop rax
    ret

; ────────────────────────────────────────────────────────────────────────────
; EVENT_IS_KEY - Check if event is a key event
; Input:  RDI = event pointer
; Output: AL = 1 if key event, 0 otherwise
; ────────────────────────────────────────────────────────────────────────────
event_is_key:
    mov eax, [rdi + EVT_TYPE]
    cmp eax, EVT_KEY_DOWN
    je .yes
    cmp eax, EVT_KEY_UP
    je .yes
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

; ────────────────────────────────────────────────────────────────────────────
; EVENT_IS_MOUSE - Check if event is a mouse event
; Input:  RDI = event pointer
; Output: AL = 1 if mouse event, 0 otherwise
; ────────────────────────────────────────────────────────────────────────────
event_is_mouse:
    mov eax, [rdi + EVT_TYPE]
    cmp eax, EVT_MOUSE_MOVE
    je .yes
    cmp eax, EVT_MOUSE_DOWN
    je .yes
    cmp eax, EVT_MOUSE_UP
    je .yes
    cmp eax, EVT_MOUSE_SCROLL
    je .yes
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

; ────────────────────────────────────────────────────────────────────────────
; EVENT_MARK_HANDLED - Mark event as handled
; Input:  RDI = event pointer
; ────────────────────────────────────────────────────────────────────────────
event_mark_handled:
    or dword [rdi + EVT_FLAGS], EVF_HANDLED
    ret

; ────────────────────────────────────────────────────────────────────────────
; EVENT_IS_HANDLED - Check if event was handled
; Input:  RDI = event pointer
; Output: AL = 1 if handled, 0 otherwise
; ────────────────────────────────────────────────────────────────────────────
event_is_handled:
    mov eax, [rdi + EVT_FLAGS]
    and eax, EVF_HANDLED
    ret

; ────────────────────────────────────────────────────────────────────────────
; EVENT_GET_KEY_SCANCODE - Get scancode from key event
; Input:  RDI = event pointer
; Output: AL = scancode
; ────────────────────────────────────────────────────────────────────────────
event_get_key_scancode:
    movzx eax, byte [rdi + EVT_DATA + KEVT_SCANCODE]
    ret

; ────────────────────────────────────────────────────────────────────────────
; EVENT_GET_KEY_ASCII - Get ASCII char from key event
; Input:  RDI = event pointer
; Output: AL = ASCII char (0 if special key)
; ────────────────────────────────────────────────────────────────────────────
event_get_key_ascii:
    movzx eax, byte [rdi + EVT_DATA + KEVT_ASCII]
    ret

; ────────────────────────────────────────────────────────────────────────────
; EVENT_GET_MOUSE_POS - Get mouse position from mouse event
; Input:  RDI = event pointer
; Output: AX = X, DX = Y
; ────────────────────────────────────────────────────────────────────────────
event_get_mouse_pos:
    movzx eax, word [rdi + EVT_DATA + MEVT_X]
    movzx edx, word [rdi + EVT_DATA + MEVT_Y]
    ret

; ────────────────────────────────────────────────────────────────────────────
; EVENT_GET_MOUSE_BUTTON - Get button that triggered mouse event
; Input:  RDI = event pointer
; Output: AL = button (MBTN_*)
; ────────────────────────────────────────────────────────────────────────────
event_get_mouse_button:
    movzx eax, byte [rdi + EVT_DATA + MEVT_BUTTON]
    ret
