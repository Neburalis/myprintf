; =============================================================================
; myprintf.asm  - minimal demo for syscall-based printing and exit
; =============================================================================

default rel

section .text
    global putbase
    global puthex
    global putint
    global putuint
    global putoct
    global putbin
    global putchar
    global putstr
    global printer

    %include "linux64_macro.asm"

; =============================================================================
; void putbase(uint64_t n, uint64_t base)
; =============================================================================
; prints number in given base to stdout (supports bases 2–36).
;
; IN:
;   rdi = n    (number to print)
;   rsi = base (2..36; values > 36 are silently ignored)
; OUT:
;   eax = number of bytes written (0 if base > 36)
; DESTR:
;   rax, rcx, rdx, rdi, rsi
putbase:
    push rbx
    sub  rsp, 80
    mov  rax, rdi
    cmp  rsi, 36
    ja  .early_exit
    mov  rbx, rsi
    lea  rsi, [rsp+79]
    xor  rcx, rcx

    test rax, rax
    jnz  .convert

    dec  rsi
    mov  byte [rsi], '0'
    inc  rcx
    jmp  .emit

.convert:
    xor  edx, edx
    div  rbx
    cmp  dl, 10
    jl   .decimal
    add  dl, 'a' - 10
    jmp  .store
.decimal:
    add  dl, '0'
.store:
    dec  rsi
    mov  byte [rsi], dl
    inc  rcx
    test rax, rax
    jnz  .convert

.emit:
    write 1, rsi, rcx
    mov  eax, edx          ; rdx = rcx (set by write macro), survives syscall
    jmp  .epilogue

.early_exit:
    xor  eax, eax          ; invalid base — nothing printed

.epilogue:
    add  rsp, 80
    pop  rbx
    ret

; =============================================================================
; void puthex(uint64_t a)
; =============================================================================
; prints number in hexadecimal (lowercase) to stdout.
;
; IN:
;   rdi = a (number to print)
; OUT:
;   eax = number of bytes written
; DESTR:
;   rax, rcx, rdx, rdi, rsi
puthex:
    mov  rsi, 16
    jmp  putbase

; =============================================================================
; void putuint(uint64_t a)
; =============================================================================
; prints unsigned integer in decimal to stdout.
;
; IN:
;   rdi = a (number to print)
; OUT:
;   eax = number of bytes written
; DESTR:
;   rax, rcx, rdx, rdi, rsi
putuint:
push rbx
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
    write 1, rsi, rcx
    mov  eax, edx          ; rdx = rcx (set by write macro), survives syscall

    add rsp, 40
    pop rbx
    ret

; =============================================================================
; void putint(int64_t a)
; =============================================================================
; prints signed integer in decimal to stdout.
;
; IN:
;   rdi = a (number to print)
; OUT:
;   eax = number of bytes written (digits + 1 for '-' if negative)
; DESTR:
;   rax, rcx, rdx, rdi, rsi
putint:
    sub rsp, 24
    test rdi, rdi
    jns .putint_positive

    mov byte [rsp+23], '-'
    lea rsi, [rsp+23]
    push rdi
    write 1, rsi, 1
    pop rdi

    neg rdi

    call putuint
    inc  eax               ; +1 for the '-' sign
    add rsp, 24
    ret

.putint_positive:
    call putuint           ; eax = digit count
    add rsp, 24
    ret

; =============================================================================
; void putoct(uint64_t a)
; =============================================================================
; prints number in octal to stdout.
;
; IN:
;   rdi = a (number to print)
; OUT:
;   eax = number of bytes written
; DESTR:
;   rax, rcx, rdx, rdi, rsi
putoct:
    mov  rsi, 8
    jmp  putbase

; =============================================================================
; void putbin(uint64_t a)
; =============================================================================
; prints number in binary to stdout.
;
; IN:
;   rdi = a (number to print)
; OUT:
;   eax = number of bytes written
; DESTR:
;   rax, rcx, rdx, rdi, rsi
putbin:
    mov  rsi, 2
    jmp  putbase

