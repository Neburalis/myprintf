Задача проекта: реализовать функцию с функционалом аналогичным дефолтному printf. Код на asm, при этом линковка с си. (запуск моей функции из си, вызов си функций из моего кода)

Структура проекта на псевдокоде:

```

// помещает символ
void putchar(char a);

// помещает строку
void putstr(char* str);

// помещает int
void putint(int64_t a);

// помещает uint
void putuint(uint64_t a);

// помещает число в 16ричном виде
void puthex(uint64_t a);

// помещает число в 8ричном виде
void putoct(uint64_t a);

// помещает число в 2ичном виде
void putbin(uint64_t a);


/* int32_t printer(char *fmt, ...)
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
;
*/ | BP | RetAddr | %1 | %2 | %3 | %4 | %5 | aligning | chain jmp BP | chain jmp RetAddr | %6 | ...

int32_t printer(char *fmt, uint8_t *ptr1, uint8_t *ptr2) {

    int32_t arg_count = 0;

    while (*fmt != '\0') {
        if (*fmt != '%') {
            putchar(*fmt);
            ++fmt;
            continue;
        }

        ++fmt;

        if (*fmt == '\0') {
            // UB
            break;
        }

        if (*fmt == '%') {
            putchar('%');
            ++fmt;
            continue;
        }

        uint8_t *arg_ptr;
        if (arg_count < 5)
            arg_ptr = ptr1 + arg_count * 8;
        else
            arg_ptr = ptr2 + (arg_count - 5) * 8;

        switch (*fmt) {
            case 'b': putbin(arg_ptr);   break;
            case 'c': putchar(*arg_ptr); break;
            case 'd': putint(arg_ptr);   break;
            case 'o': putoct(arg_ptr);   break;
            case 's': putstr(arg_ptr);   break;
            case 'u': putuint(arg_ptr);  break;
            case 'x': puthex(arg_ptr);   break;
            default:
                // UB
                break;
        }

        ++arg_count;
        ++fmt;
    }
}

```