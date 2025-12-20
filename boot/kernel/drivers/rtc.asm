; ============================================================================
; RTC.ASM - Real Time Clock driver (CMOS)
; ============================================================================
; Single Responsibility: Read time from hardware RTC
; ============================================================================

[BITS 64]

; CMOS ports
RTC_INDEX_PORT      equ 0x70
RTC_DATA_PORT       equ 0x71

; RTC registers
RTC_REG_SECONDS     equ 0x00
RTC_REG_MINUTES     equ 0x02
RTC_REG_HOURS       equ 0x04
RTC_REG_STATUS_A    equ 0x0A

; Cached time values
rtc_hours:          db 0
rtc_minutes:        db 0
rtc_seconds:        db 0
rtc_last_tick:      dq 0

; ============================================================================
; RTC_READ_TIME - Read current time from CMOS RTC
; Updates: rtc_hours, rtc_minutes, rtc_seconds
; ============================================================================
rtc_read_time:
    push rax
    push rdx

    ; Wait for update to complete (bit 7 of status A)
.wait_update:
    mov al, RTC_REG_STATUS_A
    out RTC_INDEX_PORT, al
    in al, RTC_DATA_PORT
    test al, 0x80
    jnz .wait_update

    ; Read seconds (BCD)
    mov al, RTC_REG_SECONDS
    out RTC_INDEX_PORT, al
    in al, RTC_DATA_PORT
    call rtc_bcd_to_bin
    mov [rtc_seconds], al

    ; Read minutes (BCD)
    mov al, RTC_REG_MINUTES
    out RTC_INDEX_PORT, al
    in al, RTC_DATA_PORT
    call rtc_bcd_to_bin
    mov [rtc_minutes], al

    ; Read hours (BCD)
    mov al, RTC_REG_HOURS
    out RTC_INDEX_PORT, al
    in al, RTC_DATA_PORT
    call rtc_bcd_to_bin
    mov [rtc_hours], al

    pop rdx
    pop rax
    ret

; ============================================================================
; RTC_BCD_TO_BIN - Convert BCD to binary
; Input: AL = BCD value
; Output: AL = binary value
; ============================================================================
rtc_bcd_to_bin:
    push rbx
    mov bl, al
    shr al, 4               ; High nibble (tens)
    mov ah, 10
    mul ah                  ; AL = tens * 10
    and bl, 0x0F            ; Low nibble (ones)
    add al, bl              ; AL = tens*10 + ones
    pop rbx
    ret

; ============================================================================
; RTC_GET_HOURS - Get current hours
; Output: AL = hours (0-23)
; ============================================================================
rtc_get_hours:
    mov al, [rtc_hours]
    ret

; ============================================================================
; RTC_GET_MINUTES - Get current minutes
; Output: AL = minutes (0-59)
; ============================================================================
rtc_get_minutes:
    mov al, [rtc_minutes]
    ret

; ============================================================================
; RTC_GET_SECONDS - Get current seconds
; Output: AL = seconds (0-59)
; ============================================================================
rtc_get_seconds:
    mov al, [rtc_seconds]
    ret
