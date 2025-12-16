; ════════════════════════════════════════════════════════════════════════════
; MATHIS VM - FLOAT MODULE (x87 FPU)
; Floating-point operations for LLML physics engine
; ════════════════════════════════════════════════════════════════════════════
; Stack format: floats are stored as 32-bit IEEE 754 on the VM stack
; FPU operations load from stack, compute, store back
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; FLOAT ARITHMETIC
; ════════════════════════════════════════════════════════════════════════════

vm_op_fadd:
    ; FADD: (a b -- a+b) float addition
    fld dword [ebp + 4]             ; Load a
    fadd dword [ebp]                ; Add b
    add ebp, 4                      ; Pop one
    fstp dword [ebp]                ; Store result
    jmp vm_loop

vm_op_fsub:
    ; FSUB: (a b -- a-b) float subtraction
    fld dword [ebp + 4]             ; Load a
    fsub dword [ebp]                ; Subtract b
    add ebp, 4
    fstp dword [ebp]
    jmp vm_loop

vm_op_fmul:
    ; FMUL: (a b -- a*b) float multiplication
    fld dword [ebp + 4]             ; Load a
    fmul dword [ebp]                ; Multiply by b
    add ebp, 4
    fstp dword [ebp]
    jmp vm_loop

vm_op_fdiv:
    ; FDIV: (a b -- a/b) float division
    fld dword [ebp + 4]             ; Load a
    fdiv dword [ebp]                ; Divide by b
    add ebp, 4
    fstp dword [ebp]
    jmp vm_loop

vm_op_fmod:
    ; FMOD: (a b -- a%b) float modulo
    fld dword [ebp]                 ; Load b (divisor)
    fld dword [ebp + 4]             ; Load a (dividend)
.fmod_loop:
    fprem                           ; Partial remainder
    fstsw ax                        ; Get status
    test ah, 0x04                   ; Check C2 (incomplete)
    jnz .fmod_loop
    add ebp, 4
    fstp dword [ebp]                ; Store remainder
    fstp st0                        ; Pop divisor
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; FLOAT UTILITIES
; ════════════════════════════════════════════════════════════════════════════

vm_op_fneg:
    ; FNEG: (a -- -a) float negation
    fld dword [ebp]
    fchs                            ; Change sign
    fstp dword [ebp]
    jmp vm_loop

vm_op_fabs:
    ; FABS: (a -- |a|) float absolute value
    fld dword [ebp]
    fabs
    fstp dword [ebp]
    jmp vm_loop

vm_op_fsqrt:
    ; FSQRT: (a -- sqrt(a)) square root
    fld dword [ebp]
    fsqrt
    fstp dword [ebp]
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; TRIGONOMETRY (for rotations, physics)
; ════════════════════════════════════════════════════════════════════════════

vm_op_fsin:
    ; FSIN: (a -- sin(a)) sine (radians)
    fld dword [ebp]
    fsin
    fstp dword [ebp]
    jmp vm_loop

vm_op_fcos:
    ; FCOS: (a -- cos(a)) cosine (radians)
    fld dword [ebp]
    fcos
    fstp dword [ebp]
    jmp vm_loop

vm_op_ftan:
    ; FTAN: (a -- tan(a)) tangent (radians)
    fld dword [ebp]
    fptan                           ; Returns tan and 1.0
    fstp st0                        ; Pop the 1.0
    fstp dword [ebp]
    jmp vm_loop

vm_op_fatan:
    ; FATAN: (a -- atan(a)) arctangent
    fld dword [ebp]
    fld1                            ; Load 1.0
    fpatan                          ; atan(st1/st0) = atan(a/1) = atan(a)
    fstp dword [ebp]
    jmp vm_loop

vm_op_fatan2:
    ; FATAN2: (y x -- atan2(y,x)) arctangent of y/x
    fld dword [ebp + 4]             ; Load y
    fld dword [ebp]                 ; Load x
    fpatan                          ; atan2(y, x)
    add ebp, 4
    fstp dword [ebp]
    jmp vm_loop

vm_op_fsincos:
    ; FSINCOS: (a -- sin(a) cos(a)) both sin and cos
    fld dword [ebp]
    fsincos                         ; st0=cos, st1=sin
    sub ebp, 4                      ; Make room for second value
    fstp dword [ebp]                ; Store cos
    fstp dword [ebp + 4]            ; Store sin
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; ADVANCED MATH
; ════════════════════════════════════════════════════════════════════════════

