; ============================================================================
; PATH_DATA.ASM - Path parsing buffers
; ============================================================================

[BITS 64]

; Parsed segments buffer (8 segments * 12 bytes = 96 bytes)
path_segments:      times (PATH_MAX_SEGMENTS * PATH_SEG_SIZE) db 0
path_segment_count: dd 0

; Temp buffer for name conversion
path_temp_name:     times 12 db 0
