%macro write_no_pie 3
    mov     eax, 1      ; write
    mov     rdi, %1     ; fd
    mov     rsi, %2     ; buf
    mov     rdx, %3     ; len
    syscall
%endmacro

%macro write 3
    mov     eax, 1          ; write
    mov     rdi, %1         ; fd
    lea     rsi, [rel %2]   ; buf
    mov     rdx, %3         ; len
    syscall
%endmacro

%macro exit 1
    mov     eax, 60     ; exit
    mov     edi, %1     ; status
    syscall
%endmacro