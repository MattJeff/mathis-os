; ════════════════════════════════════════════════════════════════════════════
; GO64.ASM - MATHIS OS 64-bit with Full GUI Desktop + MULTITASKING
; Features:
; - Timer IRQ0 (system tick + clock + SCHEDULER)
; - Keyboard IRQ1 (full input)
; - PS/2 Mouse IRQ12 (cursor + clicks)
; - GUI Desktop with icons
; - Window system (drag, close, minimize)
; - Terminal app, Files app, 3D Demo, Settings
; - Taskbar with Start menu and clock
; - PREEMPTIVE MULTITASKING with round-robin scheduler
; ════════════════════════════════════════════════════════════════════════════

; Screen constants
GFX_FB      equ 0xA0000
GFX_W       equ 320
GFX_H       equ 200
CENTER_X    equ 160
CENTER_Y    equ 100

; GUI Constants
TASKBAR_H   equ 14
TITLEBAR_H  equ 12
MAX_WINDOWS equ 4

; Colors (VGA 256 palette)
COL_DESKTOP     equ 1         ; Blue
COL_TASKBAR     equ 8         ; Dark gray
COL_TASKBAR_LT  equ 7         ; Light gray
COL_TITLEBAR    equ 9         ; Light blue
COL_TITLE_INACT equ 8         ; Gray
COL_WINDOW      equ 15        ; White
COL_BORDER      equ 0         ; Black
COL_TEXT        equ 0         ; Black
COL_TEXT_WHITE  equ 15        ; White
COL_CLOSE_BTN   equ 4         ; Red
COL_CURSOR      equ 15        ; White
COL_SHADOW      equ 0         ; Black
COL_SELECTED    equ 11        ; Light cyan
COL_GREEN       equ 10        ; Bright green
COL_YELLOW      equ 14        ; Yellow
COL_CYAN        equ 3         ; Cyan

; PS/2 Mouse ports
MOUSE_DATA   equ 0x60
MOUSE_CMD    equ 0x64
MOUSE_STATUS equ 0x64

do_go64:
    cli

    ; Setup page tables at 0x1000
    ; Clear 5 pages: PML4(0x1000), PDPT(0x2000), PD0(0x3000), PD3(0x4000), spare(0x5000)
    mov edi, 0x1000
    mov ecx, 5120               ; 5 pages * 1024 dwords
    xor eax, eax
    rep stosd

    ; Page table flags: P=Present, W=Write, U=User accessible, PS=Page Size (2MB)
    ; PML4[0] -> PDPT at 0x2000
    mov dword [0x1000], 0x2007      ; P+W+U

    ; PDPT[0] -> PD at 0x3000 (for 0-1GB)
    mov dword [0x2000], 0x3007      ; P+W+U

    ; PDPT[3] -> PD at 0x4000 (for 3-4GB, covers PCI MMIO)
    mov dword [0x2018], 0x4007      ; P+W+U (offset 0x18 = entry 3)

    ; PD0: Map first 32MB (heap needs 4-20MB)
    mov dword [0x3000], 0x00000087  ; 0-2MB
    mov dword [0x3008], 0x00200087  ; 2-4MB
    mov dword [0x3010], 0x00400087  ; 4-6MB
    mov dword [0x3018], 0x00600087  ; 6-8MB
    mov dword [0x3020], 0x00800087  ; 8-10MB
    mov dword [0x3028], 0x00A00087  ; 10-12MB
    mov dword [0x3030], 0x00C00087  ; 12-14MB
    mov dword [0x3038], 0x00E00087  ; 14-16MB
    mov dword [0x3040], 0x01000087  ; 16-18MB
    mov dword [0x3048], 0x01200087  ; 18-20MB
    mov dword [0x3050], 0x01400087  ; 20-22MB
    mov dword [0x3058], 0x01600087  ; 22-24MB
    mov dword [0x3060], 0x01800087  ; 24-26MB
    mov dword [0x3068], 0x01A00087  ; 26-28MB
    mov dword [0x3070], 0x01C00087  ; 28-30MB
    mov dword [0x3078], 0x01E00087  ; 30-32MB

    ; PD3: Map PCI MMIO region 0xFE000000-0xFFFFFFFF (top 32MB)
    ; PD index for 0xFE000000 = (0xFE000000 >> 21) & 0x1FF = 496
    ; We need entries 496-511 (16 entries * 2MB = 32MB)
    mov edi, 0x4000 + (496 * 8)     ; Start at PD entry 496
    mov eax, 0xFE000087             ; Base address 0xFE000000 + P+W+U+PS
    mov ecx, 16                     ; 16 entries
.map_mmio:
    mov [edi], eax
    mov dword [edi+4], 0            ; High 32 bits = 0
    add edi, 8
    add eax, 0x200000               ; Next 2MB page
    loop .map_mmio

    ; Enable PAE
    mov eax, cr4
    or eax, 0x20
    mov cr4, eax

    ; Load CR3
    mov eax, 0x1000
    mov cr3, eax

    ; Enable Long Mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x100
    wrmsr

    ; Load GDT
    lgdt [gdt64_ptr]

    ; Enable Paging
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    jmp 0x08:long_mode_entry

; ════════════════════════════════════════════════════════════════════════════
; 64-BIT LONG MODE
; ════════════════════════════════════════════════════════════════════════════
[BITS 64]
long_mode_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x90000

    ; Initialize variables
    mov qword [tick_count], 0
    mov byte [mode_flag], 2          ; Start in GUI mode
    mov word [mouse_x], 160          ; Center mouse
    mov word [mouse_y], 100
    mov byte [mouse_buttons], 0
    mov byte [mouse_cycle], 0
    mov byte [active_window], 0xFF   ; No window active
    mov byte [start_menu_open], 0
    mov byte [dragging], 0

    ; Clear windows
    mov rdi, windows
    mov rcx, MAX_WINDOWS * 32
    xor al, al
    rep stosb

    ; Clear command buffer
    mov rdi, cmd_buf
    mov rcx, 64
    xor al, al
    rep stosb
    mov byte [cmd_pos], 0

    ; Setup IDT with mouse support
    call setup_idt64

    ; Setup TSS for Ring 3 support
    call setup_tss64

    ; Setup PIC
    call setup_pic64

    ; Setup PIT (100Hz)
    call setup_pit64

    ; Initialize PS/2 Mouse
    call mouse_init

    ; Clear keyboard buffer
    in al, 0x60
    in al, 0x60

    ; Initialize scheduler (cooperative mode - processes tracked but not preempted)
    call scheduler_init

    ; Initialize network (E1000)
    call net_init

    ; Initialize USB (UHCI controller)
    call usb_init

    ; Initialize ACPI for power management
    call acpi_init

    ; Initialize heap allocator
    call heap_init

    ; Create demo processes (entries in table for ps command)
    ; These run in cooperative mode - main loop is the "idle" process
    mov rdi, demo_process_1
    mov rsi, str_proc_demo1
    call create_process

    mov rdi, demo_process_2
    mov rsi, str_proc_demo2
    call create_process

    ; Enable scheduler tracking (not preemption)
    call scheduler_enable

    ; Enable interrupts
    sti

; ════════════════════════════════════════════════════════════════════════════
; MAIN LOOP
; ════════════════════════════════════════════════════════════════════════════
main_loop:
    cmp byte [mode_flag], 2
    je gui_mode
    cmp byte [mode_flag], 1
    je shell_mode
    jmp graphics_mode

; ════════════════════════════════════════════════════════════════════════════
; GUI MODE - Desktop Environment
; ════════════════════════════════════════════════════════════════════════════
gui_mode:
    ; === Draw Desktop Background ===
    mov rdi, GFX_FB
    mov rcx, GFX_W * (GFX_H - TASKBAR_H)
    mov al, COL_DESKTOP
    rep stosb

    ; === Draw Desktop Icons ===
    ; Terminal icon (x=50, y=30)
    mov edi, 50
    mov esi, 30
    mov edx, COL_CYAN
    call draw_icon_terminal
    mov rdi, GFX_FB + GFX_W * 50 + 38
    mov rsi, str_terminal
    mov r8d, COL_TEXT_WHITE
    call draw_text

    ; Files icon (x=50, y=80)
    mov edi, 50
    mov esi, 80
    mov edx, COL_YELLOW
    call draw_icon_folder
    mov rdi, GFX_FB + GFX_W * 100 + 45
    mov rsi, str_files
    mov r8d, COL_TEXT_WHITE
    call draw_text

    ; 3D Demo icon (x=50, y=130)
    mov edi, 50
    mov esi, 130
    mov edx, COL_GREEN
    call draw_icon_cube
    mov rdi, GFX_FB + GFX_W * 150 + 38
    mov rsi, str_3ddemo
    mov r8d, COL_TEXT_WHITE
    call draw_text

    ; === Draw Open Windows ===
    call draw_windows

    ; === Draw Taskbar ===
    mov rdi, GFX_FB + GFX_W * (GFX_H - TASKBAR_H)
    mov rcx, GFX_W * TASKBAR_H
    mov al, COL_TASKBAR
    rep stosb

    ; Taskbar top highlight
    mov rdi, GFX_FB + GFX_W * (GFX_H - TASKBAR_H)
    mov rcx, GFX_W
    mov al, COL_TASKBAR_LT
    rep stosb

    ; Start button
    mov edi, 4
    mov esi, GFX_H - TASKBAR_H + 2
    mov edx, 40
    mov ecx, 10
    mov r8d, COL_TASKBAR_LT
    call fill_rect
    mov rdi, GFX_FB + GFX_W * (GFX_H - TASKBAR_H + 4) + 8
    mov rsi, str_start
    mov r8d, COL_TEXT
    call draw_text

    ; Process indicator (show process count)
    mov rdi, GFX_FB + GFX_W * (GFX_H - TASKBAR_H + 4) + 55
    call draw_proc_indicator

    ; Clock (right side)
    mov rdi, GFX_FB + GFX_W * (GFX_H - TASKBAR_H + 4) + 275
    call draw_clock

    ; === Draw Start Menu if open ===
    cmp byte [start_menu_open], 1
    jne .no_start_menu
    call draw_start_menu
.no_start_menu:

    ; === Draw Mouse Cursor ===
    call draw_mouse_cursor

    ; Small delay for stability
    mov rcx, 100000
.gui_delay:
    dec rcx
    jnz .gui_delay

    jmp main_loop

; ════════════════════════════════════════════════════════════════════════════
; DRAW WINDOWS
; ════════════════════════════════════════════════════════════════════════════
draw_windows:
    push rbx
    push r12
    push r13
    push r14
    push r15

    xor r12, r12                    ; Window index

.window_loop:
    cmp r12, MAX_WINDOWS
    jge .windows_done

    ; Get window pointer
    mov rax, r12
    shl rax, 5                      ; * 32 bytes per window
    lea rbx, [windows + rax]

    ; Check if window is open
    cmp byte [rbx], 0               ; flags byte
    je .next_window

    ; Get window coords
    movzx r13, word [rbx + 2]       ; x
    movzx r14, word [rbx + 4]       ; y
    movzx r15, word [rbx + 6]       ; width
    movzx rax, word [rbx + 8]       ; height

    ; Draw shadow
    push rax
    mov edi, r13d
    add edi, 3
    mov esi, r14d
    add esi, 3
    mov edx, r15d
    mov ecx, eax
    mov r8d, COL_SHADOW
    call fill_rect
    pop rax

    ; Draw window background
    mov edi, r13d
    mov esi, r14d
    mov edx, r15d
    mov ecx, eax
    mov r8d, COL_WINDOW
    call fill_rect

    ; Draw border
    mov edi, r13d
    mov esi, r14d
    mov edx, r15d
    mov ecx, eax
    mov r8d, COL_BORDER
    call draw_rect

    ; Draw titlebar
    mov edi, r13d
    inc edi
    mov esi, r14d
    inc esi
    mov edx, r15d
    sub edx, 2
    mov ecx, TITLEBAR_H
    ; Check if active
    cmp r12b, [active_window]
    jne .inactive_title
    mov r8d, COL_TITLEBAR
    jmp .draw_title
.inactive_title:
    mov r8d, COL_TITLE_INACT
.draw_title:
    call fill_rect

    ; Draw window title
    mov rax, r13
    add rax, 4
    mov rcx, r14
    add rcx, 3
    imul rcx, GFX_W
    add rax, rcx
    add rax, GFX_FB
    mov rdi, rax
    mov rsi, [rbx + 16]             ; title pointer
    mov r8d, COL_TEXT_WHITE
    call draw_text

    ; Draw close button (X)
    mov eax, r13d
    add eax, r15d
    sub eax, 12
    mov edi, eax
    mov esi, r14d
    add esi, 2
    mov edx, 10
    mov ecx, 10
    mov r8d, COL_CLOSE_BTN
    call fill_rect
    ; Draw X
    mov rax, r13
    add rax, r15
    sub rax, 9
    mov rcx, r14
    add rcx, 4
    imul rcx, GFX_W
    add rax, rcx
    add rax, GFX_FB
    mov rdi, rax
    mov rsi, str_x
    mov r8d, COL_TEXT_WHITE
    call draw_text

    ; Draw window content based on type
    movzx eax, byte [rbx + 1]       ; type
    cmp al, 1
    je .draw_terminal_content
    cmp al, 2
    je .draw_files_content
    cmp al, 3
    je .draw_3d_content
    jmp .next_window

.draw_terminal_content:
    call draw_terminal_window
    jmp .next_window

.draw_files_content:
    call draw_files_window
    jmp .next_window

.draw_3d_content:
    call draw_3d_window
    jmp .next_window

.next_window:
    inc r12
    jmp .window_loop

.windows_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW TERMINAL WINDOW CONTENT
; ════════════════════════════════════════════════════════════════════════════
draw_terminal_window:
    push rbx
    push r13
    push r14

    ; Get window position
    movzx r13, word [rbx + 2]       ; x
    movzx r14, word [rbx + 4]       ; y

    ; Draw terminal header
    mov rax, r14
    add rax, TITLEBAR_H + 4
    imul rax, GFX_W
    add rax, r13
    add rax, 6
    add rax, GFX_FB
    mov rdi, rax
    mov rsi, str_term_header
    mov r8d, COL_GREEN
    call draw_text

    ; Draw help text
    mov rax, r14
    add rax, TITLEBAR_H + 14
    imul rax, GFX_W
    add rax, r13
    add rax, 6
    add rax, GFX_FB
    mov rdi, rax
    mov rsi, str_term_help
    mov r8d, COL_TEXT
    call draw_text

    ; Draw prompt
    mov rax, r14
    add rax, TITLEBAR_H + 34
    imul rax, GFX_W
    add rax, r13
    add rax, 6
    add rax, GFX_FB
    mov rdi, rax
    mov rsi, str_prompt
    mov r8d, COL_YELLOW
    call draw_text

    ; Draw command buffer
    mov rax, r14
    add rax, TITLEBAR_H + 34
    imul rax, GFX_W
    add rax, r13
    add rax, 70
    add rax, GFX_FB
    mov rdi, rax
    mov rsi, cmd_buf
    mov r8d, COL_TEXT
    call draw_text

    ; Draw cursor (blinking)
    mov rax, [tick_count]
    test al, 0x10
    jz .no_cursor
    movzx rcx, byte [cmd_pos]
    shl rcx, 3                      ; * 8 pixels
    mov rax, r14
    add rax, TITLEBAR_H + 34
    imul rax, GFX_W
    add rax, r13
    add rax, 70
    add rax, rcx
    add rax, GFX_FB
    mov byte [rax], COL_TEXT
    mov byte [rax + 1], COL_TEXT
.no_cursor:

    ; Draw result if any
    cmp byte [show_result], 0
    je .no_result
    mov rax, r14
    add rax, TITLEBAR_H + 50
    imul rax, GFX_W
    add rax, r13
    add rax, 6
    add rax, GFX_FB
    mov rdi, rax
    mov rsi, result_buf
    mov r8d, COL_CYAN
    call draw_text
.no_result:

    pop r14
    pop r13
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW FILES WINDOW CONTENT
; ════════════════════════════════════════════════════════════════════════════
draw_files_window:
    push rbx
    push r13
    push r14

    movzx r13, word [rbx + 2]       ; x
    movzx r14, word [rbx + 4]       ; y

    ; Draw files list
    mov rax, r14
    add rax, TITLEBAR_H + 6
    imul rax, GFX_W
    add rax, r13
    add rax, 10
    add rax, GFX_FB
    mov rdi, rax
    mov rsi, str_file1
    mov r8d, COL_YELLOW
    call draw_text

    mov rax, r14
    add rax, TITLEBAR_H + 18
    imul rax, GFX_W
    add rax, r13
    add rax, 10
    add rax, GFX_FB
    mov rdi, rax
    mov rsi, str_file2
    mov r8d, COL_YELLOW
    call draw_text

    mov rax, r14
    add rax, TITLEBAR_H + 30
    imul rax, GFX_W
    add rax, r13
    add rax, 10
    add rax, GFX_FB
    mov rdi, rax
    mov rsi, str_file3
    mov r8d, COL_CYAN
    call draw_text

    pop r14
    pop r13
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW 3D WINDOW CONTENT (Mini rotating cube)
; ════════════════════════════════════════════════════════════════════════════
draw_3d_window:
    push rbx
    push r12
    push r13
    push r14
    push r15

    movzx r13, word [rbx + 2]       ; window x
    movzx r14, word [rbx + 4]       ; window y

    ; Mini cube center
    mov r15d, r13d
    add r15d, 60                    ; center x in window

    ; Get rotation angle from tick
    mov rax, [tick_count]
    shr rax, 2
    and rax, 0x3F
    movsx r8, byte [sin_table + rax]
    mov rbx, rax
    add rbx, 16
    and rbx, 0x3F
    movsx r9, byte [sin_table + rbx]

    ; Draw simple rotating square (2D projection)
    ; Point 1
    mov rax, -15
    imul rax, r9
    sar rax, 5
    add eax, r15d
    mov [temp_x1], eax
    mov rax, -15
    imul rax, r8
    sar rax, 5
    add eax, r14d
    add eax, TITLEBAR_H + 40
    mov [temp_y1], eax

    ; Point 2
    mov rax, 15
    imul rax, r9
    sar rax, 5
    add eax, r15d
    mov [temp_x2], eax
    mov rax, -15
    imul rax, r8
    neg rax
    sar rax, 5
    add eax, r14d
    add eax, TITLEBAR_H + 40
    mov [temp_y2], eax

    ; Point 3
    mov rax, 15
    imul rax, r9
    neg rax
    sar rax, 5
    add eax, r15d
    mov [temp_x3], eax
    mov rax, 15
    imul rax, r8
    sar rax, 5
    add eax, r14d
    add eax, TITLEBAR_H + 40
    mov [temp_y3], eax

    ; Point 4
    mov rax, -15
    imul rax, r9
    neg rax
    sar rax, 5
    add eax, r15d
    mov [temp_x4], eax
    mov rax, -15
    imul rax, r8
    neg rax
    sar rax, 5
    add eax, r14d
    add eax, TITLEBAR_H + 40
    mov [temp_y4], eax

    ; Draw lines
    mov r8d, COL_GREEN
    mov edi, [temp_x1]
    mov esi, [temp_y1]
    mov edx, [temp_x2]
    mov ecx, [temp_y2]
    call draw_line

    mov r8d, COL_GREEN
    mov edi, [temp_x2]
    mov esi, [temp_y2]
    mov edx, [temp_x3]
    mov ecx, [temp_y3]
    call draw_line

    mov r8d, COL_GREEN
    mov edi, [temp_x3]
    mov esi, [temp_y3]
    mov edx, [temp_x4]
    mov ecx, [temp_y4]
    call draw_line

    mov r8d, COL_GREEN
    mov edi, [temp_x4]
    mov esi, [temp_y4]
    mov edx, [temp_x1]
    mov ecx, [temp_y1]
    call draw_line

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW START MENU
; ════════════════════════════════════════════════════════════════════════════
draw_start_menu:
    ; Menu background
    mov edi, 4
    mov esi, GFX_H - TASKBAR_H - 70
    mov edx, 80
    mov ecx, 68
    mov r8d, COL_TASKBAR_LT
    call fill_rect

    ; Border
    mov edi, 4
    mov esi, GFX_H - TASKBAR_H - 70
    mov edx, 80
    mov ecx, 68
    mov r8d, COL_BORDER
    call draw_rect

    ; Menu items
    mov rdi, GFX_FB + GFX_W * (GFX_H - TASKBAR_H - 64) + 12
    mov rsi, str_menu_term
    mov r8d, COL_TEXT
    call draw_text

    mov rdi, GFX_FB + GFX_W * (GFX_H - TASKBAR_H - 50) + 12
    mov rsi, str_menu_files
    mov r8d, COL_TEXT
    call draw_text

    mov rdi, GFX_FB + GFX_W * (GFX_H - TASKBAR_H - 36) + 12
    mov rsi, str_menu_3d
    mov r8d, COL_TEXT
    call draw_text

    mov rdi, GFX_FB + GFX_W * (GFX_H - TASKBAR_H - 22) + 12
    mov rsi, str_menu_about
    mov r8d, COL_TEXT
    call draw_text

    mov rdi, GFX_FB + GFX_W * (GFX_H - TASKBAR_H - 8) + 12
    mov rsi, str_menu_reboot
    mov r8d, COL_CLOSE_BTN
    call draw_text

    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW PROCESS INDICATOR - Shows "Pn" where n = process count
; ════════════════════════════════════════════════════════════════════════════
draw_proc_indicator:
    push rax
    push rbx
    push rdi
    push rsi
    push r8

    ; Save screen position
    mov rbx, rdi

    ; Build string "Pn" in buffer
    mov byte [proc_ind_buf], 'P'

    ; Get process count
    call get_process_count
    add al, '0'
    mov [proc_ind_buf + 1], al
    mov byte [proc_ind_buf + 2], 0

    ; Draw using bitmap font
    mov rdi, rbx
    mov rsi, proc_ind_buf
    mov r8d, COL_TEXT
    call draw_text

    pop r8
    pop rsi
    pop rdi
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW CLOCK - Displays HH:MM using bitmap font
; ════════════════════════════════════════════════════════════════════════════
draw_clock:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8

    ; Save screen position
    mov r8, rdi

    ; Calculate time from ticks (100 ticks/sec)
    mov rax, [tick_count]
    xor rdx, rdx
    mov rbx, 100
    div rbx                         ; rax = seconds total

    xor rdx, rdx
    mov rbx, 60
    div rbx                         ; rax = minutes, rdx = seconds
    push rdx                        ; save seconds

    xor rdx, rdx
    mov rbx, 60
    div rbx                         ; rax = hours, rdx = minutes
    push rdx                        ; save minutes

    ; Hours (mod 24)
    xor rdx, rdx
    mov rbx, 24
    div rbx
    mov rax, rdx                    ; hours = hours % 24

    ; Build time string in clock_buf: "HH:MM"
    xor rdx, rdx
    mov rbx, 10
    div rbx
    add al, '0'
    mov [clock_buf], al             ; H tens
    add dl, '0'
    mov [clock_buf + 1], dl         ; H units

    mov byte [clock_buf + 2], ':'   ; :

    ; Minutes
    pop rax
    xor rdx, rdx
    mov rbx, 10
    div rbx
    add al, '0'
    mov [clock_buf + 3], al         ; M tens
    add dl, '0'
    mov [clock_buf + 4], dl         ; M units

    mov byte [clock_buf + 5], 0     ; Null terminator

    pop rdx                         ; discard seconds

    ; Draw using bitmap font
    mov rdi, r8
    mov rsi, clock_buf
    mov r8d, COL_TEXT
    call draw_text

    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW MOUSE CURSOR (Arrow shape)
; ════════════════════════════════════════════════════════════════════════════
draw_mouse_cursor:
    push rax
    push rbx
    push rcx
    push rdi

    movzx rax, word [mouse_y]
    imul rax, GFX_W
    movzx rbx, word [mouse_x]
    add rax, rbx
    add rax, GFX_FB
    mov rdi, rax

    ; Simple arrow cursor (8 pixels tall)
    mov byte [rdi], COL_CURSOR
    add rdi, GFX_W
    mov byte [rdi], COL_CURSOR
    mov byte [rdi + 1], COL_CURSOR
    add rdi, GFX_W
    mov byte [rdi], COL_CURSOR
    mov byte [rdi + 1], COL_BORDER
    mov byte [rdi + 2], COL_CURSOR
    add rdi, GFX_W
    mov byte [rdi], COL_CURSOR
    mov byte [rdi + 1], COL_BORDER
    mov byte [rdi + 2], COL_BORDER
    mov byte [rdi + 3], COL_CURSOR
    add rdi, GFX_W
    mov byte [rdi], COL_CURSOR
    mov byte [rdi + 1], COL_CURSOR
    mov byte [rdi + 2], COL_CURSOR
    mov byte [rdi + 3], COL_CURSOR
    mov byte [rdi + 4], COL_CURSOR
    add rdi, GFX_W
    mov byte [rdi], COL_CURSOR
    mov byte [rdi + 1], COL_CURSOR
    mov byte [rdi + 2], COL_BORDER
    mov byte [rdi + 3], COL_CURSOR
    add rdi, GFX_W
    mov byte [rdi], COL_CURSOR
    add rdi, GFX_W + 2
    mov byte [rdi], COL_CURSOR
    mov byte [rdi + 1], COL_CURSOR

    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW ICONS
; ════════════════════════════════════════════════════════════════════════════
draw_icon_terminal:
    ; Terminal icon: rectangle with lines
    push rax
    push rdi

    ; Background
    push rdx
    mov r8d, edx
    mov edx, 16
    mov ecx, 16
    call fill_rect
    pop rdx

    ; Border
    mov r8d, COL_BORDER
    mov edx, 16
    mov ecx, 16
    call draw_rect

    ; Lines inside (text simulation)
    mov rax, rsi
    add rax, 3
    imul rax, GFX_W
    add rax, rdi
    add rax, 3
    add rax, GFX_FB
    mov byte [rax], COL_TEXT_WHITE
    mov byte [rax + 1], COL_TEXT_WHITE
    mov byte [rax + 2], COL_TEXT_WHITE
    mov byte [rax + 3], COL_TEXT_WHITE
    mov byte [rax + 4], COL_TEXT_WHITE
    add rax, GFX_W * 3
    mov byte [rax], COL_TEXT_WHITE
    mov byte [rax + 1], COL_TEXT_WHITE
    mov byte [rax + 2], COL_TEXT_WHITE

    pop rdi
    pop rax
    ret

draw_icon_folder:
    ; Folder icon
    push rax
    push rbx
    push rdi
    push rsi

    ; Tab part
    mov r8d, edx
    push rdx
    mov edx, 8
    mov ecx, 4
    call fill_rect
    pop rdx

    ; Main folder body
    push rdi
    push rsi
    add esi, 4
    mov r8d, edx
    mov edx, 16
    mov ecx, 12
    call fill_rect
    pop rsi
    pop rdi

    ; Border
    mov r8d, COL_BORDER
    add esi, 4
    mov edx, 16
    mov ecx, 12
    call draw_rect

    pop rsi
    pop rdi
    pop rbx
    pop rax
    ret

draw_icon_cube:
    ; 3D cube icon
    push rax
    push rdi
    push rsi

    ; Draw simple cube shape
    mov r8d, edx
    mov edx, 12
    mov ecx, 12
    add edi, 2
    add esi, 4
    call fill_rect

    ; Border
    mov r8d, COL_BORDER
    mov edx, 12
    mov ecx, 12
    call draw_rect

    ; 3D effect lines
    sub edi, 2
    sub esi, 4
    mov r8d, COL_BORDER
    mov edx, edi
    add edx, 12
    mov ecx, esi
    call draw_line_h

    pop rsi
    pop rdi
    pop rax
    ret

draw_line_h:
    ; Simple horizontal line edi=x, esi=y, edx=x2, r8d=color
    push rax
    push rdi
    mov eax, esi
    imul eax, GFX_W
    add eax, edi
    add eax, GFX_FB
    mov rdi, rax
.loop_h:
    mov byte [rdi], r8b
    inc rdi
    inc edi
    cmp edi, edx
    jle .loop_h
    pop rdi
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILL RECT - edi=x, esi=y, edx=w, ecx=h, r8d=color
; ════════════════════════════════════════════════════════════════════════════
fill_rect:
    push rax
    push rbx
    push rcx
    push rdi
    push rsi

    mov eax, esi
    imul eax, GFX_W
    add eax, edi
    add eax, GFX_FB
    mov rdi, rax
    mov ebx, edx                    ; width

.fill_row:
    push rcx
    mov rcx, rbx
    mov al, r8b
    rep stosb
    add rdi, GFX_W
    sub rdi, rbx
    pop rcx
    dec ecx
    jnz .fill_row

    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW RECT (outline) - edi=x, esi=y, edx=w, ecx=h, r8d=color
; ════════════════════════════════════════════════════════════════════════════
draw_rect:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Top line
    mov eax, esi
    imul eax, GFX_W
    add eax, edi
    add eax, GFX_FB
    mov rbx, rax
    mov rdi, rbx
    push rcx
    mov rcx, rdx
    mov al, r8b
    rep stosb
    pop rcx

    ; Bottom line
    push rcx
    dec ecx
    mov eax, ecx
    imul eax, GFX_W
    add rbx, rax
    mov rdi, rbx
    mov rcx, rdx
    mov al, r8b
    rep stosb
    pop rcx
    sub rbx, rax

    ; Left & right lines
    push rcx
.vert_loop:
    mov byte [rbx], r8b
    mov rax, rbx
    add rax, rdx
    dec rax
    mov byte [rax], r8b
    add rbx, GFX_W
    dec ecx
    jnz .vert_loop
    pop rcx

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; GRAPHICS MODE - 3D Cube (fullscreen)
; ════════════════════════════════════════════════════════════════════════════
graphics_mode:
    ; Clear screen
    mov rdi, GFX_FB
    mov rcx, GFX_W * GFX_H / 8
    xor rax, rax
    rep stosq

    ; [Previous 3D cube code here - abbreviated for space]
    mov rdi, GFX_FB + 320 * 100 + 120
    mov rsi, str_3d_mode
    mov r8d, COL_GREEN
    call draw_text

    ; Draw help text
    mov rdi, GFX_FB + 320 * 190 + 10
    mov rsi, str_help_gfx
    mov r8d, 7
    call draw_text

    mov rcx, 1000000
.gfx_delay:
    dec rcx
    jnz .gfx_delay

    jmp main_loop

; ════════════════════════════════════════════════════════════════════════════
; SHELL MODE
; ════════════════════════════════════════════════════════════════════════════
shell_mode:
    ; Clear screen (dark blue)
    mov rdi, GFX_FB
    mov rcx, GFX_W * GFX_H
    mov al, COL_DESKTOP
    rep stosb

    ; Draw banner
    mov rdi, GFX_FB + 320 * 10 + 10
    mov rsi, str_banner
    mov r8d, COL_TEXT_WHITE
    call draw_text

    mov rdi, GFX_FB + 320 * 180 + 10
    mov rsi, str_help_shell
    mov r8d, 7
    call draw_text

    mov rcx, 500000
.shell_delay:
    dec rcx
    jnz .shell_delay

    jmp main_loop

; ════════════════════════════════════════════════════════════════════════════
; DRAW TEXT - rdi=screen pos, rsi=string, r8d=color
; Uses 8x8 bitmap font, draws on single horizontal line
; ════════════════════════════════════════════════════════════════════════════
draw_text:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r9
    push r10
    push r11

    mov r9, rdi                     ; r9 = current X position base

.text_loop:
    lodsb
    test al, al
    jz .text_done

    ; Get character bitmap pointer
    movzx rbx, al
    cmp bl, 32
    jl .skip_char
    cmp bl, 127
    jg .skip_char

    sub rbx, 32                     ; ASCII offset (space = 0)
    shl rbx, 3                      ; * 8 bytes per char
    lea r10, [font8x8 + rbx]

    ; Draw 8 rows of the character
    mov r11, r9                     ; r11 = current char position
    mov rcx, 8                      ; 8 rows
.draw_row:
    push rcx
    mov al, [r10]                   ; Get font row byte
    mov rdi, r11                    ; Set position for this row
    mov rcx, 8                      ; 8 pixels per row
.draw_pixel:
    test al, 0x80                   ; Check leftmost bit
    jz .no_pixel
    mov byte [rdi], r8b             ; Draw pixel
.no_pixel:
    shl al, 1                       ; Next bit
    inc rdi
    loop .draw_pixel

    inc r10                         ; Next font row
    add r11, GFX_W                  ; Next screen row
    pop rcx
    loop .draw_row

    add r9, 8                       ; Move to next char position (8 pixels wide)
    jmp .text_loop

.skip_char:
    add r9, 8
    jmp .text_loop

.text_done:
    pop r11
    pop r10
    pop r9
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW LINE - Bresenham: edi=x1, esi=y1, edx=x2, ecx=y2, r8d=color
; ════════════════════════════════════════════════════════════════════════════
draw_line:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    mov r9d, edx                    ; x2
    mov r10d, ecx                   ; y2
    mov r14d, r8d                   ; color

    ; dx = abs(x2 - x1)
    mov eax, r9d
    sub eax, edi
    mov r11d, eax
    test r11d, r11d
    jns .dx_pos
    neg r11d
.dx_pos:

    ; dy = -abs(y2 - y1)
    mov eax, r10d
    sub eax, esi
    mov r12d, eax
    test r12d, r12d
    jns .dy_pos
    neg r12d
.dy_pos:
    neg r12d

    ; sx = x1 < x2 ? 1 : -1
    mov r13d, 1
    cmp edi, r9d
    jl .sx_done
    neg r13d
.sx_done:

    ; sy = y1 < y2 ? 1 : -1
    mov r15d, 1
    cmp esi, r10d
    jl .sy_done
    neg r15d
.sy_done:

    ; err = dx + dy
    mov ebx, r11d
    add ebx, r12d

.line_loop:
    ; Bounds check
    cmp edi, 0
    jl .skip_pixel
    cmp edi, GFX_W
    jge .skip_pixel
    cmp esi, 0
    jl .skip_pixel
    cmp esi, GFX_H
    jge .skip_pixel

    ; Plot pixel
    mov eax, esi
    imul eax, GFX_W
    add eax, edi
    add eax, GFX_FB
    mov byte [eax], r14b

.skip_pixel:
    ; Check if done
    cmp edi, r9d
    jne .not_done
    cmp esi, r10d
    je .line_done
.not_done:

    ; e2 = 2 * err
    mov eax, ebx
    shl eax, 1

    ; if e2 >= dy
    cmp eax, r12d
    jl .skip_x
    add ebx, r12d
    add edi, r13d
.skip_x:

    ; if e2 <= dx
    cmp eax, r11d
    jg .skip_y
    add ebx, r11d
    add esi, r15d
.skip_y:

    jmp .line_loop

.line_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; MOUSE INIT - Initialize PS/2 Mouse (simplified)
; ════════════════════════════════════════════════════════════════════════════
mouse_init:
    push rax

    ; Enable auxiliary device (mouse port)
    call .wait_write
    mov al, 0xA8
    out 0x64, al

    ; Get compaq status byte
    call .wait_write
    mov al, 0x20
    out 0x64, al
    call .wait_read
    in al, 0x60
    or al, 2                        ; Enable IRQ12
    and al, 0xDF                    ; Enable mouse clock
    mov ah, al

    ; Set compaq status byte
    call .wait_write
    mov al, 0x60
    out 0x64, al
    call .wait_write
    mov al, ah
    out 0x60, al

    ; Send "set defaults" to mouse
    call .wait_write
    mov al, 0xD4
    out 0x64, al
    call .wait_write
    mov al, 0xF6                    ; Set defaults
    out 0x60, al
    call .wait_read
    in al, 0x60                     ; Read ACK

    ; Enable mouse data reporting
    call .wait_write
    mov al, 0xD4
    out 0x64, al
    call .wait_write
    mov al, 0xF4                    ; Enable
    out 0x60, al
    call .wait_read
    in al, 0x60                     ; Read ACK

    pop rax
    ret

.wait_write:
    in al, 0x64
    test al, 2
    jnz .wait_write
    ret

.wait_read:
    in al, 0x64
    test al, 1
    jz .wait_read
    ret

; ════════════════════════════════════════════════════════════════════════════
; SETUP IDT
; ════════════════════════════════════════════════════════════════════════════
setup_idt64:
    push rax
    push rdi
    push rcx

    ; Clear IDT
    mov rdi, idt64
    mov rcx, 512
    xor rax, rax
    rep stosq

    ; IRQ0 (timer) at 0x20
    mov rdi, idt64 + 0x20 * 16
    mov rax, timer_isr64
    call set_idt_entry

    ; IRQ1 (keyboard) at 0x21
    mov rdi, idt64 + 0x21 * 16
    mov rax, keyboard_isr64
    call set_idt_entry

    ; IRQ12 (mouse) at 0x2C
    mov rdi, idt64 + 0x2C * 16
    mov rax, mouse_isr64
    call set_idt_entry

    ; INT 0x80 (syscall) - Ring 3 callable
    mov rdi, idt64 + 0x80 * 16
    mov rax, syscall_isr64
    call set_idt_entry_user        ; DPL=3 so user can call it

    lidt [idt64_ptr]

    pop rcx
    pop rdi
    pop rax
    ret

set_idt_entry:
    ; Standard IDT entry (DPL=0, only kernel can call)
    mov word [rdi], ax
    mov word [rdi + 2], 0x08        ; Kernel code selector
    mov byte [rdi + 4], 0
    mov byte [rdi + 5], 0x8E        ; Present, DPL=0, Interrupt Gate
    shr rax, 16
    mov word [rdi + 6], ax
    shr rax, 16
    mov dword [rdi + 8], eax
    mov dword [rdi + 12], 0
    ret

set_idt_entry_user:
    ; IDT entry callable from Ring 3 (DPL=3)
    mov word [rdi], ax
    mov word [rdi + 2], 0x08        ; Kernel code selector
    mov byte [rdi + 4], 0
    mov byte [rdi + 5], 0xEE        ; Present, DPL=3, Interrupt Gate
    shr rax, 16
    mov word [rdi + 6], ax
    shr rax, 16
    mov dword [rdi + 8], eax
    mov dword [rdi + 12], 0
    ret

; ════════════════════════════════════════════════════════════════════════════
; SETUP TSS - Task State Segment for Ring 3 → Ring 0 transitions
; ════════════════════════════════════════════════════════════════════════════
setup_tss64:
    push rax
    push rbx
    push rcx

    ; Patch TSS base address into GDT descriptor (at offset 0x28)
    ; TSS descriptor is 16 bytes at gdt64 + 0x28
    mov rax, tss64                  ; Get TSS address

    ; Patch Base 15:0 (offset +2 in TSS descriptor)
    mov rbx, gdt64
    add rbx, 0x28                   ; Point to TSS descriptor
    mov word [rbx + 2], ax          ; Base 15:0

    ; Patch Base 23:16 (offset +4)
    shr rax, 16
    mov byte [rbx + 4], al          ; Base 23:16

    ; Patch Base 31:24 (offset +7)
    shr rax, 8
    mov byte [rbx + 7], al          ; Base 31:24

    ; Patch Base 63:32 (offset +8)
    mov rax, tss64
    shr rax, 32
    mov dword [rbx + 8], eax        ; Base 63:32

    ; Note: Don't reload GDT here - gdt64_ptr is 32-bit format
    ; The GDT is already loaded and we just patched it in memory

    ; Load TSS
    mov ax, TSS_SEL
    ltr ax

    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; SETUP PIC
; ════════════════════════════════════════════════════════════════════════════
setup_pic64:
    push rax

    mov al, 0x11
    out 0x20, al
    out 0xA0, al

    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al

    mov al, 0x04
    out 0x21, al
    mov al, 0x02
    out 0xA1, al

    mov al, 0x01
    out 0x21, al
    out 0xA1, al

    ; Enable IRQ0, IRQ1, IRQ2 (cascade), IRQ12
    mov al, 0xF8                    ; Master: IRQ0 + IRQ1 + IRQ2 (cascade to slave)
    out 0x21, al
    mov al, 0xEF                    ; Slave: IRQ12 (bit 4 = 0)
    out 0xA1, al

    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; SETUP PIT (100Hz)
; ════════════════════════════════════════════════════════════════════════════
setup_pit64:
    push rax
    mov al, 0x36
    out 0x43, al
    mov al, 0x9C                    ; 11932 = 0x2E9C for ~100Hz
    out 0x40, al
    mov al, 0x2E
    out 0x40, al
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; TIMER ISR - Preemptive Multitasking
; ════════════════════════════════════════════════════════════════════════════
; Stack on entry (pushed by CPU):
;   +40 SS
;   +32 RSP (original)
;   +24 RFLAGS
;   +16 CS
;   +8  RIP
;   +0  <- RSP points here
; ════════════════════════════════════════════════════════════════════════════
timer_isr64:
    ; ══════════════════════════════════════════════════════════════════
    ; STEP 1: Save ALL general-purpose registers
    ; ══════════════════════════════════════════════════════════════════
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; Now stack layout (15 GP regs + 5 CPU = 160 bytes):
    ; +152 SS
    ; +144 RSP (original)
    ; +136 RFLAGS
    ; +128 CS
    ; +120 RIP
    ; +112 RAX
    ; +104 RBX
    ; +96  RCX
    ; +88  RDX
    ; +80  RSI
    ; +72  RDI
    ; +64  RBP
    ; +56  R8
    ; +48  R9
    ; +40  R10
    ; +32  R11
    ; +24  R12
    ; +16  R13
    ; +8   R14
    ; +0   R15 <- RSP

    ; ══════════════════════════════════════════════════════════════════
    ; Increment system tick (for clock)
    ; ══════════════════════════════════════════════════════════════════
    inc qword [tick_count]

    ; ══════════════════════════════════════════════════════════════════
    ; Check if scheduler is enabled
    ; ══════════════════════════════════════════════════════════════════
    cmp byte [scheduler_enabled], 0
    je .no_schedule

    ; ══════════════════════════════════════════════════════════════════
    ; Decrement time slice of current process
    ; ══════════════════════════════════════════════════════════════════
    mov rdi, [current_process]
    test rdi, rdi
    jz .no_schedule

    dec dword [rdi + PCB_TICKS]
    jnz .no_schedule            ; Time slice not expired yet

    ; ══════════════════════════════════════════════════════════════════
    ; TIME SLICE EXPIRED - Need to context switch!
    ; ══════════════════════════════════════════════════════════════════

    ; Save current process context to its PCB
    ; RDI already points to current_process PCB

    ; Save registers from stack (offsets match stack layout comment above)
    mov rax, [rsp + 112]        ; RAX from stack
    mov [rdi + PCB_RAX], rax
    mov rax, [rsp + 104]        ; RBX from stack
    mov [rdi + PCB_RBX], rax
    mov rax, [rsp + 96]         ; RCX from stack
    mov [rdi + PCB_RCX], rax
    mov rax, [rsp + 88]         ; RDX from stack
    mov [rdi + PCB_RDX], rax
    mov rax, [rsp + 80]         ; RSI from stack
    mov [rdi + PCB_RSI], rax
    mov rax, [rsp + 72]         ; RDI from stack
    mov [rdi + PCB_RDI], rax
    mov rax, [rsp + 64]         ; RBP from stack
    mov [rdi + PCB_RBP], rax
    mov rax, [rsp + 56]         ; R8 from stack
    mov [rdi + PCB_R8], rax
    mov rax, [rsp + 48]         ; R9 from stack
    mov [rdi + PCB_R9], rax
    mov rax, [rsp + 40]         ; R10 from stack
    mov [rdi + PCB_R10], rax
    mov rax, [rsp + 32]         ; R11 from stack
    mov [rdi + PCB_R11], rax
    mov rax, [rsp + 24]         ; R12 from stack
    mov [rdi + PCB_R12], rax
    mov rax, [rsp + 16]         ; R13 from stack
    mov [rdi + PCB_R13], rax
    mov rax, [rsp + 8]          ; R14 from stack
    mov [rdi + PCB_R14], rax
    mov rax, [rsp + 0]          ; R15 from stack
    mov [rdi + PCB_R15], rax

    ; Save CPU state from iretq frame
    mov rax, [rsp + 120]        ; RIP
    mov [rdi + PCB_RIP], rax
    mov rax, [rsp + 136]        ; RFLAGS
    mov [rdi + PCB_RFLAGS], rax
    mov rax, [rsp + 144]        ; RSP (original)
    mov [rdi + PCB_RSP], rax

    ; Mark current process as READY (it was RUNNING)
    mov byte [rdi + PCB_STATE], PROC_STATE_READY

    ; ══════════════════════════════════════════════════════════════════
    ; STEP 2: Find next READY process (round-robin)
    ; ══════════════════════════════════════════════════════════════════
    mov rbx, rdi                ; RBX = current process (start point)

.find_next:
    add rdi, PCB_SIZE           ; Move to next slot

    ; Wrap around if past end of table
    lea rax, [process_table + MAX_PROCESSES * PCB_SIZE]
    cmp rdi, rax
    jl .check_slot
    mov rdi, process_table      ; Wrap to beginning

.check_slot:
    ; Did we loop back to start?
    cmp rdi, rbx
    je .no_other_process        ; No other ready process found

    ; Is this slot READY?
    cmp byte [rdi + PCB_STATE], PROC_STATE_READY
    jne .find_next              ; No, try next

    ; Found a READY process! Switch to it.
    jmp .do_switch

.no_other_process:
    ; No other process ready - keep running current one
    mov rdi, rbx
    mov dword [rdi + PCB_TICKS], TIME_SLICE
    mov byte [rdi + PCB_STATE], PROC_STATE_RUNNING
    jmp .no_schedule

.do_switch:
    ; ══════════════════════════════════════════════════════════════════
    ; STEP 3: Load new process context
    ; ══════════════════════════════════════════════════════════════════

    ; Update current_process pointer
    mov [current_process], rdi

    ; Mark new process as RUNNING
    mov byte [rdi + PCB_STATE], PROC_STATE_RUNNING
    mov dword [rdi + PCB_TICKS], TIME_SLICE

    ; ══════════════════════════════════════════════════════════════════
    ; STEP 4: Restore registers and iretq
    ; ══════════════════════════════════════════════════════════════════

    ; Restore iretq frame on stack (offsets match stack layout comment)
    mov rax, [rdi + PCB_RIP]
    mov [rsp + 120], rax        ; RIP
    mov rax, [rdi + PCB_RFLAGS]
    or rax, 0x200               ; Ensure interrupts enabled
    mov [rsp + 136], rax        ; RFLAGS
    mov rax, [rdi + PCB_RSP]
    mov [rsp + 144], rax        ; RSP
    mov qword [rsp + 128], 0x08 ; CS (kernel code)
    mov qword [rsp + 152], 0x10 ; SS (kernel data)

    ; Restore general registers on stack (will be popped)
    mov rax, [rdi + PCB_RAX]
    mov [rsp + 112], rax
    mov rax, [rdi + PCB_RBX]
    mov [rsp + 104], rax
    mov rax, [rdi + PCB_RCX]
    mov [rsp + 96], rax
    mov rax, [rdi + PCB_RDX]
    mov [rsp + 88], rax
    mov rax, [rdi + PCB_RSI]
    mov [rsp + 80], rax
    mov rax, [rdi + PCB_RDI]
    mov [rsp + 72], rax
    mov rax, [rdi + PCB_RBP]
    mov [rsp + 64], rax
    mov rax, [rdi + PCB_R8]
    mov [rsp + 56], rax
    mov rax, [rdi + PCB_R9]
    mov [rsp + 48], rax
    mov rax, [rdi + PCB_R10]
    mov [rsp + 40], rax
    mov rax, [rdi + PCB_R11]
    mov [rsp + 32], rax
    mov rax, [rdi + PCB_R12]
    mov [rsp + 24], rax
    mov rax, [rdi + PCB_R13]
    mov [rsp + 16], rax
    mov rax, [rdi + PCB_R14]
    mov [rsp + 8], rax
    mov rax, [rdi + PCB_R15]
    mov [rsp + 0], rax

.no_schedule:
    ; ══════════════════════════════════════════════════════════════════
    ; Send EOI and return
    ; ══════════════════════════════════════════════════════════════════
    mov al, 0x20
    out 0x20, al

    ; Restore all registers from stack
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ; Return to (possibly new) process
    iretq

; ════════════════════════════════════════════════════════════════════════════
; SYSCALL ISR (INT 0x80) - Redirects to full syscall handler
; See syscalls.asm for complete syscall table (48 syscalls)
; ════════════════════════════════════════════════════════════════════════════
syscall_isr64:
    jmp syscall_handler         ; Jump to full syscall dispatcher

; ════════════════════════════════════════════════════════════════════════════
; KEYBOARD ISR - Full keyboard support with shift, arrows
; ════════════════════════════════════════════════════════════════════════════
keyboard_isr64:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi

    in al, 0x60
    mov bl, al                      ; Save scancode in bl

    ; Check for key release (bit 7 set)
    test bl, 0x80
    jz .key_press

    ; Key release - check for shift release
    and bl, 0x7F                    ; Remove release bit
    cmp bl, 0x2A                    ; Left shift
    je .shift_release
    cmp bl, 0x36                    ; Right shift
    je .shift_release
    cmp bl, 0x1D                    ; Ctrl
    je .ctrl_release
    jmp .kb_done

.shift_release:
    mov byte [shift_state], 0
    jmp .kb_done

.ctrl_release:
    mov byte [ctrl_state], 0
    jmp .kb_done

.key_press:
    ; Check for shift press
    cmp bl, 0x2A                    ; Left shift
    je .shift_press
    cmp bl, 0x36                    ; Right shift
    je .shift_press
    cmp bl, 0x1D                    ; Ctrl
    je .ctrl_press

    ; ESC = reboot
    cmp bl, 0x01
    je .reboot

    ; Tab = cycle modes
    cmp bl, 0x0F
    jne .check_f9
    inc byte [mode_flag]
    cmp byte [mode_flag], 3
    jl .kb_done
    mov byte [mode_flag], 0
    jmp .kb_done

.check_f9:
    ; F9 = Launch Ring 3 user process demo
    cmp bl, 0x43                    ; F9 scancode
    jne .check_arrows
    ; Launch user process in Ring 3
    mov rdi, user_process_demo      ; Entry point
    mov rsi, user_stack_top         ; User stack
    call switch_to_ring3            ; Never returns!

.shift_press:
    mov byte [shift_state], 1
    jmp .kb_done

.ctrl_press:
    mov byte [ctrl_state], 1
    jmp .kb_done

.check_arrows:
    ; Arrow keys (use for navigation in GUI)
    cmp bl, 0x48                    ; Up arrow
    je .arrow_up
    cmp bl, 0x50                    ; Down arrow
    je .arrow_down
    cmp bl, 0x4B                    ; Left arrow
    je .arrow_left
    cmp bl, 0x4D                    ; Right arrow
    je .arrow_right

    ; Enter key = click if no terminal active, else execute command
    cmp bl, 0x1C
    je .enter_key

    ; Space in GUI (no terminal) = click
    cmp bl, 0x39
    jne .not_space_gui
    cmp byte [mode_flag], 2
    jne .not_space_gui
    movzx rax, byte [active_window]
    cmp al, 0xFF
    je .space_click
    shl rax, 5
    cmp byte [windows + rax + 1], 1
    jne .space_click
.not_space_gui:

    ; Only process typing in GUI mode with terminal window
    cmp byte [mode_flag], 2
    jne .kb_done

    ; Check if terminal window is open and active
    movzx rax, byte [active_window]
    cmp al, 0xFF
    je .kb_done
    shl rax, 5
    cmp byte [windows + rax + 1], 1    ; Type 1 = terminal
    jne .kb_done

    ; Backspace
    cmp bl, 0x0E
    jne .not_bs
    cmp byte [cmd_pos], 0
    je .kb_done
    dec byte [cmd_pos]
    movzx rbx, byte [cmd_pos]
    mov byte [cmd_buf + rbx], 0
    jmp .kb_done
.not_bs:

    ; Convert scancode to ASCII
    movzx rax, bl
    cmp al, 58
    jae .kb_done

    ; Check shift state for uppercase/symbols
    cmp byte [shift_state], 1
    je .use_shift_table
    mov al, [scancode_ascii + rax]
    jmp .got_char
.use_shift_table:
    mov al, [scancode_shift + rax]
.got_char:
    test al, al
    jz .kb_done

    ; Add to buffer
    movzx rbx, byte [cmd_pos]
    cmp bl, 30
    jae .kb_done
    mov [cmd_buf + rbx], al
    inc byte [cmd_pos]
    jmp .kb_done

; Arrow key handlers - move mouse cursor with keyboard
.arrow_up:
    cmp word [mouse_y], 5
    jl .kb_done
    sub word [mouse_y], 5
    jmp .kb_done

.arrow_down:
    cmp word [mouse_y], GFX_H - 15
    jg .kb_done
    add word [mouse_y], 5
    jmp .kb_done

.arrow_left:
    cmp word [mouse_x], 5
    jl .kb_done
    sub word [mouse_x], 5
    jmp .kb_done

.arrow_right:
    cmp word [mouse_x], GFX_W - 13
    jg .kb_done
    add word [mouse_x], 5
    jmp .kb_done

; Enter key handler
.enter_key:
    cmp byte [mode_flag], 2
    jne .kb_done
    movzx rax, byte [active_window]
    cmp al, 0xFF
    je .enter_click                 ; No window = click
    shl rax, 5
    cmp byte [windows + rax + 1], 1
    jne .enter_click                ; Not terminal = click
    ; Terminal is active, execute command
    call execute_cmd
    jmp .kb_done
.enter_click:
    call handle_mouse_click
    jmp .kb_done

; Space bar = simulate mouse click in GUI mode (when no terminal)
.space_click:
    call handle_mouse_click
    jmp .kb_done

.kb_done:
    mov al, 0x20
    out 0x20, al
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    iretq

.reboot:
    lidt [idt64_null]
    int 0

; ════════════════════════════════════════════════════════════════════════════
; MOUSE ISR
; ════════════════════════════════════════════════════════════════════════════
mouse_isr64:
    push rax
    push rbx
    push rcx

    in al, MOUSE_DATA
    movzx rbx, byte [mouse_cycle]

    cmp bl, 0
    je .byte0
    cmp bl, 1
    je .byte1
    jmp .byte2

.byte0:
    ; Validate byte0: bit 3 must be 1 (PS/2 protocol)
    test al, 0x08
    jz .mouse_done                      ; Invalid packet, resync
    mov [mouse_byte0], al
    inc byte [mouse_cycle]
    jmp .mouse_done

.byte1:
    mov [mouse_byte1], al
    inc byte [mouse_cycle]
    jmp .mouse_done

.byte2:
    mov [mouse_byte2], al
    mov byte [mouse_cycle], 0

    ; Process packet
    mov al, [mouse_byte0]
    mov [mouse_buttons], al

    ; Update X
    movsx bx, byte [mouse_byte1]
    add [mouse_x], bx

    ; Clamp X
    cmp word [mouse_x], 0
    jge .x_min_ok
    mov word [mouse_x], 0
.x_min_ok:
    cmp word [mouse_x], GFX_W - 8
    jle .x_max_ok
    mov word [mouse_x], GFX_W - 8
.x_max_ok:

    ; Update Y (inverted)
    movsx bx, byte [mouse_byte2]
    neg bx
    add [mouse_y], bx

    ; Clamp Y
    cmp word [mouse_y], 0
    jge .y_min_ok
    mov word [mouse_y], 0
.y_min_ok:
    cmp word [mouse_y], GFX_H - 10
    jle .y_max_ok
    mov word [mouse_y], GFX_H - 10
.y_max_ok:

    ; Check for click (with debounce + cooldown)
    ; First check cooldown timer
    mov ecx, [click_cooldown]
    test ecx, ecx
    jz .cooldown_ok
    dec dword [click_cooldown]
    jmp .no_click
.cooldown_ok:
    mov al, [mouse_byte0]
    and al, 1                           ; Isolate left button
    mov ah, [last_mouse_btn]
    mov [last_mouse_btn], al            ; Save current state
    test ah, ah                         ; Was button pressed before?
    jnz .no_click                       ; Yes = ignore (held down)
    test al, al                         ; Is button pressed now?
    jz .no_click                        ; No = no click
    ; Button just pressed (0->1 transition)
    mov dword [click_cooldown], 15      ; 15 packets cooldown (~150ms)
    call handle_mouse_click
.no_click:

.mouse_done:
    mov al, 0x20
    out 0xA0, al
    out 0x20, al

    pop rcx
    pop rbx
    pop rax
    iretq

; ════════════════════════════════════════════════════════════════════════════
; HANDLE MOUSE CLICK
; ════════════════════════════════════════════════════════════════════════════
handle_mouse_click:
    push rax
    push rbx
    push rcx
    push rdx

    movzx eax, word [mouse_x]
    movzx ebx, word [mouse_y]

    ; Check if clicking on Start button
    cmp eax, 44
    jg .not_start_btn
    cmp ebx, GFX_H - TASKBAR_H
    jl .not_start_btn
    xor byte [start_menu_open], 1
    jmp .click_done
.not_start_btn:

    ; Check Start menu clicks
    cmp byte [start_menu_open], 0
    je .not_menu

    ; Menu bounds: x=4-84, y=(GFX_H-TASKBAR_H-70) to (GFX_H-TASKBAR_H)
    cmp eax, 4
    jl .close_menu
    cmp eax, 84
    jg .close_menu
    cmp ebx, GFX_H - TASKBAR_H - 70
    jl .close_menu
    cmp ebx, GFX_H - TASKBAR_H
    jg .close_menu

    ; Which menu item?
    mov ecx, ebx
    sub ecx, GFX_H - TASKBAR_H - 70

    cmp ecx, 14
    jl .menu_terminal
    cmp ecx, 28
    jl .menu_files
    cmp ecx, 42
    jl .menu_3d
    cmp ecx, 56
    jl .menu_about
    jmp .menu_reboot

.menu_terminal:
    mov byte [start_menu_open], 0
    mov edi, 1                      ; Type: terminal
    mov esi, 100                    ; x
    mov edx, 20                     ; y
    call open_window
    jmp .click_done

.menu_files:
    mov byte [start_menu_open], 0
    mov edi, 2                      ; Type: files
    mov esi, 120                    ; x
    mov edx, 30                     ; y
    call open_window
    jmp .click_done

.menu_3d:
    mov byte [start_menu_open], 0
    mov edi, 3                      ; Type: 3D
    mov esi, 140                    ; x
    mov edx, 40                     ; y
    call open_window
    jmp .click_done

.menu_about:
    mov byte [start_menu_open], 0
    jmp .click_done

.menu_reboot:
    lidt [idt64_null]
    int 0

.close_menu:
    ; Don't close menu when clicking outside - only close via Start button or item selection
    ; This gives user more time to navigate with keyboard
    jmp .click_done

.not_menu:
    ; Check icon clicks
    ; Terminal icon (38-66, 30-50)
    cmp eax, 38
    jl .not_term_icon
    cmp eax, 66
    jg .not_term_icon
    cmp ebx, 30
    jl .not_term_icon
    cmp ebx, 50
    jg .not_term_icon
    mov edi, 1
    mov esi, 100
    mov edx, 20
    call open_window
    jmp .click_done
.not_term_icon:

    ; Files icon (38-66, 80-100)
    cmp eax, 38
    jl .not_files_icon
    cmp eax, 66
    jg .not_files_icon
    cmp ebx, 80
    jl .not_files_icon
    cmp ebx, 100
    jg .not_files_icon
    mov edi, 2
    mov esi, 120
    mov edx, 30
    call open_window
    jmp .click_done
.not_files_icon:

    ; 3D icon (38-66, 130-150)
    cmp eax, 38
    jl .not_3d_icon
    cmp eax, 66
    jg .not_3d_icon
    cmp ebx, 130
    jl .not_3d_icon
    cmp ebx, 150
    jg .not_3d_icon
    mov edi, 3
    mov esi, 140
    mov edx, 40
    call open_window
    jmp .click_done
.not_3d_icon:

    ; Check window clicks (close button, titlebar for drag)
    call check_window_clicks

.click_done:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; CHECK WINDOW CLICKS
; ════════════════════════════════════════════════════════════════════════════
check_window_clicks:
    push rax
    push rbx
    push rcx
    push rdx
    push r12

    movzx eax, word [mouse_x]
    movzx ebx, word [mouse_y]

    ; Check each window (reverse order for z-order)
    mov r12d, MAX_WINDOWS - 1

.check_win_loop:
    cmp r12d, 0
    jl .no_window_hit

    mov ecx, r12d
    shl ecx, 5
    lea rdx, [windows + rcx]

    ; Skip if not open
    cmp byte [rdx], 0
    je .next_win

    ; Get window bounds
    movzx ecx, word [rdx + 2]       ; win_x
    cmp eax, ecx
    jl .next_win

    movzx esi, word [rdx + 6]       ; win_w
    add esi, ecx
    cmp eax, esi
    jg .next_win

    movzx esi, word [rdx + 4]       ; win_y
    cmp ebx, esi
    jl .next_win

    movzx edi, word [rdx + 8]       ; win_h
    add edi, esi
    cmp ebx, edi
    jg .next_win

    ; Hit! Set as active
    mov [active_window], r12b

    ; Check close button
    movzx ecx, word [rdx + 2]
    movzx esi, word [rdx + 6]
    add ecx, esi
    sub ecx, 12                     ; Close button x
    cmp eax, ecx
    jl .not_close
    movzx esi, word [rdx + 4]
    add esi, 2
    cmp ebx, esi
    jl .not_close
    add esi, 10
    cmp ebx, esi
    jg .not_close

    ; Close window
    mov byte [rdx], 0
    mov byte [active_window], 0xFF
    jmp .win_check_done

.not_close:
    ; Could add drag handling here
    jmp .win_check_done

.next_win:
    dec r12d
    jmp .check_win_loop

.no_window_hit:
    mov byte [active_window], 0xFF

.win_check_done:
    pop r12
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; OPEN WINDOW - edi=type, esi=x, edx=y
; ════════════════════════════════════════════════════════════════════════════
open_window:
    push rax
    push rbx
    push rcx

    ; Find empty slot
    xor ecx, ecx
.find_slot:
    cmp ecx, MAX_WINDOWS
    jge .no_slot

    mov eax, ecx
    shl eax, 5
    cmp byte [windows + rax], 0
    je .found_slot
    inc ecx
    jmp .find_slot

.found_slot:
    lea rbx, [windows + rax]

    ; Setup window
    mov byte [rbx], 1               ; flags = open
    mov byte [rbx + 1], dil         ; type
    mov word [rbx + 2], si          ; x
    mov word [rbx + 4], dx          ; y
    mov word [rbx + 6], 120         ; width
    mov word [rbx + 8], 80          ; height

    ; Set title based on type
    cmp dil, 1
    jne .not_term
    mov qword [rbx + 16], str_win_terminal
    jmp .title_done
.not_term:
    cmp dil, 2
    jne .not_files
    mov qword [rbx + 16], str_win_files
    jmp .title_done
.not_files:
    mov qword [rbx + 16], str_win_3d
.title_done:

    mov [active_window], cl

.no_slot:
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; EXECUTE COMMAND
; ════════════════════════════════════════════════════════════════════════════
execute_cmd:
    push rax
    push rbx
    push rcx
    push rdi

    ; Check commands
    cmp dword [cmd_buf], 'help'
    je .cmd_help
    cmp dword [cmd_buf], 'clea'
    je .cmd_clear
    cmp word [cmd_buf], 'ls'
    je .cmd_ls
    cmp word [cmd_buf], 'ps'
    je .cmd_ps
    cmp dword [cmd_buf], 'kill'
    je .cmd_kill
    jmp .cmd_unknown

.cmd_help:
    mov rsi, str_help_result
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_clear:
    mov byte [show_result], 0
    jmp .clear_cmd

.cmd_ls:
    mov rsi, str_ls_result
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_ps:
    ; Show process list - format: "3 procs running"
    call get_process_count
    mov rdi, result_buf
    add al, '0'                             ; Convert to ASCII
    mov [rdi], al
    mov byte [rdi + 1], ' '
    mov byte [rdi + 2], 'p'
    mov byte [rdi + 3], 'r'
    mov byte [rdi + 4], 'o'
    mov byte [rdi + 5], 'c'
    mov byte [rdi + 6], 's'
    mov byte [rdi + 7], 0
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_kill:
    ; kill <pid> - Kill a process (parse single digit PID)
    movzx edi, byte [cmd_buf + 5]           ; Get char after "kill "
    sub edi, '0'                            ; Convert to number
    cmp edi, 0
    jle .kill_failed
    cmp edi, 9
    jg .kill_failed
    call kill_process
    test eax, eax
    jnz .kill_failed
    ; Success
    mov rdi, result_buf
    mov byte [rdi], 'O'
    mov byte [rdi + 1], 'K'
    mov byte [rdi + 2], 0
    mov byte [show_result], 1
    jmp .clear_cmd
.kill_failed:
    mov rdi, result_buf
    mov byte [rdi], 'E'
    mov byte [rdi + 1], 'r'
    mov byte [rdi + 2], 'r'
    mov byte [rdi + 3], 0
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_unknown:
    mov byte [show_result], 0

.clear_cmd:
    mov rdi, cmd_buf
    mov rcx, 32
    xor al, al
    rep stosb
    mov byte [cmd_pos], 0

    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

copy_string:
    lodsb
    stosb
    test al, al
    jnz copy_string
    ret

; ════════════════════════════════════════════════════════════════════════════
; DEMO PROCESSES - Background tasks for multitasking demonstration
; ════════════════════════════════════════════════════════════════════════════

; Demo process 1 - Increments a counter (simulates background work)
demo_process_1:
    inc qword [demo1_counter]
    ; Simulate work
    mov rcx, 50000
.work1:
    nop
    dec rcx
    jnz .work1
    jmp demo_process_1

; Demo process 2 - Another background counter
demo_process_2:
    inc qword [demo2_counter]
    ; Simulate different work
    mov rcx, 30000
.work2:
    nop
    dec rcx
    jnz .work2
    jmp demo_process_2

; ════════════════════════════════════════════════════════════════════════════
; RING 3 USER-MODE SUPPORT
; ════════════════════════════════════════════════════════════════════════════

; Switch to Ring 3 (user mode)
; RDI = user entry point
; RSI = user stack pointer
switch_to_ring3:
    cli                             ; Disable interrupts during switch

    ; Build iretq stack frame to "return" to Ring 3
    push USER_DATA_SEL              ; SS (user data selector with RPL=3)
    push rsi                        ; RSP (user stack)
    pushfq                          ; RFLAGS
    or qword [rsp], 0x200           ; Set IF (interrupts enabled)
    push USER_CODE_SEL              ; CS (user code selector with RPL=3)
    push rdi                        ; RIP (user entry point)

    ; Clear registers for clean user state
    xor rax, rax
    xor rbx, rbx
    xor rcx, rcx
    xor rdx, rdx
    xor rsi, rsi
    xor rdi, rdi
    xor rbp, rbp
    xor r8, r8
    xor r9, r9
    xor r10, r10
    xor r11, r11
    xor r12, r12
    xor r13, r13
    xor r14, r14
    xor r15, r15

    iretq                           ; "Return" to user mode

; ════════════════════════════════════════════════════════════════════════════
; USER-MODE DEMO PROCESS
; This code runs in Ring 3! It can only use syscalls to interact with kernel.
; New syscall numbers: see syscalls.asm
; ════════════════════════════════════════════════════════════════════════════
user_process_demo:
    ; Running in Ring 3 now!
    ; Get our PID via syscall
    mov rax, SYS_GETPID             ; syscall 11
    int 0x80                        ; Returns PID in RAX

    ; Draw a pixel pattern using syscalls to prove we're in user mode
    mov r12, 10                     ; x position
    mov r13, 180                    ; y position (near bottom)
    mov r14, 0                      ; color counter

.user_loop:
    ; sys_putpixel: draw pixel at (x, y) with color
    mov rax, SYS_PUTPIXEL           ; syscall 40
    mov rdi, r12                    ; x
    mov rsi, r13                    ; y
    mov rdx, r14                    ; color
    int 0x80

    ; Move to next position
    inc r12
    cmp r12, 300
    jl .no_wrap
    mov r12, 10
    inc r14                         ; Next color
.no_wrap:

    ; Yield to let other processes run
    mov rax, SYS_YIELD              ; syscall 18
    int 0x80

    ; Small delay using sleep syscall (10ms)
    mov rax, SYS_SLEEP              ; syscall 17
    mov rdi, 10                     ; 10 milliseconds
    int 0x80

    jmp .user_loop

; User stack area (must be in mapped memory)
align 16
user_stack_bottom:
    times 4096 db 0                 ; 4KB user stack
user_stack_top:

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE SCHEDULER MODULE
; ════════════════════════════════════════════════════════════════════════════
%include "scheduler.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE E1000 NETWORK DRIVER
; ════════════════════════════════════════════════════════════════════════════
%include "e1000/e1000.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE SYSCALLS MODULE (48 system calls)
; ════════════════════════════════════════════════════════════════════════════
%include "syscalls.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE USB UHCI DRIVER
; ════════════════════════════════════════════════════════════════════════════
%include "usb/uhci.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE ACPI POWER MANAGEMENT
; ════════════════════════════════════════════════════════════════════════════
%include "acpi.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE HEAP ALLOCATOR
; ════════════════════════════════════════════════════════════════════════════
%include "mm/heap.asm"

; ════════════════════════════════════════════════════════════════════════════
; DATA SECTION
; ════════════════════════════════════════════════════════════════════════════
align 8

; System variables
tick_count:     dq 0
mode_flag:      db 2                ; 0=3D, 1=shell, 2=GUI
active_window:  db 0xFF
start_menu_open: db 0
dragging:       db 0
drag_window:    db 0
drag_offset_x:  dw 0
drag_offset_y:  dw 0

; Mouse state
mouse_x:        dw 160
mouse_y:        dw 100
mouse_buttons:  db 0
mouse_cycle:    db 0
mouse_byte0:    db 0
mouse_byte1:    db 0
mouse_byte2:    db 0
last_mouse_btn: db 0                    ; For click debounce
click_cooldown: dd 0                    ; Cooldown timer between clicks

; Terminal state
cmd_buf:        times 64 db 0
cmd_pos:        db 0
show_result:    db 0
result_buf:     times 64 db 0

; Demo process counters (to show multitasking is working)
demo1_counter:  dq 0
demo2_counter:  dq 0

; Clock buffer for time display
clock_buf:      times 8 db 0

; Process indicator buffer
proc_ind_buf:   times 8 db 0

; Temp variables for 3D
temp_x1:        dd 0
temp_y1:        dd 0
temp_x2:        dd 0
temp_y2:        dd 0
temp_x3:        dd 0
temp_y3:        dd 0
temp_x4:        dd 0
temp_y4:        dd 0

; Windows array (4 windows * 32 bytes each)
; Format: flags(1), type(1), x(2), y(2), w(2), h(2), reserved(6), title_ptr(8), extra(8)
align 8
windows:        times MAX_WINDOWS * 32 db 0

; Strings
str_banner:     db "MATHIS OS 64-BIT", 0
str_start:      db "Start", 0
str_terminal:   db "Terminal", 0
str_files:      db "Files", 0
str_3ddemo:     db "3D Demo", 0
str_x:          db "X", 0

str_win_terminal: db "Terminal", 0
str_win_files:    db "Files", 0
str_win_3d:       db "3D Demo", 0

str_term_header:  db "MATHIS OS Terminal", 0
str_term_help:    db "Cmds: help,ps,kill <pid>", 0
str_prompt:       db "mathis>", 0

str_file1:        db "[DIR] boot/", 0
str_file2:        db "[DIR] system/", 0
str_file3:        db "readme.txt", 0

str_menu_term:    db "Terminal", 0
str_menu_files:   db "Files", 0
str_menu_3d:      db "3D Demo", 0
str_menu_about:   db "About", 0
str_menu_reboot:  db "Reboot", 0

str_help_result:  db "help,clear,ls,ps", 0
str_ls_result:    db "boot/ readme.txt", 0

str_3d_mode:      db "3D MODE", 0
str_help_gfx:     db "TAB=next mode", 0
str_help_shell:   db "TAB=next mode ESC=reboot", 0

; Process names for demos
str_proc_demo1:   db "worker1", 0
str_proc_demo2:   db "worker2", 0
str_ps_header:    db "PID STATE NAME", 0
str_proc_run:     db "RUN ", 0
str_proc_rdy:     db "RDY ", 0
str_proc_blk:     db "BLK ", 0

; Scancode to ASCII (lowercase/unshifted)
scancode_ascii:
    db 0, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0, 0
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0, 0
    db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0, '\'
    db 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, 0, 0, ' '

; Sin table for 3D
sin_table:
    db  0,  3,  6,  9, 12, 15, 18, 21
    db 24, 26, 28, 30, 31, 32, 32, 32
    db 32, 32, 32, 31, 30, 28, 26, 24
    db 21, 18, 15, 12,  9,  6,  3,  0
    db  0, -3, -6, -9,-12,-15,-18,-21
    db -24,-26,-28,-30,-31,-32,-32,-32
    db -32,-32,-32,-31,-30,-28,-26,-24
    db -21,-18,-15,-12, -9, -6, -3,  0

; 8x8 Bitmap Font (ASCII 32-127)
align 8
font8x8:
    ; Space (32)
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ; ! (33)
    db 0x18, 0x18, 0x18, 0x18, 0x18, 0x00, 0x18, 0x00
    ; " (34)
    db 0x6C, 0x6C, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00
    ; # (35)
    db 0x6C, 0xFE, 0x6C, 0x6C, 0xFE, 0x6C, 0x00, 0x00
    ; $ (36)
    db 0x18, 0x7E, 0xC0, 0x7C, 0x06, 0xFC, 0x18, 0x00
    ; % (37)
    db 0xC6, 0xCC, 0x18, 0x30, 0x66, 0xC6, 0x00, 0x00
    ; & (38)
    db 0x38, 0x6C, 0x38, 0x76, 0xDC, 0xCC, 0x76, 0x00
    ; ' (39)
    db 0x18, 0x18, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00
    ; ( (40)
    db 0x0C, 0x18, 0x30, 0x30, 0x30, 0x18, 0x0C, 0x00
    ; ) (41)
    db 0x30, 0x18, 0x0C, 0x0C, 0x0C, 0x18, 0x30, 0x00
    ; * (42)
    db 0x00, 0x66, 0x3C, 0xFF, 0x3C, 0x66, 0x00, 0x00
    ; + (43)
    db 0x00, 0x18, 0x18, 0x7E, 0x18, 0x18, 0x00, 0x00
    ; , (44)
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x30
    ; - (45)
    db 0x00, 0x00, 0x00, 0x7E, 0x00, 0x00, 0x00, 0x00
    ; . (46)
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00
    ; / (47)
    db 0x06, 0x0C, 0x18, 0x30, 0x60, 0xC0, 0x00, 0x00
    ; 0 (48)
    db 0x7C, 0xCE, 0xDE, 0xF6, 0xE6, 0xC6, 0x7C, 0x00
    ; 1 (49)
    db 0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00
    ; 2 (50)
    db 0x7C, 0xC6, 0x0E, 0x3C, 0x78, 0xE0, 0xFE, 0x00
    ; 3 (51)
    db 0x7C, 0xC6, 0x06, 0x3C, 0x06, 0xC6, 0x7C, 0x00
    ; 4 (52)
    db 0x1C, 0x3C, 0x6C, 0xCC, 0xFE, 0x0C, 0x0C, 0x00
    ; 5 (53)
    db 0xFE, 0xC0, 0xFC, 0x06, 0x06, 0xC6, 0x7C, 0x00
    ; 6 (54)
    db 0x7C, 0xC0, 0xFC, 0xC6, 0xC6, 0xC6, 0x7C, 0x00
    ; 7 (55)
    db 0xFE, 0x06, 0x0C, 0x18, 0x30, 0x30, 0x30, 0x00
    ; 8 (56)
    db 0x7C, 0xC6, 0xC6, 0x7C, 0xC6, 0xC6, 0x7C, 0x00
    ; 9 (57)
    db 0x7C, 0xC6, 0xC6, 0x7E, 0x06, 0x06, 0x7C, 0x00
    ; : (58)
    db 0x00, 0x18, 0x18, 0x00, 0x00, 0x18, 0x18, 0x00
    ; ; (59)
    db 0x00, 0x18, 0x18, 0x00, 0x00, 0x18, 0x18, 0x30
    ; < (60)
    db 0x0C, 0x18, 0x30, 0x60, 0x30, 0x18, 0x0C, 0x00
    ; = (61)
    db 0x00, 0x00, 0x7E, 0x00, 0x7E, 0x00, 0x00, 0x00
    ; > (62)
    db 0x30, 0x18, 0x0C, 0x06, 0x0C, 0x18, 0x30, 0x00
    ; ? (63)
    db 0x7C, 0xC6, 0x0C, 0x18, 0x18, 0x00, 0x18, 0x00
    ; @ (64)
    db 0x7C, 0xC6, 0xDE, 0xDE, 0xDE, 0xC0, 0x7C, 0x00
    ; A (65)
    db 0x38, 0x6C, 0xC6, 0xC6, 0xFE, 0xC6, 0xC6, 0x00
    ; B (66)
    db 0xFC, 0xC6, 0xC6, 0xFC, 0xC6, 0xC6, 0xFC, 0x00
    ; C (67)
    db 0x7C, 0xC6, 0xC0, 0xC0, 0xC0, 0xC6, 0x7C, 0x00
    ; D (68)
    db 0xF8, 0xCC, 0xC6, 0xC6, 0xC6, 0xCC, 0xF8, 0x00
    ; E (69)
    db 0xFE, 0xC0, 0xC0, 0xF8, 0xC0, 0xC0, 0xFE, 0x00
    ; F (70)
    db 0xFE, 0xC0, 0xC0, 0xF8, 0xC0, 0xC0, 0xC0, 0x00
    ; G (71)
    db 0x7C, 0xC6, 0xC0, 0xCE, 0xC6, 0xC6, 0x7C, 0x00
    ; H (72)
    db 0xC6, 0xC6, 0xC6, 0xFE, 0xC6, 0xC6, 0xC6, 0x00
    ; I (73)
    db 0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00
    ; J (74)
    db 0x1E, 0x06, 0x06, 0x06, 0xC6, 0xC6, 0x7C, 0x00
    ; K (75)
    db 0xC6, 0xCC, 0xD8, 0xF0, 0xD8, 0xCC, 0xC6, 0x00
    ; L (76)
    db 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xFE, 0x00
    ; M (77)
    db 0xC6, 0xEE, 0xFE, 0xD6, 0xC6, 0xC6, 0xC6, 0x00
    ; N (78)
    db 0xC6, 0xE6, 0xF6, 0xDE, 0xCE, 0xC6, 0xC6, 0x00
    ; O (79)
    db 0x7C, 0xC6, 0xC6, 0xC6, 0xC6, 0xC6, 0x7C, 0x00
    ; P (80)
    db 0xFC, 0xC6, 0xC6, 0xFC, 0xC0, 0xC0, 0xC0, 0x00
    ; Q (81)
    db 0x7C, 0xC6, 0xC6, 0xC6, 0xD6, 0xDE, 0x7C, 0x06
    ; R (82)
    db 0xFC, 0xC6, 0xC6, 0xFC, 0xD8, 0xCC, 0xC6, 0x00
    ; S (83)
    db 0x7C, 0xC6, 0xC0, 0x7C, 0x06, 0xC6, 0x7C, 0x00
    ; T (84)
    db 0xFE, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00
    ; U (85)
    db 0xC6, 0xC6, 0xC6, 0xC6, 0xC6, 0xC6, 0x7C, 0x00
    ; V (86)
    db 0xC6, 0xC6, 0xC6, 0xC6, 0x6C, 0x38, 0x10, 0x00
    ; W (87)
    db 0xC6, 0xC6, 0xC6, 0xD6, 0xFE, 0xEE, 0xC6, 0x00
    ; X (88)
    db 0xC6, 0xC6, 0x6C, 0x38, 0x6C, 0xC6, 0xC6, 0x00
    ; Y (89)
    db 0xC6, 0xC6, 0x6C, 0x38, 0x18, 0x18, 0x18, 0x00
    ; Z (90)
    db 0xFE, 0x06, 0x0C, 0x18, 0x30, 0x60, 0xFE, 0x00
    ; [ (91)
    db 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00
    ; \ (92)
    db 0xC0, 0x60, 0x30, 0x18, 0x0C, 0x06, 0x00, 0x00
    ; ] (93)
    db 0x3C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x3C, 0x00
    ; ^ (94)
    db 0x10, 0x38, 0x6C, 0xC6, 0x00, 0x00, 0x00, 0x00
    ; _ (95)
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFE
    ; ` (96)
    db 0x18, 0x18, 0x0C, 0x00, 0x00, 0x00, 0x00, 0x00
    ; a (97)
    db 0x00, 0x00, 0x7C, 0x06, 0x7E, 0xC6, 0x7E, 0x00
    ; b (98)
    db 0xC0, 0xC0, 0xFC, 0xC6, 0xC6, 0xC6, 0xFC, 0x00
    ; c (99)
    db 0x00, 0x00, 0x7C, 0xC6, 0xC0, 0xC6, 0x7C, 0x00
    ; d (100)
    db 0x06, 0x06, 0x7E, 0xC6, 0xC6, 0xC6, 0x7E, 0x00
    ; e (101)
    db 0x00, 0x00, 0x7C, 0xC6, 0xFE, 0xC0, 0x7C, 0x00
    ; f (102)
    db 0x1C, 0x36, 0x30, 0x78, 0x30, 0x30, 0x30, 0x00
    ; g (103)
    db 0x00, 0x00, 0x7E, 0xC6, 0xC6, 0x7E, 0x06, 0x7C
    ; h (104)
    db 0xC0, 0xC0, 0xFC, 0xC6, 0xC6, 0xC6, 0xC6, 0x00
    ; i (105)
    db 0x18, 0x00, 0x38, 0x18, 0x18, 0x18, 0x3C, 0x00
    ; j (106)
    db 0x06, 0x00, 0x0E, 0x06, 0x06, 0x06, 0xC6, 0x7C
    ; k (107)
    db 0xC0, 0xC0, 0xCC, 0xD8, 0xF0, 0xD8, 0xCC, 0x00
    ; l (108)
    db 0x38, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00
    ; m (109)
    db 0x00, 0x00, 0xEC, 0xFE, 0xD6, 0xC6, 0xC6, 0x00
    ; n (110)
    db 0x00, 0x00, 0xFC, 0xC6, 0xC6, 0xC6, 0xC6, 0x00
    ; o (111)
    db 0x00, 0x00, 0x7C, 0xC6, 0xC6, 0xC6, 0x7C, 0x00
    ; p (112)
    db 0x00, 0x00, 0xFC, 0xC6, 0xC6, 0xFC, 0xC0, 0xC0
    ; q (113)
    db 0x00, 0x00, 0x7E, 0xC6, 0xC6, 0x7E, 0x06, 0x06
    ; r (114)
    db 0x00, 0x00, 0xDC, 0xE6, 0xC0, 0xC0, 0xC0, 0x00
    ; s (115)
    db 0x00, 0x00, 0x7E, 0xC0, 0x7C, 0x06, 0xFC, 0x00
    ; t (116)
    db 0x30, 0x30, 0x7C, 0x30, 0x30, 0x36, 0x1C, 0x00
    ; u (117)
    db 0x00, 0x00, 0xC6, 0xC6, 0xC6, 0xC6, 0x7E, 0x00
    ; v (118)
    db 0x00, 0x00, 0xC6, 0xC6, 0xC6, 0x6C, 0x38, 0x00
    ; w (119)
    db 0x00, 0x00, 0xC6, 0xC6, 0xD6, 0xFE, 0x6C, 0x00
    ; x (120)
    db 0x00, 0x00, 0xC6, 0x6C, 0x38, 0x6C, 0xC6, 0x00
    ; y (121)
    db 0x00, 0x00, 0xC6, 0xC6, 0xC6, 0x7E, 0x06, 0x7C
    ; z (122)
    db 0x00, 0x00, 0xFE, 0x0C, 0x38, 0x60, 0xFE, 0x00
    ; { (123)
    db 0x0E, 0x18, 0x18, 0x70, 0x18, 0x18, 0x0E, 0x00
    ; | (124)
    db 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00
    ; } (125)
    db 0x70, 0x18, 0x18, 0x0E, 0x18, 0x18, 0x70, 0x00
    ; ~ (126)
    db 0x76, 0xDC, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ; DEL (127) - empty
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

; IDT
align 16
idt64:          times 256 dq 0, 0

idt64_ptr:
    dw 256*16 - 1
    dq idt64

idt64_null:
    dw 0
    dq 0

; GDT with Ring 3 support
[BITS 32]
align 16
gdt64:
    dq 0                            ; 0x00: Null descriptor
    dq 0x00209A0000000000           ; 0x08: Kernel Code (Ring 0, DPL=0)
    dq 0x0000920000000000           ; 0x10: Kernel Data (Ring 0, DPL=0)
    dq 0x0020FA0000000000           ; 0x18: User Code (Ring 3, DPL=3)
    dq 0x0000F20000000000           ; 0x20: User Data (Ring 3, DPL=3)
    ; 0x28: TSS descriptor (16 bytes in 64-bit mode)
    dw 104                          ; Limit (size of TSS - 1)
    dw 0                            ; Base 15:0 (patched at runtime)
    db 0                            ; Base 23:16
    db 0x89                         ; Type: 64-bit TSS Available, DPL=0
    db 0x00                         ; Limit 19:16, flags
    db 0                            ; Base 31:24
    dd 0                            ; Base 63:32
    dd 0                            ; Reserved
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1
    dd gdt64

; Selectors for easy reference
KERNEL_CODE_SEL equ 0x08
KERNEL_DATA_SEL equ 0x10
USER_CODE_SEL   equ 0x18 | 3       ; 0x1B (Ring 3)
USER_DATA_SEL   equ 0x20 | 3       ; 0x23 (Ring 3)
TSS_SEL         equ 0x28

; ════════════════════════════════════════════════════════════════════════════
; TSS (Task State Segment) - Required for Ring 3 → Ring 0 transitions
; ════════════════════════════════════════════════════════════════════════════
align 16
tss64:
    dd 0                            ; Reserved
    dq 0x90000                      ; RSP0 - Kernel stack for interrupts
    dq 0                            ; RSP1
    dq 0                            ; RSP2
    dq 0                            ; Reserved
    dq 0                            ; IST1
    dq 0                            ; IST2
    dq 0                            ; IST3
    dq 0                            ; IST4
    dq 0                            ; IST5
    dq 0                            ; IST6
    dq 0                            ; IST7
    dq 0                            ; Reserved
    dw 0                            ; Reserved
    dw 104                          ; IOPB offset (no IOPB)
tss64_end:
