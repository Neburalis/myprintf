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

    extern printf

    %include "linux64_macro.asm"

struc buf
    .string     resq 1 ; char*
    .capacity   resd 1 ; uint32_t
    .size       resd 1 ; uint32_t
endstruc

TMP_BUF_SIZE equ 80

; =============================================================================
; void putbase(uint64_t n, uint8_t shift, uint8_t mask)
; =============================================================================
; prints number in base 2^shift to stdout (supports bases 2, 4, 8, 16, 32).
;
; IN:
;   rdi = n     (number to print)
;   rsi -> buf  (end of print buffer. Should be no less than TMP_BUF_SIZE)
;   dl  = mask  (base - 1)
;   cl  = shift (1..5 corresponds base 2, 4, 8, 16, 32)
; OUT:
;   eax = number of bytes written
;   rsi -> start of string (buf filled from end)
; DESTR:
;   rax, rcx, rdx, rdi, rsi
putbase:
    push    rbx
    ; sub     rsp, 80                 ; char buf[80] = {};

    mov     r9, rdi                 ; r9  = n
    movzx   r8d, dl                 ; r8d = mask
    lea     r10, [rel .digits_lut]  ; r10 = LUT
    ; lea     rsi, [rsp+79]           ; rsi = &buf[79]; // Пишем с конца
    xor     eax, eax                ; eax = 0 // counter

    test    r9, r9
    jnz     .convert

    mov     byte [rsi], '0'
    mov     al, 1
    jmp     .emit

.convert:
    mov     edx, r9d
    and     edx, r8d                ; Получили очередную цифру (0..31)
    shr     r9,  cl                 ; r9 /= 2^shift

    movzx   edx, byte [r10 + rdx]   ; Получаем символ из LUT
    dec     rsi                     ;
    mov    [rsi], dl                ; buf[--rsi] = dl
    inc     eax                     ; ++counter

    test r9, r9
    jnz .convert

.emit:
    ; mov     rcx, rax
    ; write   1, rsi, rcx

    ; add     rsp, 80
    pop     rbx
    ret

section .rodata align=64
.digits_lut:
    db "0123456789ABCDEF"   ; 32 символа для base 2..32

section .text

; =============================================================================
; void puthex(uint64_t a)
; =============================================================================
; prints number in hexadecimal (lowercase) to stdout.
;
; IN:
;   rdi = a (number to print)
;   rsi -> buf  (end of print buffer. Should be no less than TMP_BUF_SIZE)
; OUT:
;   eax = number of bytes written
;   rsi -> start of string (buf filled from end)
; DESTR:
;   rax, rcx, rdx, rdi, rsi
puthex:
    mov  cl, 4
    mov  dl, 0xF
    jmp  putbase

; =============================================================================
; void putoct(uint64_t a)
; =============================================================================
; prints number in octal to stdout.
;
; IN:
;   rdi = a (number to print)
;   rsi -> buf  (end of print buffer. Should be no less than TMP_BUF_SIZE)
; OUT:
;   eax = number of bytes written
;   rsi -> start of string (buf filled from end)
; DESTR:
;   rax, rcx, rdx, rdi, rsi
putoct:
    mov  cl, 3
    mov  dl, 7
    jmp  putbase

; =============================================================================
; void putbin(uint64_t a)
; =============================================================================
; prints number in binary to stdout.
;
; IN:
;   rdi = a (number to print)
;   rsi -> buf  (end of print buffer. Should be no less than TMP_BUF_SIZE)
; OUT:
;   eax = number of bytes written
;   rsi -> start of string (buf filled from end)
; DESTR:
;   rax, rcx, rdx, rdi, rsi
putbin:
    mov  cl, 1
    mov  dl, 1
    jmp  putbase


; =============================================================================
; void putuint(uint64_t a)
; =============================================================================
; prints unsigned integer in decimal to stdout.
;
; IN:
;   rdi = a (number to print)
;   rsi -> buf  (end of print buffer. Should be no less than TMP_BUF_SIZE)
; OUT:
;   eax = number of bytes written
;   rsi -> start of string (buf filled from end)
; DESTR:
;   rax, rcx, rdx, rdi, rsi
putuint:
push rbx
    ; sub rsp, 80
    mov rax, rdi
    ; lea rsi, [rsp+39]
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
    ; write 1, rsi, rcx
    mov  eax, ecx          ; ecx = digit count

    ; add rsp, 80
    pop rbx
    ret

