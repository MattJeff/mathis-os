; ════════════════════════════════════════════════════════════════════════════
; MATHIS NEURAL KERNEL - Cognitive Architecture
; Each module = Neuron with:
;   - Input synapses (message receivers)
;   - Processing core (decision making)
;   - Output axons (message senders)
; ════════════════════════════════════════════════════════════════════════════

[BITS 32]
[ORG 0x10000]

; ════════════════════════════════════════════════════════════════════════════
; NEURAL NETWORK STRUCTURES
; ════════════════════════════════════════════════════════════════════════════
struc Neuron
    .id:            resd 1      ; Unique neuron ID
    .type:          resb 1      ; 0=input, 1=hidden, 2=output
    .activation:    resb 1      ; Current activation level (0-255)
    .threshold:     resb 1      ; Firing threshold
    .connections:   resd 8      ; Pointers to connected neurons (max 8)
    .weights:       resb 8      ; Connection weights (-128 to 127)
    .memory:        resb 16     ; Short-term memory
    .callback:      resd 1      ; Function to execute when fired
endstruc

; ════════════════════════════════════════════════════════════════════════════
; COGNITIVE LAYERS
; ════════════════════════════════════════════════════════════════════════════
neural_kernel:
    ; === SENSORY LAYER (Input neurons) ===
    .keyboard_neuron:
        dd 0x1001               ; ID
        db 0                    ; Type: input
        db 0                    ; Activation
        db 50                   ; Threshold
        times 8 dd 0            ; Connections (to be linked)
        times 8 db 10           ; Weights
        times 16 db 0           ; Memory
        dd process_keystroke    ; Callback

    .timer_neuron:
        dd 0x1002
        db 0                    ; Input
        db 0
        db 30
        times 8 dd 0
        times 8 db 5
        times 16 db 0
        dd process_timer

    ; === COGNITIVE LAYER (Hidden neurons) ===
    .pattern_neuron:
        dd 0x2001
        db 1                    ; Hidden
        db 0
        db 80                   ; Higher threshold
        times 8 dd 0
        times 8 db 15
        times 16 db 0
        dd recognize_pattern

    .memory_neuron:
        dd 0x2002
        db 1
        db 0
        db 60
        times 8 dd 0
        times 8 db 20
        times 16 db 0
        dd store_memory

    ; === ACTION LAYER (Output neurons) ===
    .display_neuron:
        dd 0x3001
        db 2                    ; Output
        db 0
        db 100
        times 8 dd 0
        times 8 db 25
        times 16 db 0
        dd render_display

    .execute_neuron:
        dd 0x3002
        db 2
        db 0
        db 120
        times 8 dd 0
        times 8 db 30
        times 16 db 0
        dd execute_command

; ════════════════════════════════════════════════════════════════════════════
; SYNAPSE PROPAGATION ENGINE
; ════════════════════════════════════════════════════════════════════════════
propagate_signal:
    ; ESI = source neuron
    ; AL = signal strength
    push ebx
    push ecx
    push edx

    ; Apply activation to source
    add byte [esi + Neuron.activation], al
    
    ; Check if neuron fires
    mov bl, [esi + Neuron.activation]
    cmp bl, [esi + Neuron.threshold]
    jb .no_fire

    ; Neuron fires! Reset and propagate
    mov byte [esi + Neuron.activation], 0
    
    ; Store in short-term memory
    lea edi, [esi + Neuron.memory]
    mov ecx, 15
    lea esi, [edi + 1]
    rep movsb
    mov [edi + 15], bl      ; Latest activation

    ; Propagate to connected neurons
    mov ecx, 8
    lea ebx, [esi + Neuron.connections]
.propagate_loop:
    mov edi, [ebx]
    test edi, edi
    jz .skip_connection
    
    ; Apply weight
    movsx eax, byte [esi + Neuron.weights + ecx - 1]
    mul bl                  ; Weighted signal
    shr eax, 2              ; Scale down
    
    ; Recursive propagation
    push esi
    push ecx
    mov esi, edi
    call propagate_signal
    pop ecx
    pop esi
    
.skip_connection:
    add ebx, 4
    loop .propagate_loop

    ; Execute callback if exists
    mov eax, [esi + Neuron.callback]
    test eax, eax
    jz .no_fire
    call eax

