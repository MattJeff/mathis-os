; ════════════════════════════════════════════════════════════════════════════
; FS_EVENTS.ASM - Filesystem Event System (main include)
; ════════════════════════════════════════════════════════════════════════════
; Provides event-driven sync between desktop and files mode
;
; Usage:
;   1. Register listener: mov rdi, my_callback / call fs_evt_register
;   2. Emit event: mov dil, FS_EVT_CREATE / mov sil, FS_EVT_FLAG_FILE
;                  lea rdx, [path] / xor ecx, ecx / call fs_evt_emit
;   3. Process in main loop: call fs_evt_process
;
; Callback signature: my_callback(rdi = pointer to FS_EVENT)
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

%include "fs/events/fs_event_types.asm"
%include "fs/events/fs_event_queue.asm"
%include "fs/events/fs_event_dispatch.asm"