; =============================================================================
; void putint(int64_t a)
; =============================================================================
; prints signed integer in decimal to stdout.
;
; IN:
;   rdi = a (number to print)
;   rsi -> buf  (end of print buffer. Should be no less than TMP_BUF_SIZE)
; OUT:
;   eax = number of bytes written (digits + 1 for '-' if negative)
;   rsi -> start of string (buf filled from end)
; DESTR:
;   rax, rcx, rdx, rdi, rsi
putint:
    ; sub rsp, 80
    test rdi, rdi
    jns .putint_positive

    ; mov byte [rsp+23], '-'
    ; lea rsi, [rsp+23]
    ; push rdi
    ; write 1, rsi, 1
    ; pop rdi

    neg rdi

    call putuint
    inc  eax               ; +1 for the '-' sign
    dec  rsi
    mov  byte [rsi], '-'
    ; add rsp, 80
    ret

.putint_positive:
    call putuint           ; eax = digit count ; rsi -> start of string
    ; add rsp, 80
    ret

; =============================================================================
; void putchar(char a)
; =============================================================================
; prints one byte to stdout.
;
; IN:
;   dil = a (character to print)
;   rsi -> buf  (end of print buffer. Should be no less than TMP_BUF_SIZE)
; OUT:
;   eax = 1 (always one byte)
;   rsi -> start of string (buf filled from end)
; DESTR:
;   rax, rdi, rsi, rdx
putchar:
    ; sub rsp, 80
    mov byte [rsi], dil
    ; write 1, rsp, 1
    mov  eax, 1
    dec  rsi
    ; add rsp, 80
    ret

; =============================================================================
; void putstr(char* str)
; =============================================================================
; computes string length; does NOT write — caller is responsible for the write.
;
; IN:
;   rdi = str (pointer to null-terminated string; NULL is treated as empty)
; OUT:
;   eax = string length (0 for NULL or empty string)
;   rsi -> start of string
; DESTR:
;   rax, rcx, rsi
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
    mov  eax, ecx

.empty:
    ret

; =============================================================================
; JmpTable:
section .data
align 8

; Индекс: (*fmt - 'b')
; Диапазон: 'b'..'x'
jmp_table:
    dq printer.internal.case_b       ; 'b'
    dq printer.internal.case_c       ; 'c'
    dq printer.internal.case_d       ; 'd'
    times ('o' - 'd' - 1) dq printer.internal.case_default
    dq printer.internal.case_o       ; 'o'
    times ('s' - 'o' - 1) dq printer.internal.case_default
    dq printer.internal.case_s       ; 's'
    dq printer.internal.case_default ; 't'
    dq printer.internal.case_u       ; 'u'
    times ('x' - 'u' - 1) dq printer.internal.case_default
    dq printer.internal.case_x       ; 'x'

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
    sub  rsp, 64

    mov  [rsp],    rsi
    mov  [rsp+8],  rdx
    mov  [rsp+16], rcx
    mov  [rsp+24], r8
    mov  [rsp+32], r9
    mov  [rsp+40], rdi

    lea  rsi, [rsp]
    lea  rdx, [rbp+16]
    call printer.internal

    mov  rsi, [rsp]
    mov  rdx, [rsp+8]
    mov  rcx, [rsp+16]
    mov  r8,  [rsp+24]
    mov  r9,  [rsp+32]
    mov  rdi, [rsp+40]
    add  rsp, 64
    pop  rbp

    jmp printf wrt ..plt

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
    ; mov   rdi, rax
    ; sub   rsp, TMP_BUF_SIZE
    ; lea   rsi, [rsp+TMP_BUF_SIZE-1]
    ; mov
    ; call  putchar
    ; mov   rcx, rax
    ; write 1, rsi, rcx
    ; mov   rax, rdx
    ; add   rsp, TMP_BUF_SIZE
    sub   rsp, 1
    mov  [rsp], al
    write_no_pie 1, rsp, 1
    add   rsp, 1
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

    ; mov   rdi, '%'
    ; sub   rsp, TMP_BUF_SIZE
    ; lea   rsi, [rsp+TMP_BUF_SIZE-1]
    ; call  putchar
    ; mov   rcx, rax
    ; write 1, rsi, rcx
    ; mov   rax, rdx
    ; add   rsp, TMP_BUF_SIZE
    sub   rsp, 1
    mov  [rsp], al
    write_no_pie 1, rsp, 1
    add   rsp, 1
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
    ; sub   rax, 'b'
    ; cmp   rax, ('x' - 'b') ; JT - диапазон 'b' - 'x'
    ; ja    .case_default

    cmp     rax, 'b'
    jb      .case_default
    cmp     rax, 'x'
    ja      .case_default

    lea     rdx, [rel jmp_table]
    jmp     [rdx + (rax - 'b') * 8]

                                ; qword* jmp_table = {labels};
    ; lea   rdx, [rel jmp_table]  ; rdx = jmp_table
    ; mov   rax, [rdx + rax*8]    ; rax = *(jmp_table + label) = label - jmp_table
    ; add   rax, rdx              ; rax = rdx - jmp_table + (label - jmp_table) = label
    ; jmp   rax

    ; lea   rdx, [rel jmp_table]
    ; jmp   [rdx + rax*8]        ; читаем абсолютный адрес из таблицы и прыгаем

.case_b:
    ; putbin(*arg_ptr)
    mov   rdi, [rdi]
    sub   rsp, TMP_BUF_SIZE
    lea   rsi, [rsp+TMP_BUF_SIZE-1]
    call  putbin
    mov   rcx, rax
    write_no_pie 1, rsi, rcx
    mov   rax, rcx
    add   rsp, TMP_BUF_SIZE
    jmp   .after_spec

.case_c:
    ; putchar(*arg_ptr)
    ; movzx edi, byte [rdi]
    mov   al, byte [rdi]
    ; sub   rsp, TMP_BUF_SIZE
    ; lea   rsi, [rsp+TMP_BUF_SIZE-1]
    ; call  putchar
    ; mov   rcx, rax
    ; write 1, rsi, rcx
    ; mov   rax, rcx
    ; add   rsp, TMP_BUF_SIZE
    sub   rsp, 1
    mov  [rsp], al
    write_no_pie 1, rsp, 1
    add   rsp, 1
    jmp   .after_spec

.case_d:
    ; putint(*arg_ptr)
    mov   rdi, [rdi]
    sub   rsp, TMP_BUF_SIZE
    lea   rsi, [rsp+TMP_BUF_SIZE-1]
    call  putint
    mov   rcx, rax
    write_no_pie 1, rsi, rcx
    mov   rax, rcx
    add   rsp, TMP_BUF_SIZE
    jmp   .after_spec

.case_o:
    ; putoct(*arg_ptr)
    mov   rdi, [rdi]
    sub   rsp, TMP_BUF_SIZE
    lea   rsi, [rsp+TMP_BUF_SIZE-1]
    call  putoct
    mov   rcx, rax
    write_no_pie 1, rsi, rcx
    mov   rax, rcx
    add   rsp, TMP_BUF_SIZE
    jmp   .after_spec

.case_s:
    ; putstr(arg_ptr)
    mov   rdi, [rdi]
    call  putstr
    mov   rcx, rax
    write_no_pie 1, rsi, rcx
    mov   rax, rcx
    jmp   .after_spec

.case_u:
    ; putuint(*arg_ptr)
    mov   rdi, [rdi]
    sub   rsp, TMP_BUF_SIZE
    lea   rsi, [rsp+TMP_BUF_SIZE-1]
    call  putuint
    mov   rcx, rax
    write_no_pie 1, rsi, rcx
    mov   rax, rcx
    add   rsp, TMP_BUF_SIZE
    jmp   .after_spec

.case_x:
    ; puthex(*arg_ptr)
    mov   rdi, [rdi]
    sub   rsp, TMP_BUF_SIZE
    lea   rsi, [rsp+TMP_BUF_SIZE-1]
    call  puthex
    mov   rcx, rax
    write_no_pie 1, rsi, rcx
    mov   rax, rcx
    add   rsp, TMP_BUF_SIZE
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
