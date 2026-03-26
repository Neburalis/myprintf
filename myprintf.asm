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

; =============================================================================
; void puthex(uint64_t a);
; =============================================================================
; prints the number in hexadecimal to stdout using Linux write syscall.
;   rdi = number
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

; =============================================================================
; void putuint(uint64_t a);
; =============================================================================
; prints unsigned integer in decimal to stdout.
;   rdi = number
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

; =============================================================================
; void putint(int64_t a);
; =============================================================================
; prints signed integer in decimal to stdout.
;   rdi = number
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

section .data

Int64MinValue: db "9223372036854775808"
Int64MinValueLen equ $ - Int64MinValue

section .text

; =============================================================================
; void putoct(uint64_t a);
; =============================================================================
; prints number in octal to stdout.
;   rdi = number to print
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

; =============================================================================
; void putbin(uint64_t a);
; =============================================================================
; prints number in binary to stdout.
;   rdi = number
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

; =============================================================================
; void putchar(char a);
; =============================================================================
; prints one byte to stdout.
;   dil = ch to print
putchar:
    sub rsp, 16
    mov byte [rsp], dil
    write_no_pie 1, rsp, 1
    add rsp, 16
    ret

; =============================================================================
; void putstr(char* str);
; =============================================================================
; computes string length and writes entire string using one syscall.
;   rdi -> str
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

; =============================================================================
; JmpTable:
section .rodata
align 8

; Индекс: (*fmt - 'b')
; Диапазон: 'b'..'x'
jmp_table:
    dq printer.case_b        ; 'b'
    dq printer.case_c        ; 'c'
    dq printer.case_d        ; 'd'
    dq printer.case_default  ; 'e'
    dq printer.case_default  ; 'f'
    dq printer.case_default  ; 'g'
    dq printer.case_default  ; 'h'
    dq printer.case_default  ; 'i'
    dq printer.case_default  ; 'j'
    dq printer.case_default  ; 'k'
    dq printer.case_default  ; 'l'
    dq printer.case_default  ; 'm'
    dq printer.case_default  ; 'n'
    dq printer.case_o        ; 'o'
    dq printer.case_default  ; 'p'
    dq printer.case_default  ; 'q'
    dq printer.case_default  ; 'r'
    dq printer.case_s        ; 's'
    dq printer.case_default  ; 't'
    dq printer.case_u        ; 'u'
    dq printer.case_default  ; 'v'
    dq printer.case_default  ; 'w'
    dq printer.case_x        ; 'x'

section .text

; =============================================================================
; int32_t printer(char *fmt, uint8_t *ptr1, uint8_t *ptr2)
; =============================================================================
; calling convention:
;   rdi -> fmt
;   rsi -> ptr_to_arg1..5
;   rdx -> ptr_to_arg6...
;   who pushed - that popped (calling func need to pop all )
; Почему так?
; Для более удобного написания трамплина для вызова по ABI. Потому что первые 6 аргументов (без fmt получается 5)
; лежат в регистрах, а последующие в стеке (под адресом возврата). Поэтому трамплин пушит 5 аргументов в стек, и
; передает 2 указателя: на 1й аргумент (последний запушенный в стек) и на первый элемент стека трамплина
;
; Структура стека:
;                  ptr1                                                                   ptr2
;                   ↓                                                                      ↓
; | BP | RetAddr | %1 | %2 | %3 | %4 | %5 | aligning | chain jmp BP | chain jmp RetAddr | %6 | ...
;
; Псевдокод логики функции:
; int32_t printer(char *fmt, uint8_t *ptr1, uint8_t *ptr2) {
;
;     int32_t arg_count = 0;
;
;     while (*fmt != '\0') {
;         if (*fmt != '%') {
;             putchar(*fmt);
;             ++fmt;
;             continue;
;         }
;
;         ++fmt;
;
;         if (*fmt == '\0') {
;             // UB
;             break;
;         }
;
;         if (*fmt == '%') {
;             putchar('%');
;             ++fmt;
;             continue;
;         }
;
;         uint8_t *arg_ptr;
;         if (arg_count < 5)
;             arg_ptr = ptr1 + arg_count * 8;
;         else
;             arg_ptr = ptr2 + (arg_count - 5) * 8;
;
;         switch (*fmt) {
;             case 'b': putbin(*arg_ptr);  break;
;             case 'c': putchar(*arg_ptr); break;
;             case 'd': putint(*arg_ptr);  break;
;             case 'o': putoct(*arg_ptr);  break;
;             case 's': putstr(arg_ptr);   break;
;             case 'u': putuint(*arg_ptr); break;
;             case 'x': puthex(*arg_ptr);  break;
;             default:
;                 // UB
;                 break;
;         }
;
;         ++arg_count;
;         ++fmt;
;     }
; }
;
printer:
    push rbp
    mov  rbp, rsp

    ; используем callee-saved регистры
    push rbx
    push r12
    push r13
    push r14

    ; r12 = fmt
    ; r13 = ptr1
    ; r14 = ptr2
    ; ebx = arg_count
    mov  r12, rdi
    mov  r13, rsi
    mov  r14, rdx
    xor  ebx, ebx

.loop:
    ; while (*fmt != '\0')
    movzx rax, byte [r12]
    test  al, al
    je    .done

    ; if (*fmt != '%')
    cmp   al, '%'
    je    .percent

    ; putchar(*fmt)
    mov   rdi, rax
    call  putchar

    ; ++fmt
    inc   r12
    jmp   .loop

.percent:
    ; ++fmt
    inc   r12

    ; if (*fmt == '\0') // UB break;
    movzx rax, byte [r12]
    test  al, al
    je    .done

    ; if (*fmt == '%') { putchar('%'); ++fmt; continue; }
    cmp   al, '%'
    jne   .select_arg

    mov   rdi, '%'
    call  putchar
    inc   r12
    jmp   .loop

.select_arg:
    ; if (arg_count < 5)
    ;     arg_ptr = ptr1 + arg_count * 8;
    ; else
    ;     arg_ptr = ptr2 + (arg_count - 5) * 8;
    cmp   ebx, 5
    jl    .from_ptr1

    mov   rax, rbx
    sub   rax, 5
    shl   rax, 3
    lea   rdi, [r14 + rax]
    jmp   .dispatch

.from_ptr1:
    mov   rcx, rbx
    shl   rcx, 3
    lea   rdi, [r13 + rcx]

.dispatch:
    ; *fmt уже лежит в rax

    ; Нормализуем индекс: 'b' -> 0
    sub   rax, 'b'
    cmp   rax, ('x' - 'b')
    ja    .case_default

    mov   rax, [rel jmp_table + rax*8]
    jmp   rax

.case_b:
    ; putbin(arg_ptr)
    call  putbin
    jmp   .after_spec

.case_c:
    ; putchar(*arg_ptr)
    movzx edi, byte [rdi]
    call  putchar
    jmp   .after_spec

.case_d:
    ; putint(*arg_ptr)
    movzx rdi, byte [rdi]
    call  putint
    jmp   .after_spec

.case_o:
    ; putoct(*arg_ptr)
    movzx rdi, byte [rdi]
    call  putoct
    jmp   .after_spec

.case_s:
    ; putstr(arg_ptr)
    call  putstr
    jmp   .after_spec

.case_u:
    ; putuint(*arg_ptr)
    movzx rdi, byte [rdi]
    call  putuint
    jmp   .after_spec

.case_x:
    ; puthex(*arg_ptr)
    movzx rdi, byte [rdi]
    call  puthex
    jmp   .after_spec

.case_default:
    ; UB -> просто выходим
    jmp   .done

.after_spec:
    ; ++arg_count
    inc   ebx

    ; ++fmt
    inc   r12
    jmp   .loop

.done:
    xor   rax, rax

    pop   r14
    pop   r13
    pop   r12
    pop   rbx
    pop   rbp
    ret

; ============= Program entry ================================================
_start:

    push 12345
    mov rsi, rsp

    ; mov rdi, [rsi]
    ; call putint

    lea rdi, [rel TestFMT]
    call printer

    mov rdi, 0x0A
    call putchar

    exit         0

section .data

TestPutstr: db "putstr test", 0x0A, 0
TestFMT:    db "Hello, World!", 0x0A, "%d", 0x0A, 0