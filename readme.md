Задача проекта: реализовать функцию с функционалом аналогичным дефолтному printf. Код на asm, при этом линковка с си. (запуск моей функции из си, вызов си функций из моего кода)

Структура проекта на псевдокоде:

```

// помещает символ
void putchar(char a);

// помещает строку
void putstr(char* str);

// помещает int
void putint(int a);

// помещает int
void putuint(int a);

// помещает число в 16ричном виде
void puthex(uint64_t a);

// помещает число в 8ричном виде
void putoct(uint64_t a);

// помещает число в 2ичном виде
void putbin(uint64_t a);

int32_t printf_inter(char *fmt, ...) {

    // fmt stay in rbx

asm(
    push bp
    mov bp, sp
)

    _bp -= 8; // [sp] - указывает на адрес возврата, перед ним лежит первый аргумент

    int32_t put_count = 0; // local var, stay in eax (return value)
    while(*fmt != '\0') {
        if (*fmt == '%') {
            ++fmt;
            switch(*fmt) {
                case 'b':
                    putbin(_bp);
                    _bp -= 8;
                    break;
                case 'c':
                    putchar(_bp);
                    _bp -= 1;
                    break;
                case 'd':
                    putint(_bp);
                    _bp -= 8;
                    break;
                case 'o':
                    putoct(_bp);
                    _bp -= 8;
                    break;
                case 's':
                    putstr(_bp);
                    _bp -= 8;
                    break;
                case 'u':
                    putuint(_bp);
                    _bp -= 8;
                    break;
                case 'x':
                    putoct(_bp);
                    _bp -= 8;
                    break;
                default:
                    // UB
                    asm (jmp 0)
            }
            ++fmt;
        } else {
            putchar(buf, *fmt);
            ++put_count;
            ++fmt;
        }
    }

asm(
    pop bp
    ret
)

}

```