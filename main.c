#include <stdint.h>

extern int32_t printer(const char *fmt, ...);

int main(void) {
    printer("A=%d B=%d C=%d D=%d E=%d F=%d\n", 1, 2, 3, 4, 5, 6);
    return 0;
}