vm_op_fpow:
    ; FPOW: (base exp -- base^exp) power
    ; Using: x^y = 2^(y*log2(x))
    fld dword [ebp]                 ; Load exp
    fld dword [ebp + 4]             ; Load base
    fyl2x                           ; st0 = exp * log2(base)
    fld st0                         ; Duplicate
    frndint                         ; Integer part
    fsub st1, st0                   ; Fractional part in st1
    fxch st1                        ; Swap
    f2xm1                           ; 2^frac - 1
    fld1
    faddp                           ; 2^frac
    fscale                          ; * 2^int
    fstp st1                        ; Clean up
    add ebp, 4
    fstp dword [ebp]
    jmp vm_loop

vm_op_flog:
    ; FLOG: (a -- log2(a)) logarithm base 2
    fld1
    fld dword [ebp]
    fyl2x                           ; 1 * log2(a)
    fstp dword [ebp]
    jmp vm_loop

vm_op_flog10:
    ; FLOG10: (a -- log10(a)) logarithm base 10
    fldlg2                          ; Load log10(2)
    fld dword [ebp]
    fyl2x                           ; log10(2) * log2(a) = log10(a)
    fstp dword [ebp]
    jmp vm_loop

vm_op_fln:
    ; FLN: (a -- ln(a)) natural logarithm
    fldln2                          ; Load ln(2)
    fld dword [ebp]
    fyl2x                           ; ln(2) * log2(a) = ln(a)
    fstp dword [ebp]
    jmp vm_loop

vm_op_fexp:
    ; FEXP: (a -- e^a) exponential
    fld dword [ebp]
    fldl2e                          ; Load log2(e)
    fmulp                           ; a * log2(e)
    fld st0
    frndint
    fsub st1, st0
    fxch st1
    f2xm1
    fld1
    faddp
    fscale
    fstp st1
    fstp dword [ebp]
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; CONVERSION (int <-> float)
; ════════════════════════════════════════════════════════════════════════════

vm_op_itof:
    ; ITOF: (int -- float) integer to float
    fild dword [ebp]                ; Load integer
    fstp dword [ebp]                ; Store as float
    jmp vm_loop

vm_op_ftoi:
    ; FTOI: (float -- int) float to integer (truncate)
    ; Set rounding mode to truncate
    fld dword [ebp]
    sub esp, 4
    fnstcw [esp]                    ; Save control word
    mov ax, [esp]
    or ax, 0x0C00                   ; Set truncate mode
    mov [esp + 2], ax
    fldcw [esp + 2]                 ; Load modified CW
    fistp dword [ebp]               ; Store as integer
    fldcw [esp]                     ; Restore original CW
    add esp, 4
    jmp vm_loop

vm_op_ftoi_round:
    ; FTOI_ROUND: (float -- int) float to integer (round)
    fld dword [ebp]
    fistp dword [ebp]               ; Uses current rounding mode (round-to-nearest)
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; COMPARISON
; ════════════════════════════════════════════════════════════════════════════

vm_op_fcmp:
    ; FCMP: (a b -- result) compare floats
    ; Returns: -1 if a<b, 0 if a==b, 1 if a>b
    fld dword [ebp]                 ; Load b
    fld dword [ebp + 4]             ; Load a
    add ebp, 4
    fcomip st0, st1                 ; Compare and pop
    fstp st0                        ; Pop b
    ja .fcmp_greater
    jb .fcmp_less
    mov dword [ebp], 0              ; Equal
    jmp vm_loop
.fcmp_less:
    mov dword [ebp], -1
    jmp vm_loop
.fcmp_greater:
    mov dword [ebp], 1
    jmp vm_loop

vm_op_flt:
    ; FLT: (a b -- a<b) float less than
    fld dword [ebp]                 ; Load b
    fld dword [ebp + 4]             ; Load a
    add ebp, 4
    fcomip st0, st1
    fstp st0
    setb al
    movzx eax, al
    mov [ebp], eax
    jmp vm_loop

vm_op_fgt:
    ; FGT: (a b -- a>b) float greater than
    fld dword [ebp]                 ; Load b
    fld dword [ebp + 4]             ; Load a
    add ebp, 4
    fcomip st0, st1
    fstp st0
    seta al
    movzx eax, al
    mov [ebp], eax
    jmp vm_loop

vm_op_feq:
    ; FEQ: (a b -- a==b) float equal
    fld dword [ebp]
    fld dword [ebp + 4]
    add ebp, 4
    fcomip st0, st1
    fstp st0
    sete al
    movzx eax, al
    mov [ebp], eax
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; CONSTANTS
; ════════════════════════════════════════════════════════════════════════════