; =============================================================================
; void putchar(char a)
; =============================================================================
; prints one byte to stdout.
;
; IN:
;   dil = a (character to print)
; OUT:
;   eax = 1 (always one byte)
; DESTR:
;   rax, rdi, rsi, rdx
putchar:
    sub rsp, 16
    mov byte [rsp], dil
    write 1, rsp, 1
    mov  eax, 1
    add rsp, 16
    ret

; =============================================================================
; void putstr(char* str)
; =============================================================================
; computes string length and writes entire string using one syscall.
;
; IN:
;   rdi = str (pointer to null-terminated string; NULL is treated as empty)
; OUT:
;   eax = number of bytes written (0 for NULL or empty string)
; DESTR:
;   rax, rcx, rdi, rsi, rdx
putstr:
    xor  eax, eax
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
    write 1, rsi, rcx
    mov  eax, edx          ; rdx = rcx (set by write macro), survives syscall

.empty:
    ret

; =============================================================================
; JmpTable:
section .rodata
align 8

; Индекс: (*fmt - 'b')
; Диапазон: 'b'..'x'
jmp_table:
    dq printer.internal.case_b       - jmp_table ; 'b'
    dq printer.internal.case_c       - jmp_table ; 'c'
    dq printer.internal.case_d       - jmp_table ; 'd'
    dq printer.internal.case_default - jmp_table ; 'e'
    dq printer.internal.case_default - jmp_table ; 'f'
    dq printer.internal.case_default - jmp_table ; 'g'
    dq printer.internal.case_default - jmp_table ; 'h'
    dq printer.internal.case_default - jmp_table ; 'i'
    dq printer.internal.case_default - jmp_table ; 'j'
    dq printer.internal.case_default - jmp_table ; 'k'
    dq printer.internal.case_default - jmp_table ; 'l'
    dq printer.internal.case_default - jmp_table ; 'm'
    dq printer.internal.case_default - jmp_table ; 'n'
    dq printer.internal.case_o       - jmp_table ; 'o'
    dq printer.internal.case_default - jmp_table ; 'p'
    dq printer.internal.case_default - jmp_table ; 'q'
    dq printer.internal.case_default - jmp_table ; 'r'
    dq printer.internal.case_s       - jmp_table ; 's'
    dq printer.internal.case_default - jmp_table ; 't'
    dq printer.internal.case_u       - jmp_table ; 'u'
    dq printer.internal.case_default - jmp_table ; 'v'
    dq printer.internal.case_default - jmp_table ; 'w'
    dq printer.internal.case_x       - jmp_table ; 'x'

section .text

; =============================================================================
; int32_t printer(char *fmt, ...)
; =============================================================================
; SysV x86-64 ABI trampoline: spills register args to stack and delegates to
; printer.internal.
;
; IN:
;   rdi = fmt  (format string pointer)
;   rsi = arg1
;   rdx = arg2
;   rcx = arg3
;   r8  = arg4
;   r9  = arg5
;   [rbp+16].. = arg6+ (already on caller stack)
; OUT:
;   eax = total bytes written
; DESTR:
;   rax, rcx, rdx, rsi, r8, r9
;
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
    ; SysV x86-64 ABI trampoline for C: printer(fmt, ...)
    ; rdi  - fmt
    ; rsi  - 1st arg
    ; rdx  - 2nd arg
    ; rcx  - 3rd arg
    ; r8   - 4th arg
    ; r9   - 5th arg
    ; 6th+ continue in caller stack at [rbp+16] after call/ret address
    push rbp
    mov  rbp, rsp
    sub  rsp, 48

    mov  [rsp],    rsi
    mov  [rsp+8],  rdx
    mov  [rsp+16], rcx
    mov  [rsp+24], r8
    mov  [rsp+32], r9

    lea  rsi, [rsp]
    lea  rdx, [rbp+16]
    call printer.internal

    add  rsp, 48
    pop  rbp
    ret

