; ════════════════════════════════════════════════════════════════════════════
; HEAP_TEST.ASM - Simple heap allocator test
; ════════════════════════════════════════════════════════════════════════════
; Draws colored pixels to show test results:
;   Green pixel = test passed
;   Red pixel = test failed
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; HEAP_RUN_TESTS - Run all heap tests
; Output: EAX = number of failed tests (0 = all passed)
; ════════════════════════════════════════════════════════════════════════════
heap_run_tests:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r12
    push r13
    push r14

    xor r12d, r12d                  ; r12 = tests passed
    xor r13d, r13d                  ; r13 = tests failed

    ; Get screen position for results (top-left area)
    mov r14, [screen_fb]
    add r14, 160                    ; Start at x=40 (40*4 bytes)

    ; ─────────────────────────────────────────────────────────────
    ; TEST 1: kmalloc(64) returns valid pointer
    ; ─────────────────────────────────────────────────────────────
    mov rdi, 64
    call kmalloc

    test rax, rax
    jz .test1_fail
    cmp rax, 0x400000               ; >= HEAP_START
    jb .test1_fail
    cmp rax, 0x1400000              ; < HEAP_END
    jae .test1_fail

    mov rbx, rax                    ; Save ptr for later
    mov dword [r14], 0x0000FF00     ; GREEN = pass
    inc r12d
    jmp .test1_done
.test1_fail:
    mov dword [r14], 0x00FF0000     ; RED = fail
    inc r13d
    xor rbx, rbx
.test1_done:
    add r14, 16                     ; Next pixel position

    ; ─────────────────────────────────────────────────────────────
    ; TEST 2: Can write to allocated memory
    ; ─────────────────────────────────────────────────────────────
    test rbx, rbx
    jz .test2_fail

    ; Write pattern
    mov byte [rbx], 0xAA
    mov byte [rbx + 1], 0xBB
    mov byte [rbx + 63], 0xCC

    ; Verify
    cmp byte [rbx], 0xAA
    jne .test2_fail
    cmp byte [rbx + 1], 0xBB
    jne .test2_fail
    cmp byte [rbx + 63], 0xCC
    jne .test2_fail

    mov dword [r14], 0x0000FF00     ; GREEN
    inc r12d
    jmp .test2_done
.test2_fail:
    mov dword [r14], 0x00FF0000     ; RED
    inc r13d
.test2_done:
    add r14, 16

    ; ─────────────────────────────────────────────────────────────
    ; TEST 3: kfree doesn't crash
    ; ─────────────────────────────────────────────────────────────
    test rbx, rbx
    jz .test3_skip
    mov rdi, rbx
    call kfree
.test3_skip:
    mov dword [r14], 0x0000FF00     ; GREEN (if we reach here, no crash)
    inc r12d
    add r14, 16

    ; ─────────────────────────────────────────────────────────────
    ; TEST 4: Second kmalloc works
    ; ─────────────────────────────────────────────────────────────
    mov rdi, 128
    call kmalloc

    test rax, rax
    jz .test4_fail
    cmp rax, 0x400000
    jb .test4_fail
    cmp rax, 0x1400000
    jae .test4_fail

    mov rbx, rax                    ; Save for cleanup
    mov dword [r14], 0x0000FF00     ; GREEN
    inc r12d
    jmp .test4_done
.test4_fail:
    mov dword [r14], 0x00FF0000     ; RED
    inc r13d
    xor rbx, rbx
.test4_done:
    add r14, 16

    ; ─────────────────────────────────────────────────────────────
    ; TEST 5: kfree(NULL) doesn't crash
    ; ─────────────────────────────────────────────────────────────
    xor rdi, rdi
    call kfree
    mov dword [r14], 0x0000FF00     ; GREEN
    inc r12d
    add r14, 16

    ; ─────────────────────────────────────────────────────────────
    ; Cleanup
    ; ─────────────────────────────────────────────────────────────
    test rbx, rbx
    jz .no_cleanup
    mov rdi, rbx
    call kfree
.no_cleanup:

    ; ─────────────────────────────────────────────────────────────
    ; Final indicator: White pixel if all passed, Yellow if some failed
    ; ─────────────────────────────────────────────────────────────
    add r14, 16
    test r13d, r13d
    jnz .some_failed
    mov dword [r14], 0x00FFFFFF     ; WHITE = all passed
    jmp .tests_done
.some_failed:
    mov dword [r14], 0x00FFFF00     ; YELLOW = some failed

.tests_done:
    mov eax, r13d                   ; Return failed count

    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret
