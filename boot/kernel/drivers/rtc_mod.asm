; ============================================================================
; RTC_MOD.ASM - Real Time Clock Driver
; ============================================================================
; Read time from CMOS RTC
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
CMOS_ADDR               equ 0x70
CMOS_DATA               equ 0x71
RTC_SECONDS             equ 0x00
RTC_MINUTES             equ 0x02
RTC_HOURS               equ 0x04
RTC_DAY                 equ 0x07
RTC_MONTH               equ 0x08
RTC_YEAR                equ 0x09

; ============================================================================
; EXPORTS
; ============================================================================
global rtc_get_time
global rtc_hours
global rtc_minutes
global rtc_seconds

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; rtc_get_time - Read current time from RTC
; Output: Updates rtc_hours, rtc_minutes, rtc_seconds
; ----------------------------------------------------------------------------
rtc_get_time:
    push rax
    push rdx

    ; Read seconds
    mov al, RTC_SECONDS
    out CMOS_ADDR, al
    in al, CMOS_DATA
    call .bcd_to_bin
    mov [rtc_seconds], al

    ; Read minutes
    mov al, RTC_MINUTES
    out CMOS_ADDR, al
    in al, CMOS_DATA
    call .bcd_to_bin
    mov [rtc_minutes], al

    ; Read hours
    mov al, RTC_HOURS
    out CMOS_ADDR, al
    in al, CMOS_DATA
    call .bcd_to_bin
    mov [rtc_hours], al

    pop rdx
    pop rax
    ret

; Convert BCD to binary (AL = BCD value)
.bcd_to_bin:
    push rbx
    mov bl, al
    and al, 0x0F            ; Low nibble
    shr bl, 4               ; High nibble
    imul ebx, ebx, 10       ; High nibble * 10
    add al, bl
    pop rbx
    ret

; ============================================================================
; DATA
; ============================================================================
section .data

rtc_hours:              db 0
rtc_minutes:            db 0
rtc_seconds:            db 0