; =============================================================================
; int32_t printer.internal(char *fmt, uint8_t *ptr1, uint8_t *ptr2)
; =============================================================================
; core format-string loop; called directly by printer trampoline.
;
; IN:
;   rdi = fmt  (pointer to format string)
;   rsi = ptr1 (pointer to args 1–5 on stack, each 8 bytes)
;   rdx = ptr2 (pointer to args 6+ on caller stack)
; OUT:
;   eax = total bytes written
; DESTR:
;   rax, rcx, rdi, rsi, rdx
; USE (local variables):
;   rbp - frame pointer
;   r12 - fmt
;   r13 - ptr1
;   r14 - ptr2
;   rbx - arg_count
;   rax - *fmt ; jmp addr
;   rcx - tmp
;   rdi - arg_ptr ; func input
;
printer.internal:
    push rbp
    mov  rbp, rsp

    ; используем callee-saved регистры
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; r12 = fmt
    ; r13 = ptr1
    ; r14 = ptr2
    ; ebx = arg_count
    ; r15d = bytes written
    mov  r12, rdi
    mov  r13, rsi
    mov  r14, rdx
    xor  ebx, ebx
    xor  r15d, r15d

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
    add   r15d, eax

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
    add   r15d, eax
    inc   r12
    jmp   .loop

.select_arg:
    ; if (arg_count < 5)
    ;     arg_ptr = ptr1 + arg_count * 8;
    ; else
    ;     arg_ptr = ptr2 + (arg_count - 5) * 8;
    cmp   ebx, 5
    jl    .from_ptr1

; .from_ptr2
    ; rcx = (arg_count - 5) * 8
    mov   rcx, rbx
    sub   rcx, 5
    shl   rcx, 3
    ; rdi = ptr2 + rcx = ptr2 + (arg_count - 5) * 8
    lea   rdi, [r14 + rcx]
    jmp   .dispatch

.from_ptr1:
    mov   rcx, rbx
    shl   rcx, 3
    lea   rdi, [r13 + rcx]

.dispatch:
    ; *fmt уже лежит в rax

    ; Нормализуем индекс: 'b' -> 0
    sub   rax, 'b'
    cmp   rax, ('x' - 'b') ; JT - диапазон 'b' - 'x'
    ja    .case_default

                                ; qword* jmp_table = {labels};
    lea   rdx, [rel jmp_table]  ; rdx = jmp_table
    mov   rax, [rdx + rax*8]    ; rax = *(jmp_table + label) = label - jmp_table
    add   rax, rdx              ; rax = rdx - jmp_table + (label - jmp_table) = label
    jmp   rax

.case_b:
    ; putbin(*arg_ptr)
    mov   rdi, [rdi]
    call  putbin
    jmp   .after_spec

.case_c:
    ; putchar(*arg_ptr)
    movzx edi, byte [rdi]
    call  putchar
    jmp   .after_spec

.case_d:
    ; putint(*arg_ptr)
    mov   rdi, [rdi]
    call  putint
    jmp   .after_spec

.case_o:
    ; putoct(*arg_ptr)
    mov   rdi, [rdi]
    call  putoct
    jmp   .after_spec

.case_s:
    ; putstr(arg_ptr)
    mov   rdi, [rdi]
    call  putstr
    jmp   .after_spec

.case_u:
    ; putuint(*arg_ptr)
    mov   rdi, [rdi]
    call  putuint
    jmp   .after_spec

.case_x:
    ; puthex(*arg_ptr)
    mov   rdi, [rdi]
    call  puthex
    jmp   .after_spec

.case_default:
    ; ERROR !
    ; //TODO -  Error handing
    ; UB -> просто выходим
    jmp   .done

.after_spec:
    add   r15d, eax        ; accumulate bytes from the last put* call

    ; ++arg_count
    inc   ebx

    ; ++fmt
    inc   r12
    jmp   .loop

.done:
    mov   eax, r15d        ; return total bytes written

    pop   r15
    pop   r14
    pop   r13
    pop   r12
    pop   rbx
    pop   rbp
    ret

; ============= Program entry ================================================
_start:

    lea rdi, [rel Message]
    push rdi
    push qword -1
    mov rsi, rsp

    ; mov rdi, [rsi]
    ; call putint

    lea rdi, [rel TestFMT]
    call printer.internal

    mov rdi, 0x0A
    call putchar

    exit         0

section .data

Message:    db "putstr test", 0x0A, 0
TestFMT:    db "%%", 0x0A, "%d", 0x0A, "%s", 0x0A, 0
