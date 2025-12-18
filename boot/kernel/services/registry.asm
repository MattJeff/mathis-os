; ════════════════════════════════════════════════════════════════════════════
; REGISTRY.ASM - Service Registry (Dependency Inversion)
; ════════════════════════════════════════════════════════════════════════════
; Central service locator - modules request services by ID, not direct calls.
; Enables: swappable implementations, testing, modularity
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; SERVICE IDS
; ════════════════════════════════════════════════════════════════════════════
SVC_VIDEO       equ 0       ; Video/drawing service
SVC_INPUT       equ 1       ; Keyboard/mouse service
SVC_ALLOC       equ 2       ; Memory allocator service
SVC_FS          equ 3       ; Filesystem service
SVC_NET         equ 4       ; Network service
SVC_TIMER       equ 5       ; Timer/scheduler service
SVC_MAX         equ 6

; ════════════════════════════════════════════════════════════════════════════
; ALLOC SERVICE V-TABLE OFFSETS
; ════════════════════════════════════════════════════════════════════════════
ALLOC_MALLOC    equ 0       ; malloc(size) -> ptr
ALLOC_FREE      equ 8       ; free(ptr)
ALLOC_REALLOC   equ 16      ; realloc(ptr, size) -> ptr
ALLOC_CALLOC    equ 24      ; calloc(count, size) -> ptr

; ════════════════════════════════════════════════════════════════════════════
; VIDEO SERVICE V-TABLE OFFSETS
; ════════════════════════════════════════════════════════════════════════════
VIDEO_CLEAR     equ 0       ; clear(color)
VIDEO_PIXEL     equ 8       ; pixel(x, y, color)
VIDEO_RECT      equ 16      ; rect(x, y, w, h, color)
VIDEO_FILL      equ 24      ; fill_rect(x, y, w, h, color)
VIDEO_TEXT      equ 32      ; text(x, y, str, color)
VIDEO_LINE      equ 40      ; line(x1, y1, x2, y2, color)

; ════════════════════════════════════════════════════════════════════════════
; INPUT SERVICE V-TABLE OFFSETS
; ════════════════════════════════════════════════════════════════════════════
INPUT_POLL      equ 0       ; poll() -> event_type
INPUT_KEY       equ 8       ; get_key() -> scancode
INPUT_MOUSE_X   equ 16      ; mouse_x() -> x
INPUT_MOUSE_Y   equ 24      ; mouse_y() -> y
INPUT_MOUSE_BTN equ 32      ; mouse_btn() -> buttons

; ════════════════════════════════════════════════════════════════════════════
; REGISTRY_INIT - Initialize service registry
; ════════════════════════════════════════════════════════════════════════════
registry_init:
    push rax
    push rcx
    push rdi

    ; Clear service table (RIP-relative)
    lea rdi, [rel service_table]
    mov rcx, SVC_MAX
    xor eax, eax
.clear_loop:
    mov [rdi], rax
    add rdi, 8
    dec rcx
    jnz .clear_loop

    ; Mark as initialized
    lea rax, [rel registry_initialized]
    mov byte [rax], 1

    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; REGISTER_SERVICE - Register a service vtable
; Input:  EDI = service ID (SVC_*)
;         RSI = pointer to vtable
; Output: EAX = 1 on success, 0 on failure
; ════════════════════════════════════════════════════════════════════════════
register_service:
    push rbx

    ; Validate ID
    cmp edi, SVC_MAX
    jae .fail

    ; Validate vtable pointer
    test rsi, rsi
    jz .fail

    ; Store in table
    mov eax, edi
    shl eax, 3                      ; * 8 (qword size)
    lea rbx, [rel service_table]
    mov [rbx + rax], rsi

    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; GET_SERVICE - Get a service vtable
; Input:  EDI = service ID (SVC_*)
; Output: RAX = pointer to vtable (or 0 if not registered)
; ════════════════════════════════════════════════════════════════════════════
get_service:
    ; Validate ID
    cmp edi, SVC_MAX
    jae .not_found

    ; Lookup in table
    mov eax, edi
    shl eax, 3                      ; * 8 (qword size)
    lea rcx, [rel service_table]
    mov rax, [rcx + rax]
    ret

.not_found:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; SERVICE_CALL - Helper to call a service method
; Input:  EDI = service ID
;         ESI = method offset in vtable
;         RDX, RCX, R8, R9 = method arguments
; Output: RAX = method return value
; Note: Clobbers RDI, RSI for the actual method call
; ════════════════════════════════════════════════════════════════════════════
service_call:
    push rbx
    push r12

    mov r12d, esi                   ; Save method offset

    ; Get service vtable
    call get_service
    test rax, rax
    jz .no_service

    ; Call method
    mov rbx, rax                    ; rbx = vtable
    mov rdi, rdx                    ; shift args: rdx->rdi
    mov rsi, rcx                    ; rcx->rsi
    mov rdx, r8                     ; r8->rdx
    mov rcx, r9                     ; r9->rcx
    call [rbx + r12]                ; call vtable[offset]

    jmp .done

.no_service:
    xor eax, eax

.done:
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA SECTION
; ════════════════════════════════════════════════════════════════════════════
align 8

registry_initialized:   db 0
align 8
service_table:          times SVC_MAX dq 0
