; =============================================================================
; myprintf.asm  - minimal demo for syscall-based printing and exit
; =============================================================================

section .text
    global _start
    global puthex
    global putint
    global putuint
    global putoct
    global putbin
    global putchar
    global putstr
    %include "linux64_macro.asm"

; void puthex(uint64_t a);
;   prints the number in hexadecimal to stdout using Linux write syscall.
puthex:
    sub rsp, 24
    mov rdx, rdi
    lea rsi, [rsp+23]
    xor r9d, r9d

    test rdx, rdx
    jnz .convert

    dec rsi
    mov byte [rsi], '0'
    inc r9
    jmp .emit

.convert:
    mov al, dl
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .digit_ready
    add al, 7

.digit_ready:
    dec rsi
    mov byte [rsi], al
    inc r9

    shr rdx, 4
    test rdx, rdx
    jne .convert

.emit:
    write_no_pie 1, rsi, r9

    add rsp, 24
    ret

; void putuint(uint64_t a);
;   prints unsigned integer in decimal to stdout.
putuint:
    sub rsp, 40
    mov rax, rdi
    lea rsi, [rsp+39]
    xor rcx, rcx

    test rax, rax
    jnz .convert

    dec rsi
    mov byte [rsi], '0'
    inc rcx
    jmp .emit

.convert:
    mov rbx, 10

.zaloop:
    xor edx, edx
    div rbx
    add dl, '0'

    dec rsi
    mov byte [rsi], dl
    inc rcx

    test rax, rax
    jnz .zaloop

.emit:
    write_no_pie 1, rsi, rcx

    add rsp, 40
    ret

; void putint(int64_t a);
;   prints signed integer in decimal to stdout.
putint:
    sub rsp, 24
    test rdi, rdi
    jns .putint_positive

    mov byte [rsp+23], '-'
    lea rsi, [rsp+23]
    write_no_pie 1, rsi, 1

    neg rdi
    jo .putint_min
    jmp .putint_positive

.putint_positive:
    call putuint
    add rsp, 24
    ret

.putint_min:
    write 1, Int64MinValue, Int64MinValueLen
    add rsp, 24
    ret

; void putoct(uint64_t a);
;   prints number in octal to stdout.
putoct:
    sub rsp, 40
    mov rax, rdi
    lea rsi, [rsp+39]
    xor rcx, rcx

    test rax, rax
    jnz .zaloop

    dec rsi
    mov byte [rsi], '0'
    inc rcx
    jmp .emit

.zaloop:
    mov rdx, rax
    and rdx, 7
    add dl, '0'

    dec rsi
    mov byte [rsi], dl
    inc rcx

    shr rax, 3
    test rax, rax
    jnz .zaloop

.emit:
    write_no_pie 1, rsi, rcx

    add rsp, 40
    ret

; void putbin(uint64_t a);
;   prints number in binary to stdout.
putbin:
    sub rsp, 80
    mov rax, rdi
    lea rsi, [rsp+79]
    xor rcx, rcx

    test rax, rax
    jnz .bin_loop

    dec rsi
    mov byte [rsi], '0'
    inc rcx
    jmp .bin_emit

.bin_loop:
    mov rdx, rax
    and rdx, 1
    add dl, '0'

    dec rsi
    mov byte [rsi], dl
    inc rcx

    shr rax, 1
    test rax, rax
    jnz .bin_loop

.bin_emit:
    write_no_pie 1, rsi, rcx

    add rsp, 80
    ret

; void putchar(char a);
;   prints one byte to stdout.
putchar:
    sub rsp, 16
    mov byte [rsp], dil
    write_no_pie 1, rsp, 1
    add rsp, 16
    ret

; void putstr(char* str);
;   computes string length and writes entire string using one syscall.
putstr:
    test rdi, rdi
    jz .empty
    mov rsi, rdi
    xor rcx, rcx

.len_loop:
    cmp byte [rsi + rcx], 0
    je .len_done
    inc rcx
    jmp .len_loop

.len_done:
    test rcx, rcx
    jz .empty
    write_no_pie 1, rdi, rcx

.empty:
    ret

; ============= Program entry ================================================
_start:
    write_no_pie 1, Msg, MsgLen
    
    mov rdi, 'C'
    call putchar

    mov rdi, 0x0A
    call putchar

    mov rdi, TestPutstr
    call putstr

    mov rdi, 0ABCh
    call puthex

    mov rdi, 0x0A
    call putchar

    exit         0

section .data

Msg:    db "__Hllwrld", 0x0a
MsgLen  equ $ - Msg
TestPutstr: db "putstr test", 0x0A, 0
Int64MinValue: db "9223372036854775808"
Int64MinValueLen equ $ - Int64MinValue
