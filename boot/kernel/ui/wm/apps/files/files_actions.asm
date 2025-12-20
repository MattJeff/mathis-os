; FILES_ACTIONS.ASM - File operations
[BITS 64]

; WMF_CREATE_FOLDER - Open dialog to create new folder
wmf_create_folder:
    call wmf_dialog_open
    ret
