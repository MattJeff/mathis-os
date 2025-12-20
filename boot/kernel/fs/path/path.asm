; ============================================================================
; PATH.ASM - Path parsing module (main include)
; ============================================================================

[BITS 64]

; Constants (equ only, no data)
PATH_MAX_SEGMENTS   equ 8           ; Max depth: /a/b/c/d/e/f/g/h
PATH_SEG_SIZE       equ 12          ; 11 chars (8.3) + null

; Code first (explicitly in text section)
section .text

%include "fs/path/path_parse.asm"
%include "fs/path/path_resolve.asm"

; Data after code
%include "fs/path/path_data.asm"