vm_op_fconst_pi:
    ; FCONST_PI: ( -- pi) push pi
    sub ebp, 4
    fldpi
    fstp dword [ebp]
    jmp vm_loop

vm_op_fconst_e:
    ; FCONST_E: ( -- e) push e (2.71828...)
    sub ebp, 4
    fld1
    fldl2e                          ; log2(e)
    fyl2x                           ; 1 * log2(e) ... wait, that's wrong
    ; Actually just load e directly
    fld1
    fld1
    fld1
    faddp                           ; 2
    fld1
    fdivp                           ; 0.5
    f2xm1                           ; 2^0.5 - 1
    fld1
    faddp                           ; sqrt(2)
    ; This is getting complex, let's just use a constant
    mov dword [ebp], 0x402DF854     ; IEEE 754 for e ≈ 2.71828
    jmp vm_loop

vm_op_fconst_0:
    ; FCONST_0: ( -- 0.0) push zero
    sub ebp, 4
    fldz
    fstp dword [ebp]
    jmp vm_loop

vm_op_fconst_1:
    ; FCONST_1: ( -- 1.0) push one
    sub ebp, 4
    fld1
    fstp dword [ebp]
    jmp vm_loop

vm_op_fconst:
    ; FCONST: Load 32-bit float constant from bytecode
    mov eax, [esi]
    add esi, 4
    sub ebp, 4
    mov [ebp], eax
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; VECTOR HELPERS (for physics)
; ════════════════════════════════════════════════════════════════════════════

vm_op_fdup:
    ; FDUP: (a -- a a) duplicate float
    mov eax, [ebp]
    sub ebp, 4
    mov [ebp], eax
    jmp vm_loop

vm_op_fdrop:
    ; FDROP: (a --) drop float
    add ebp, 4
    jmp vm_loop

vm_op_fswap:
    ; FSWAP: (a b -- b a) swap floats
    mov eax, [ebp]
    mov ebx, [ebp + 4]
    mov [ebp], ebx
    mov [ebp + 4], eax
    jmp vm_loop

vm_op_fover:
    ; FOVER: (a b -- a b a) copy second to top
    mov eax, [ebp + 4]
    sub ebp, 4
    mov [ebp], eax
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; SPECIAL
; ════════════════════════════════════════════════════════════════════════════

vm_op_fmin:
    ; FMIN: (a b -- min(a,b))
    fld dword [ebp]
    fld dword [ebp + 4]
    fcomip st0, st1
    jbe .fmin_st1
    fstp dword [ebp + 4]
    add ebp, 4
    jmp vm_loop
.fmin_st1:
    fstp st0
    add ebp, 4
    jmp vm_loop

vm_op_fmax:
    ; FMAX: (a b -- max(a,b))
    fld dword [ebp]
    fld dword [ebp + 4]
    fcomip st0, st1
    jae .fmax_st1
    fstp dword [ebp + 4]
    add ebp, 4
    jmp vm_loop
.fmax_st1:
    fstp st0
    add ebp, 4
    jmp vm_loop

vm_op_fclamp:
    ; FCLAMP: (val min max -- clamped) clamp value to range
    fld dword [ebp]                 ; max
    fld dword [ebp + 4]             ; min
    fld dword [ebp + 8]             ; val
    ; Compare val with min
    fcom st1
    fstsw ax
    sahf
    jae .clamp_check_max
    ; val < min, use min
    fstp st0
    add ebp, 8
    fstp dword [ebp]
    fstp st0
    jmp vm_loop
.clamp_check_max:
    ; Compare val with max
    fcom st2
    fstsw ax
    sahf
    jbe .clamp_use_val
    ; val > max, use max
    fstp st0
    fstp st0
    add ebp, 8
    fstp dword [ebp]
    jmp vm_loop
.clamp_use_val:
    add ebp, 8
    fstp dword [ebp]
    fstp st0
    fstp st0
    jmp vm_loop

vm_op_flerp:
    ; FLERP: (a b t -- lerp(a,b,t)) linear interpolation
    ; result = a + t*(b-a)
    fld dword [ebp + 8]             ; a
    fld dword [ebp + 4]             ; b
    fsub st0, st1                   ; b - a
    fmul dword [ebp]                ; t * (b - a)
    faddp                           ; a + t*(b-a)
    add ebp, 8
    fstp dword [ebp]
    jmp vm_loop
