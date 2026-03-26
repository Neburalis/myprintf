; =============================================================================
; linux64_macro.asm - Linux x86-64 syscall helpers
; =============================================================================

; ============= write_no_pie =================================================
;
; Function:
;   write_no_pie fd, buf, len
;
; Purpose:
;   Execute Linux write(2) with buffer passed as a plain address expression.
;   For PIC-sensitive code when caller already provides an absolute address.
;
; IN:
;   %1 = file descriptor (integer)
;   %2 = buffer address
;   %3 = buffer size in bytes
; EXP:
;   Performs syscall with SYS_write (rax=1)
; DESTR:
;   EAX, EDI, RSI, RDX
;
%macro write_no_pie 3
    mov     eax, 1          ; write
    %ifnidni %1, edi
        mov     edi, %1     ; fd
    %endif
    %ifnidni %2, rsi
        mov     rsi, %2     ; buf
    %endif
    %ifnidni %3, rdx
        mov     rdx, %3     ; len
    %endif
    syscall
%endmacro

; ============= write ========================================================
;
; Function:
;   write fd, rel_label, len
;
; Purpose:
;   Execute Linux write(2) with RIP-relative LEA for position-independent
;   code. Suitable for labels in the same translation unit.
;
; IN:
;   %1 = file descriptor (integer)
;   %2 = label/reference in the current section
;   %3 = buffer size in bytes
; EXP:
;   Performs syscall with SYS_write (rax=1)
; DESTR:
;   EAX, EDI, RSI, RDX
;
%macro write 3
    mov     eax, 1          ; write
    %ifnidni %1, edi
        mov     edi, %1     ; fd
    %endif
    lea     rsi, [rel %2]   ; buf
    %ifnidni %3, rdx
        mov     rdx, %3     ; len
    %endif
    syscall
%endmacro

; ============= exit =========================================================
;
; Function:
;   exit status
;
; Purpose:
;   Execute Linux exit(2) with provided status code.
;
; IN:
;   %1 = exit status
; EXP:
;   Performs syscall with SYS_exit (rax=60)
; DESTR:
;   EAX, EDI
;
%macro exit 1
    mov     eax, 60       ; exit
    %ifnidni %1, edi
        mov     edi, %1   ; status
    %endif
    syscall
%endmacro
