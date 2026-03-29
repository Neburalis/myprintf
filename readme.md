Задача проекта: реализовать функцию с функционалом аналогичным дефолтному printf. Код на asm, при этом линковка с си. (запуск моей функции из си, вызов си функций из моего кода)

Структура проекта на псевдокоде:

// ================================
// Типы и константы
// ================================

#define TMP_BUF_SIZE 64

struct buf_t {
    char*    buf;
    uint32_t capacity;
    uint32_t size;
};

typedef int32_t (*flush_buf_t)(buf_t*);


// ================================
// Вспомогательные функции
// каждая строит строку во временном буфере на стеке
// и возвращает количество записанных символов
// ================================

// Буфер должен быть не меньше TMP_BUF_SIZE
uint32_t putchar_buf(char buf[TMP_BUF_SIZE], char a) {
    buf[0] = a;
    return 1;
}

uint32_t putint_buf(char buf[TMP_BUF_SIZE], int64_t a) {
    // строим цифры справа налево, потом разворачиваем
    // обрабатываем знак отдельно
    ...
    return size;
}

uint32_t putuint_buf(char buf[TMP_BUF_SIZE], uint64_t a) { ... }
uint32_t puthex_buf (char buf[TMP_BUF_SIZE], uint64_t a) { ... }
uint32_t putoct_buf (char buf[TMP_BUF_SIZE], uint64_t a) { ... }
uint32_t putbin_buf (char buf[TMP_BUF_SIZE], uint64_t a) { ... }


// ================================
// Таблица функций
// индексируется как (specifier - 'b')
// дырки заполнены указателем на put_unknown_buf
// ================================

uint32_t put_unknown_buf(char buf[TMP_BUF_SIZE], uint64_t a) {
    // UB — неизвестный спецификатор
    return 0;
}

jump_table['b' - 'b'] = putbin_buf
jump_table['c' - 'b'] = putchar_buf
jump_table['d' - 'b'] = putint_buf
jump_table['o' - 'b'] = putoct_buf
jump_table['u' - 'b'] = putuint_buf
jump_table['x' - 'b'] = puthex_buf
// остальные -> put_unknown_buf


// ================================
// put_to_buf — общая логика записи tmp в основной буфер
// возвращает количество записанных символов или < 0 при ошибке
// ================================

int32_t put_to_buf(buf_t *buf, flush_buf_t flush, char *tmp, uint32_t tmp_size) {

    if (buf->size + tmp_size <= buf->capacity) {
        memcpy(buf->buf + buf->size, tmp, tmp_size);
        buf->size += tmp_size;
        return tmp_size;
    }

    // не влезает — сбрасываем накопленное
    int32_t flushed = flush(buf);
    if (flushed < 0) return flushed;
    buf->size = 0;

    if (tmp_size <= buf->capacity) {
        memcpy(buf->buf, tmp, tmp_size);
        buf->size = tmp_size;
        return tmp_size;
    }

    // tmp больше самого буфера — сбрасываем tmp напрямую
    buf_t tmp_buf = { tmp, tmp_size, tmp_size };
    flushed = flush(&tmp_buf);
    if (flushed < 0) return flushed;
    return tmp_size;
}


// ================================
// putstr — обрабатывается отдельно, вне таблицы
// режет строку на куски по capacity и флашит
// ================================

int32_t putstr(buf_t *buf, flush_buf_t flush, char *str) {
    int32_t total = 0;

    while (*str != '\0') {
        // считаем сколько влезет
        uint32_t chunk = min(strlen(str), buf->capacity);

        int32_t written = put_to_buf(buf, flush, str, chunk);
        if (written < 0) return written;

        total += written;
        str   += chunk;
    }

    return total;
}


// ================================
// printer.internal
// ================================

int32_t printer_internal(buf_t *buf, flush_buf_t flush, char *fmt, uint8_t *ptr1, uint8_t *ptr2) {

    int32_t total    = 0;
    int32_t arg_count = 0;

    while (*fmt != '\0') {

        if (*fmt != '%') {
            int32_t written = put_to_buf(buf, flush, fmt, 1);
            if (written < 0) return written;
            total += written;
            ++fmt;
            continue;
        }

        ++fmt;

        if (*fmt == '\0') break; // UB

        if (*fmt == '%') {
            int32_t written = put_to_buf(buf, flush, "%", 1);
            if (written < 0) return written;
            total += written;
            ++fmt;
            continue;
        }

        // получаем указатель на аргумент
        uint64_t arg;
        if (arg_count < 5)
            arg = *(uint64_t*)(ptr1 + arg_count * 8);
        else
            arg = *(uint64_t*)(ptr2 + (arg_count - 5) * 8);

        int32_t written;

        if (*fmt == 's') {
            written = putstr(buf, flush, (char*)arg);
        } else {
            // bounds check
            uint8_t idx = *fmt - 'b';
            if (idx >= jump_table_size) {
                // UB — неизвестный спецификатор
                ++fmt;
                continue;
            }

            char tmp[TMP_BUF_SIZE];
            uint32_t tmp_size = jump_table[idx](tmp, arg);

            written = put_to_buf(buf, flush, tmp, tmp_size);
        }

        if (written < 0) return written;
        total    += written;
        ++arg_count;
        ++fmt;
    }

    // финальный flush остатка
    int32_t flushed = flush(buf);
    if (flushed < 0) return flushed;
    total += flushed; // flush возвращает сколько реально вывел

    return total;
}


// ================================
// Трамплины
// ================================

// flush для printf/fprintf — пишет buf в fd
int32_t flush_to_fd(buf_t *buf, int fd) {
    return write(fd, buf->buf, buf->size); // syscall write
}

int32_t printf(char *fmt, ...) {
    char raw[PRINTF_BUF_SIZE];
    buf_t buf = { raw, PRINTF_BUF_SIZE, 0 };
    // собираем ptr1, ptr2 из varargs через трамплин
    return printer_internal(&buf, flush_to_stdout, fmt, ptr1, ptr2);
}

int32_t fprintf(int fd, char *fmt, ...) {
    char raw[PRINTF_BUF_SIZE];
    buf_t buf = { raw, PRINTF_BUF_SIZE, 0 };
    return printer_internal(&buf, flush_to_fd(fd), fmt, ptr1, ptr2);
}

// flush для snprintf — просто отказывает при переполнении
int32_t flush_no_overflow(buf_t *buf) {
    return -1; // буфер фиксирован, переполнение = ошибка
}

int32_t snprintf(char *dst, uint32_t n, char *fmt, ...) {
    buf_t buf = { dst, n, 0 };
    int32_t result = printer_internal(&buf, flush_no_overflow, fmt, ptr1, ptr2);
    // финальный flush здесь не нужен — данные уже в dst
    // нуль-терминатор
    if (buf.size < n) dst[buf.size] = '\0';
    return result;
}