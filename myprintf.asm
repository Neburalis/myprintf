; =============================================================================
; myprintf.asm  - minimal demo for syscall-based printing and exit
; pseudocode of this file is in readme.md
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
    global myprintf
    global myfprintf
    global mysnprintf

    extern printf

    %include "linux64_macro.asm"

struc buf
    .string     resq 1 ; char*
    .capacity   resd 1 ; uint32_t
    .size       resd 1 ; uint32_t
endstruc

TMP_BUF_SIZE    equ 80
PRINTER_BUF_SIZE equ 512

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
; uint32_t put_double(double a, char *buf_end)
; =============================================================================
; Converts a double to decimal string with 6 fractional digits.
; Fills buffer from end (same convention as other helpers).
; Assumes: |a| < 2^63, no NaN/Inf.
;
; IN:
;   rdi = a (raw IEEE 754 double bits)
;   rsi -> buf  (end of print buffer. Should be no less than TMP_BUF_SIZE)
; OUT:
;   eax = number of bytes written
;   rsi -> start of string (buf filled from end)
; SAVED:
;   rbx, r12, r13
;
put_double:
    push rbx
    push r12
    push r13

    mov  r12, rsi           ; r12 = end of buffer (save original rsi for final count)

    ; --- sign ---
    xor  ebx, ebx           ; ebx = sign flag (0 = positive)
    test rdi, rdi
    jns  .abs_done
    inc  ebx                ; negative
    btr  rdi, 63            ; clear sign bit → |a|
.abs_done:
    movq xmm0, rdi          ; xmm0 = |a|

    ; --- integer part ---
    cvttsd2si r13, xmm0     ; r13 = (int64)|a|  (truncate toward zero)
    cvtsi2sd  xmm1, r13
    subsd     xmm0, xmm1   ; xmm0 = fractional part ∈ [0, 1)

    ; --- 6 fractional digits ---
    ; Multiply frac by 10^6 → integer, then extract digits by division.
    ; Division produces least-significant digit first, which fills buffer
    ; right-to-left correctly (rightmost = least significant).
    mulsd     xmm0, [rel million_double]  ; xmm0 = frac * 1000000
    cvttsd2si rdi,  xmm0                  ; rdi = frac_integer (0..999999)

    push r8
    mov  r8, 10
    mov  ecx, 6
.frac_loop:
    xor  edx, edx
    mov  rax, rdi
    div  r8                ; edx = digit (LSB first), rax = quotient
    mov  rdi, rax
    add  dl, '0'
    dec  rsi
    mov  byte [rsi], dl
    dec  ecx
    jnz  .frac_loop
    pop  r8

    ; --- decimal point ---
    dec  rsi
    mov  byte [rsi], '.'

    ; --- integer digits (reuse putuint) ---
    mov  rdi, r13
    call putuint            ; rsi → start of integer digits, eax = int digit count

    ; --- minus sign if negative ---
    test ebx, ebx
    jz   .no_sign
    dec  rsi
    mov  byte [rsi], '-'
.no_sign:

    mov  rax, r12
    sub  rax, rsi           ; total bytes = end − current rsi

    pop  r13
    pop  r12
    pop  rbx
    ret

; =============================================================================

; #=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#
; Don't edit this part #
; it's generated automatically by a generate_jmp_table.py script #

; JmpTable:
section .data
align 8

; Индекс: (*fmt - 'b')
; Диапазон: 'b'..'x'
jmp_table:
    dq printer.internal.case_b       ; 'b'
    dq printer.internal.case_c       ; 'c'
    dq printer.internal.case_d       ; 'd'
    dq printer.internal.case_default ; 'e'
    dq printer.internal.case_f       ; 'f'
    dq printer.internal.case_default ; 'g'
    dq printer.internal.case_default ; 'h'
    dq printer.internal.case_d       ; 'i'
    dq printer.internal.case_default ; 'j'
    dq printer.internal.case_default ; 'k'
    dq printer.internal.case_default ; 'l'
    dq printer.internal.case_default ; 'm'
    dq printer.internal.case_default ; 'n'
    dq printer.internal.case_o       ; 'o'
    dq printer.internal.case_x       ; 'p'
    dq printer.internal.case_default ; 'q'
    dq printer.internal.case_default ; 'r'
    dq printer.internal.case_s       ; 's'
    dq printer.internal.case_default ; 't'
    dq printer.internal.case_u       ; 'u'
    dq printer.internal.case_default ; 'v'
    dq printer.internal.case_default ; 'w'
    dq printer.internal.case_x       ; 'x'
; end of generated part
; #=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#

section .text

; =============================================================================
; int32_t put_to_buf(buf_t *buf, flush_buf_t flush, char *tmp, uint32_t tmp_size)
; =============================================================================
; {
;     if (buf->size + tmp_size <= buf->capacity) {
;         memcpy(buf->buf + buf->size, tmp, tmp_size);
;         buf->size += tmp_size;
;         return tmp_size;
;     }
;
;     // не влезает — сбрасываем накопленное
;     int32_t flushed = flush(buf);
;     if (flushed < 0) return flushed;
;     buf->size = 0;
;
;     if (tmp_size <= buf->capacity) {
;         memcpy(buf->buf, tmp, tmp_size);
;         buf->size = tmp_size;
;         return tmp_size;
;     }
;
;     // tmp больше самого буфера — сбрасываем tmp напрямую
;     buf_t tmp_buf = { tmp, tmp_size, tmp_size };
;     flushed = flush(&tmp_buf);
;     if (flushed < 0) return flushed;
;     return tmp_size;
; }
put_to_buf:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13
    push    r14
    push    r15
    ; After 5 pushes (ret addr + 4 regs): rsp % 16 == 0

    mov     r12, rdi        ; r12 = buf
    mov     r13, rsi        ; r13 = flush
    mov     r14, rdx        ; r14 = tmp
    mov     r15d, ecx       ; r15d = tmp_size

    ; if (buf->size + tmp_size <= buf->capacity)
    ; if (buf->size <= buf->capacity - tmp_size)
    ; jump to .no_fit when buf->size > capacity - tmp_size (doesn't fit)
    mov     eax, [r12 + buf.capacity]
    sub     eax, r15d
    cmp     eax, [r12 + buf.size]
    jb      .no_fit

    ; memcpy(buf->buf + buf->size, tmp, tmp_size)
    mov     rdi, [r12 + buf.string]
    mov     eax, [r12 + buf.size]   ; zero-extends to rax
    add     rdi, rax
    mov     rsi, r14
    mov     ecx, r15d
    rep movsb

    ; buf->size += tmp_size
    add     dword [r12 + buf.size], r15d
    mov     eax, r15d               ; return tmp_size
    jmp     .ret

.no_fit:
    ; flushed = flush(buf)
    mov     rdi, r12
    call    r13
    test    eax, eax
    js      .ret                    ; if (flushed < 0) return flushed

    ; buf->size = 0
    mov     dword [r12 + buf.size], 0

    ; if (tmp_size <= buf->capacity)
    mov     eax, r15d
    cmp     eax, [r12 + buf.capacity]
    ja      .tmp_too_big

    ; memcpy(buf->buf, tmp, tmp_size)
    mov     rdi, [r12 + buf.string]
    mov     rsi, r14
    mov     ecx, r15d
    rep movsb

    ; buf->size = tmp_size
    mov     dword [r12 + buf.size], r15d
    mov     eax, r15d               ; return tmp_size
    jmp     .ret

.tmp_too_big:
    ; buf_t tmp_buf = { tmp, tmp_size, tmp_size }
    sub     rsp, 16                         ; rsp % 16 == 0
    mov     [rsp + buf.string],   r14
    mov     dword [rsp + buf.capacity], r15d
    mov     dword [rsp + buf.size],     r15d

    ; flushed = flush(&tmp_buf)
    mov     rdi, rsp
    call    r13

    add     rsp, 16

    test    eax, eax
    js      .ret                    ; if (flushed < 0) return flushed
    mov     eax, r15d               ; return tmp_size

.ret:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

; ================================
; putstr — обрабатывается отдельно, вне таблицы
; режет строку на куски по capacity и флашит
; ================================
;
; int32_t putstr(buf_t *buf, flush_buf_t flush, char *str) {
;     int32_t total = 0;
;
;     while (*str != '\0') {
;         // считаем сколько влезет
;         uint32_t chunk = min(strlen(str), buf->capacity);
;
;         int32_t written = put_to_buf(buf, flush, str, chunk);
;         if (written < 0) return written;
;
;         total += written;
;         str   += chunk;
;     }
;
;     return total;
; }
putstr:
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbx
    ; 5 pushes после ret addr → rsp % 16 == 0 перед call put_to_buf

    mov     r12, rdi        ; r12 = buf
    mov     r13, rsi        ; r13 = flush
    mov     r14, rdx        ; r14 = str
    xor     r15d, r15d      ; r15d = total = 0

.loop:
    ; while (*str != '\0')
    cmp     byte [r14], 0
    je      .done

    ; rcx = strlen(str) через repne scasb
    mov     rdi, r14
    xor     eax, eax        ; al = 0 (ищем null-байт)
    mov     rcx, -1
    repne   scasb
    not     rcx
    dec     rcx             ; rcx = strlen(str)

    ; chunk = min(strlen, buf->capacity)
    mov     eax, [r12 + buf.capacity]
    cmp     ecx, eax
    cmova   ecx, eax        ; if ecx > capacity → ecx = capacity (unsigned)
    mov     ebx, ecx        ; rbx = chunk (upper bits zeroed by mov ebx)

    ; put_to_buf(buf, flush, str, chunk)
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    ; ecx уже = chunk
    call    put_to_buf

    ; if (written < 0) return written
    test    eax, eax
    js      .ret            ; eax < 0 → ошибка, возвращаем как есть

    ; total += written
    add     r15d, eax

    ; str += chunk
    add     r14, rbx        ; rbx = (uint64_t)chunk (zero-extended от ebx)

    jmp     .loop

.done:
    mov     eax, r15d       ; return total

.ret:
    pop     rbx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    ret

; =============================================================================
; int32_t printer.flush(buf_t *buf)
; =============================================================================
; Writes buf->string[0..buf->size) to stdout via write(2). Returns the
; number of bytes written, or a negative value on error.
;
; IN:
;   rdi = buf_t*
; OUT:
;   eax = bytes written (or negative on error)
; DESTR:
;   rax, rcx, rdi, rsi, rdx, r11
printer.flush:
    mov   rcx, rdi                          ; rcx = buf_t* (rdi clobbered by write macro)
    mov   edx, dword [rcx + buf.size]      ; edx = size (zero-extends to rdx)
    test  edx, edx
    jz    .empty
    mov   rsi, [rcx + buf.string]          ; rsi = string ptr
    write 1, rsi, rdx                      ; write(stdout, string, size) → rax
    ret
.empty:
    xor   eax, eax
    ret

; =============================================================================
; int32_t printer.flush_to_fd(buf_fd_t *buf)
; =============================================================================
; Writes buf->string[0..buf->size) to the fd stored at [buf + 16] via write(2).
; The buf_fd_t layout extends buf_t with an int32_t fd field at offset 16.
;
; IN:
;   rdi = buf_fd_t* (buf_t with int32 fd appended at offset 16)
; OUT:
;   eax = bytes written (or negative on error)
; DESTR:
;   rax, rcx, rdx, rdi, rsi
printer.flush_to_fd:
    mov   edx, dword [rdi + buf.size]
    test  edx, edx
    jz    .empty
    mov   rsi, [rdi + buf.string]
    mov   edi, dword [rdi + 16]         ; fd at offset 16 (after buf_t's 16 bytes)
    mov   eax, 1                        ; SYS_write
    syscall
    ret
.empty:
    xor   eax, eax
    ret

; =============================================================================
; int32_t printer.flush_no_overflow(buf_t *buf)
; =============================================================================
; Overflow guard for snprintf: always returns -1, preventing put_to_buf from
; resetting and overwriting the fixed-size destination buffer.
;
; IN:
;   rdi = buf_t*
; OUT:
;   eax = -1 (overflow error)
printer.flush_no_overflow:
    mov   eax, -1
    ret

; =============================================================================
; int32_t myprintf(char *fmt, ...)
; =============================================================================
; SysV x86-64 ABI trampoline: spills register args to stack, sets up a
; print buffer, then delegates to printer.internal.
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
; Stack frame layout (sub rsp, 640):
;   [rsp +   0 ..  39] : 5 register args (rsi, rdx, rcx, r8, r9)
;   [rsp +  40 ..  47] : saved fmt (rdi)
;   [rsp +  48 ..  63] : buf_t  { .string*, .capacity, .size }
;   [rsp +  64 .. 575] : PRINTER_BUF_SIZE-byte print buffer
;   [rsp + 576 .. 639] : XMM save area (xmm0..xmm7, 8×8 bytes)
;
myprintf:
    push rbp
    mov  rbp, rsp
    sub  rsp, 640       ; 40 args + 8 fmt + 16 buf_t + 512 buffer + 64 xmm (16-byte aligned)

    mov  [rsp +  0], rsi
    mov  [rsp +  8], rdx
    mov  [rsp + 16], rcx
    mov  [rsp + 24], r8
    mov  [rsp + 32], r9
    mov  [rsp + 40], rdi    ; save fmt

    ; Save XMM args (xmm0..xmm7) for %f support
    movq [rsp + 576], xmm0
    movq [rsp + 584], xmm1
    movq [rsp + 592], xmm2
    movq [rsp + 600], xmm3
    movq [rsp + 608], xmm4
    movq [rsp + 616], xmm5
    movq [rsp + 624], xmm6
    movq [rsp + 632], xmm7

    ; Set up buf_t at [rsp+48]: string → [rsp+64], capacity = 512, size = 0
    lea  rax, [rsp + 64]
    mov  [rsp + 48 + buf.string],        rax
    mov  dword [rsp + 48 + buf.capacity], PRINTER_BUF_SIZE
    mov  dword [rsp + 48 + buf.size],     0

    ; printer.internal(buf, flush, fmt, ptr1, ptr2, ptr_xmm)
    lea  rdi, [rsp + 48]                ; buf_t*
    lea  rsi, [rel printer.flush]       ; flush fn
    mov  rdx, [rsp + 40]               ; fmt
    lea  rcx, [rsp + 0]                ; ptr1 (5 register args)
    lea  r8,  [rbp + 16]               ; ptr2 (caller stack args 6+)
    lea  r9,  [rsp + 576]              ; ptr_xmm
    call printer.internal

    ; flush remaining buffer before jmp to printf
    push rax                            ; save return value
    lea  rdi, [rsp + 48 + 8]           ; buf_t* (rsp shifted by the push above)
    call printer.flush
    pop  rax                            ; restore return value

    mov  rdi, [rsp + 40]    ; fmt
    mov  rsi, [rsp +  0]    ; 1st arg
    mov  rdx, [rsp +  8]    ; 2nd arg
    mov  rcx, [rsp + 16]    ; 3rd arg
    mov  r8,  [rsp + 24]    ; 4th arg
    mov  r9,  [rsp + 32]    ; 5th arg
    movq xmm0, [rsp + 576]  ; restore xmm0 for libc printf trampoline
    movq xmm1, [rsp + 584]
    movq xmm2, [rsp + 592]
    movq xmm3, [rsp + 600]
    movq xmm4, [rsp + 608]
    movq xmm5, [rsp + 616]
    movq xmm6, [rsp + 624]
    movq xmm7, [rsp + 632]
    mov  al,   8            ; up to 8 XMM args used
    add  rsp, 640
    pop  rbp
    jmp  printf wrt ..plt

; =============================================================================
; int32_t myfprintf(int fd, char *fmt, ...)
; =============================================================================
; Writes formatted output to the given file descriptor.
;
; IN:
;   rdi = fd
;   rsi = fmt
;   rdx = arg1 .. r9 = arg4  (variadic register args)
;   [rbp+16] = arg5+ (caller stack args)
; OUT:
;   eax = total bytes written (or negative on error)
;
; Stack frame layout (sub rsp, 656; X%16==0 → aligned):
;   [rsp +  0 ..  39] : 5 variadic reg args (rdx, rcx, r8, r9, [rbp+16])
;   [rsp + 40 ..  47] : saved fmt (rsi)
;   [rsp + 48 ..  55] : saved fd  (rdi)
;   [rsp + 56 ..  71] : buf_t  { .string*, .capacity, .size }
;   [rsp + 72 ..  79] : fd for flush_to_fd (buf_t offset 16)
;   [rsp + 80 .. 591] : PRINTER_BUF_SIZE-byte print buffer
;   [rsp + 592 .. 655] : XMM save area (xmm0..xmm7, 8×8 bytes)
;
myfprintf:
    push rbp
    mov  rbp, rsp
    sub  rsp, 656               ; 656 % 16 == 0 → remains aligned after push rbp

    ; spill 4 variadic register args + first caller-stack arg → ptr1[0..4]
    mov  [rsp +  0], rdx        ; arg1
    mov  [rsp +  8], rcx        ; arg2
    mov  [rsp + 16], r8         ; arg3
    mov  [rsp + 24], r9         ; arg4
    mov  rax, [rbp + 16]        ; arg5 (first caller-stack variadic arg)
    mov  [rsp + 32], rax
    mov  [rsp + 40], rsi        ; save fmt
    mov  [rsp + 48], rdi        ; save fd

    ; Save XMM args (xmm0..xmm7) for %f support
    movq [rsp + 592], xmm0
    movq [rsp + 600], xmm1
    movq [rsp + 608], xmm2
    movq [rsp + 616], xmm3
    movq [rsp + 624], xmm4
    movq [rsp + 632], xmm5
    movq [rsp + 640], xmm6
    movq [rsp + 648], xmm7

    ; Set up buf_t at [rsp+56]: string → [rsp+80], capacity=512, size=0
    lea  rax, [rsp + 80]
    mov  [rsp + 56 + buf.string],         rax
    mov  dword [rsp + 56 + buf.capacity], PRINTER_BUF_SIZE
    mov  dword [rsp + 56 + buf.size],     0
    ; fd at offset 16 from buf_t start = [rsp+72]
    mov  eax, dword [rsp + 48]
    mov  dword [rsp + 72], eax

    ; printer.internal(buf_fd, flush_to_fd, fmt, ptr1, ptr2, ptr_xmm)
    lea  rdi, [rsp + 56]                    ; buf_fd_t* (compatible with buf_t*)
    lea  rsi, [rel printer.flush_to_fd]
    mov  rdx, [rsp + 40]                    ; fmt
    lea  rcx, [rsp + 0]                     ; ptr1 (5 variadic args)
    lea  r8,  [rbp + 24]                    ; ptr2 (caller-stack args 6+)
    lea  r9,  [rsp + 592]                   ; ptr_xmm
    call printer.internal

    ; final flush
    push rax                                ; save result
    lea  rdi, [rsp + 56 + 8]               ; buf_fd_t* (rsp shifted by 8 after push)
    call printer.flush_to_fd
    pop  rax                                ; restore result (ignore flush result)

    add  rsp, 656
    pop  rbp
    ret

; =============================================================================
; int32_t mysnprintf(char *dst, uint32_t n, char *fmt, ...)
; =============================================================================
; Writes formatted output into dst[0..n). Always null-terminates if n > 0.
; Returns -1 on overflow (data would exceed n bytes).
;
; IN:
;   rdi = dst (char*)
;   esi = n   (uint32_t)
;   rdx = fmt
;   rcx = arg1 .. r9 = arg3  (variadic register args)
;   [rbp+16] = arg4+ (caller stack args)
; OUT:
;   eax = bytes written, or -1 on overflow
;
; Stack frame layout (sub rsp, 144; X%16==0 → aligned):
;   [rsp +  0 ..  39] : 5 variadic reg args (rcx, r8, r9, [rbp+16], [rbp+24])
;   [rsp + 40 ..  47] : saved fmt (rdx)
;   [rsp + 48 ..  55] : saved dst (rdi)
;   [rsp + 56 ..  63] : saved n   (esi, uint32 in low dword)
;   [rsp + 64 ..  79] : buf_t { .string*=dst, .capacity=n, .size=0 }
;   [rsp + 80 .. 143] : XMM save area (xmm0..xmm7, 8×8 bytes)
;
mysnprintf:
    push rbp
    mov  rbp, rsp
    sub  rsp, 144               ; 144 % 16 == 0 → aligned

    ; spill 3 variadic register args + first two caller-stack args → ptr1[0..4]
    mov  [rsp +  0], rcx        ; arg1
    mov  [rsp +  8], r8         ; arg2
    mov  [rsp + 16], r9         ; arg3
    mov  rax, [rbp + 16]        ; arg4 (first caller-stack variadic arg)
    mov  [rsp + 24], rax
    mov  rax, [rbp + 24]        ; arg5
    mov  [rsp + 32], rax
    mov  [rsp + 40], rdx        ; save fmt
    mov  [rsp + 48], rdi        ; save dst
    mov  dword [rsp + 56], esi  ; save n

    ; Save XMM args (xmm0..xmm7) for %f support
    movq [rsp +  80], xmm0
    movq [rsp +  88], xmm1
    movq [rsp +  96], xmm2
    movq [rsp + 104], xmm3
    movq [rsp + 112], xmm4
    movq [rsp + 120], xmm5
    movq [rsp + 128], xmm6
    movq [rsp + 136], xmm7

    ; Set up buf_t at [rsp+64]: string=dst, capacity=n, size=0
    mov  [rsp + 64 + buf.string],         rdi
    mov  dword [rsp + 64 + buf.capacity], esi
    mov  dword [rsp + 64 + buf.size],     0

    ; printer.internal(buf, flush_no_overflow, fmt, ptr1, ptr2, ptr_xmm)
    lea  rdi, [rsp + 64]                      ; buf_t*
    lea  rsi, [rel printer.flush_no_overflow]
    mov  rdx, [rsp + 40]                      ; fmt
    lea  rcx, [rsp + 0]                       ; ptr1
    lea  r8,  [rbp + 32]                      ; ptr2 (caller-stack args 6+)
    lea  r9,  [rsp + 80]                      ; ptr_xmm
    call printer.internal

    ; no final flush — data is already in dst
    ; add null terminator if space remains
    mov  rdi, [rsp + 48]                      ; dst
    mov  ecx, dword [rsp + 64 + buf.size]     ; buf.size
    mov  edx, dword [rsp + 56]               ; n
    cmp  ecx, edx
    jae  .no_null
    mov  byte [rdi + rcx], 0                  ; dst[buf.size] = '\0'
.no_null:

    add  rsp, 144
    pop  rbp
    ret


;
; Pseudo code of function logic:
; int32_t printer_internal(buf_t *buf, flush_buf_t flush, char *fmt, uint8_t *ptr1, uint8_t *ptr2) {
;
;     int32_t total    = 0;
;     int32_t arg_count = 0;
;
;     while (*fmt != '\0') {
;
;         if (*fmt != '%') {
;             int32_t written = put_to_buf(buf, flush, fmt, 1);
;             if (written < 0) return written;
;             total += written;
;             ++fmt;
;             continue;
;         }
;
;         ++fmt;
;
;         if (*fmt == '\0') break; // UB
;
;         if (*fmt == '%') {
;             int32_t written = put_to_buf(buf, flush, "%", 1);
;             if (written < 0) return written;
;             total += written;
;             ++fmt;
;             continue;
;         }
;
;         // получаем указатель на аргумент
;         uint64_t arg;
;         if (arg_count < 5)
;             arg = *(uint64_t*)(ptr1 + arg_count * 8);
;         else
;             arg = *(uint64_t*)(ptr2 + (arg_count - 5) * 8);
;
;         int32_t written;
;
;         if (*fmt == 's') {
;             written = putstr(buf, flush, (char*)arg);
;         } else {
;             // bounds check
;             uint8_t idx = *fmt - 'b';
;             if (idx >= jump_table_size) {
;                 // UB — неизвестный спецификатор
;                 ++fmt;
;                 continue;
;             }
;
;             char tmp[TMP_BUF_SIZE];
;             uint32_t tmp_size = jump_table[idx](tmp, arg);
;
;             written = put_to_buf(buf, flush, tmp, tmp_size);
;         }
;
;         if (written < 0) return written;
;         total    += written;
;         ++arg_count;
;         ++fmt;
;     }
; }

; =============================================================================
; int32_t printer.internal(buf_t *buf, flush_buf_t flush, char *fmt,
;                          uint8_t *ptr1, uint8_t *ptr2, double *ptr_xmm)
; =============================================================================
; core format-string loop; called directly by printer trampoline.
;
; IN:
;   rdi = buf     (buf_t* — output buffer)
;   rsi = flush   (flush_buf_t — flush callback)
;   rdx = fmt     (pointer to format string)
;   rcx = ptr1    (pointer to integer args 1–5, each 8 bytes)
;   r8  = ptr2    (pointer to integer args 6+ on caller stack)
;   r9  = ptr_xmm (pointer to 8×8-byte XMM save area: xmm0..xmm7)
; OUT:
;   eax = total bytes written (or negative on error)
; SAVED:
;   rbp, rbx, r12, r13, r14, r15
; LOCAL (rsp-relative after sub 104):
;   [rsp +  0] = ptr2      (8 bytes)
;   [rsp +  8] = total     (int32_t)
;   [rsp + 12] = xmm_count (int32_t)  ← float arg counter (was pad)
;   [rsp + 16] = tmp_buf   (TMP_BUF_SIZE bytes)
;   [rsp + 96] = ptr_xmm   (8 bytes)  ← in former alignment slack
; REGISTER MAP during loop:
;   r12 = buf,  r13 = flush,  r14 = fmt,  r15 = ptr1,  rbx = arg_count
;
printer.internal:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    ; 1 ret addr + 6 pushes = 56 bytes → rsp%16 == 8.
    ; Alloc: 8(ptr2) + 8(total+pad) + 80(tmp_buf) + 8(align) = 104
    sub  rsp, 104           ; rsp now 16-byte aligned

    mov  r12, rdi           ; r12 = buf
    mov  r13, rsi           ; r13 = flush
    mov  r14, rdx           ; r14 = fmt
    mov  r15, rcx           ; r15 = ptr1
    mov  [rsp], r8          ; [rsp+0] = ptr2
    mov  dword [rsp+8], 0   ; total = 0
    mov  dword [rsp+12], 0  ; xmm_count = 0
    mov  [rsp+96], r9       ; ptr_xmm
    xor  ebx, ebx           ; arg_count = 0

.loop:
    movzx rax, byte [r14]
    test  al, al
    je    .done

    cmp   al, '%'
    je    .percent

    ; regular char: put_to_buf(buf, flush, &char, 1)
    mov  rdi, r12
    mov  rsi, r13
    mov  rdx, r14
    mov  ecx, 1
    call put_to_buf
    test eax, eax
    js   .ret_err
    add  dword [rsp+8], eax
    inc  r14
    jmp  .loop

.percent:
    inc  r14
    movzx rax, byte [r14]
    test  al, al
    je    .done             ; UB: trailing single '%'

    cmp   al, '%'
    jne   .select_arg

    ; '%%' → emit single '%'
    mov  rdi, r12
    mov  rsi, r13
    mov  rdx, r14           ; r14 points to second '%'
    mov  ecx, 1
    call put_to_buf
    test eax, eax
    js   .ret_err
    add  dword [rsp+8], eax
    inc  r14
    jmp  .loop

.select_arg:
    ; rax = specifier char
    cmp  ebx, 5
    jl   .from_ptr1

    ; ptr2 + (arg_count - 5) * 8
    mov  rdi, [rsp]         ; rdi = ptr2
    mov  rcx, rbx
    sub  rcx, 5
    shl  rcx, 3
    add  rdi, rcx
    jmp  .dispatch

.from_ptr1:
    mov  rcx, rbx
    shl  rcx, 3
    lea  rdi, [r15 + rcx]

.dispatch:
    ; rdi = arg_ptr, rax = specifier char
    cmp  rax, 'b'
    jb   .case_default
    cmp  rax, 'x'
    ja   .case_default
    lea  rdx, [rel jmp_table]
    jmp  [rdx + (rax - 'b') * 8]

.case_b:
    mov  rdi, [rdi]
    lea  rsi, [rsp + 16 + TMP_BUF_SIZE - 1]
    call putbin
    jmp  .put_tmp

.case_c:
    ; char arg — store in tmp_buf[0], call put_to_buf
    mov  al, byte [rdi]
    mov  [rsp + 16], al
    mov  rdi, r12
    mov  rsi, r13
    lea  rdx, [rsp + 16]
    mov  ecx, 1
    call put_to_buf
    test eax, eax
    js   .ret_err
    add  dword [rsp+8], eax
    jmp  .after_spec

.case_d:
    mov  rdi, [rdi]
    lea  rsi, [rsp + 16 + TMP_BUF_SIZE - 1]
    call putint
    jmp  .put_tmp

.case_f:
    ; %f — load raw double bits from XMM save area (independent of integer arg_count)
    mov  ecx, dword [rsp + 12]    ; ecx = xmm_count
    mov  rax, [rsp + 96]          ; rax = ptr_xmm
    shl  rcx, 3                   ; * 8
    mov  rdi, [rax + rcx]         ; rdi = raw double bits
    lea  rsi, [rsp + 16 + TMP_BUF_SIZE - 1]
    call put_double
    ; put result to output buffer
    mov  rdx, rsi
    mov  ecx, eax
    mov  rdi, r12
    mov  rsi, r13
    call put_to_buf
    test eax, eax
    js   .ret_err
    add  dword [rsp+8], eax
    ; increment xmm_count only (NOT ebx = integer arg_count)
    inc  dword [rsp + 12]
    inc  r14
    jmp  .loop

.case_o:
    mov  rdi, [rdi]
    lea  rsi, [rsp + 16 + TMP_BUF_SIZE - 1]
    call putoct
    jmp  .put_tmp

.case_s:
    ; putstr(buf, flush, str)
    mov  rdx, [rdi]         ; rdx = string ptr (arg value)
    mov  rdi, r12
    mov  rsi, r13
    call putstr
    test eax, eax
    js   .ret_err
    add  dword [rsp+8], eax
    jmp  .after_spec

.case_u:
    mov  rdi, [rdi]
    lea  rsi, [rsp + 16 + TMP_BUF_SIZE - 1]
    call putuint
    jmp  .put_tmp

.case_x:
    mov  rdi, [rdi]
    lea  rsi, [rsp + 16 + TMP_BUF_SIZE - 1]
    call puthex
    jmp  .put_tmp

.put_tmp:
    ; after helper: rsi = start of string in tmp_buf, eax = count
    mov  rdx, rsi
    mov  ecx, eax
    mov  rdi, r12
    mov  rsi, r13
    call put_to_buf
    test eax, eax
    js   .ret_err
    add  dword [rsp+8], eax
    jmp  .after_spec

.case_default:
    ; unknown specifier — skip, do NOT consume an arg
    inc  r14
    jmp  .loop

.after_spec:
    inc  ebx                ; ++arg_count
    inc  r14                ; ++fmt (past specifier)
    jmp  .loop

.done:
    mov  eax, dword [rsp+8]     ; return total bytes written
    jmp  .cleanup

.ret_err:
    ; eax already negative

.cleanup:
    add  rsp, 104
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    pop  rbp
    ret

section .data

ten_double      dq 10.0
million_double  dq 1000000.0