.no_fire:
    pop edx
    pop ecx
    pop ebx
    ret

; ════════════════════════════════════════════════════════════════════════════
; LEARNING ENGINE (Hebbian plasticity)
; ════════════════════════════════════════════════════════════════════════════
adjust_weights:
    ; ESI = neuron
    ; AL = reward (-128 to 127)
    push ebx
    push ecx
    
    movsx ebx, al
    mov ecx, 8
    lea edi, [esi + Neuron.weights]
    
.adjust_loop:
    ; Hebbian rule: neurons that fire together wire together
    movsx eax, byte [edi]
    add eax, ebx
    
    ; Clamp to byte range
    cmp eax, 127
    jle .not_max
    mov eax, 127
.not_max:
    cmp eax, -128
    jge .not_min
    mov eax, -128
.not_min:
    stosb
    loop .adjust_loop
    
    pop ecx
    pop ebx
    ret

; ════════════════════════════════════════════════════════════════════════════
; CONSCIOUSNESS LOOP
; ════════════════════════════════════════════════════════════════════════════
consciousness_loop:
    ; Continuously evaluate network state
    push eax
    push esi
    
    ; Check all neurons for spontaneous firing
    mov esi, neural_kernel.keyboard_neuron
    call check_spontaneous
    
    mov esi, neural_kernel.pattern_neuron
    call check_spontaneous
    
    ; Dream state (random activations when idle)
    rdtsc                       ; Random from timestamp
    and eax, 0x7F
    cmp eax, 5
    jae .no_dream
    
    ; Random small activation
    mov esi, neural_kernel.memory_neuron
    mov al, 10
    call propagate_signal
    
.no_dream:
    pop esi
    pop eax
    ret

check_spontaneous:
    ; Check for memory-based spontaneous firing
    movzx eax, byte [esi + Neuron.memory + 15]
    shr eax, 2                  ; Decay
    jz .no_spontaneous
    call propagate_signal
.no_spontaneous:
    ret

; ════════════════════════════════════════════════════════════════════════════
; INITIALIZE NEURAL CONNECTIONS
; ════════════════════════════════════════════════════════════════════════════
init_neural_network:
    ; Connect keyboard → pattern recognizer
    mov dword [neural_kernel.keyboard_neuron + Neuron.connections], neural_kernel.pattern_neuron
    
    ; Connect pattern → memory
    mov dword [neural_kernel.pattern_neuron + Neuron.connections], neural_kernel.memory_neuron
    
    ; Connect memory → display
    mov dword [neural_kernel.memory_neuron + Neuron.connections], neural_kernel.display_neuron
    
    ; Connect pattern → execute
    mov dword [neural_kernel.pattern_neuron + Neuron.connections + 4], neural_kernel.execute_neuron
    
    ret

; ════════════════════════════════════════════════════════════════════════════
; NEURON CALLBACKS
; ════════════════════════════════════════════════════════════════════════════
process_keystroke:
    ; Keyboard input triggers pattern recognition
    mov al, [last_scancode]
    mov esi, neural_kernel.pattern_neuron
    call propagate_signal
    ret

process_timer:
    ; Timer triggers consciousness check
    call consciousness_loop
    ret

recognize_pattern:
    ; Pattern detected - store and maybe execute
    mov esi, neural_kernel.memory_neuron
    mov al, 50
    call propagate_signal
    
    ; Check if executable pattern
    cmp byte [pattern_type], 1
    jne .not_executable
    mov esi, neural_kernel.execute_neuron
    mov al, 100
    call propagate_signal
.not_executable:
    ret

store_memory:
    ; Store pattern in long-term memory
    ; (Implementation depends on memory model)
    ret

render_display:
    ; Visual cortex - render to screen
    mov esi, thought_buffer
    call display_thought
    ret

execute_command:
    ; Motor cortex - execute action
    call vm_execute
    ret

; ════════════════════════════════════════════════════════════════════════════
; COGNITIVE STATE
; ════════════════════════════════════════════════════════════════════════════
last_scancode:      db 0
pattern_type:       db 0
thought_buffer:     times 256 db 0
attention_focus:    dd neural_kernel.keyboard_neuron   ; Current focus

; "The kernel doesn't just process - it THINKS."
