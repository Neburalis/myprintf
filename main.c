#include <stdint.h>
#include <stdio.h>

extern int32_t printer(const char *fmt, ...);

int main(void) {
    printer("%s", "%% %d %c %s\n%b %o %x\n\n");
    printer("%% %d %c %s\n%b %o %x\n %d %s %x %d%%%c%b\n", (long) -1, 'x', "Hello", 12, 12, 12, (long) -1, "love", 3802, 100, 33, 126);
    printer("\n");
    for (long i = 1; i < 100; i+=3) {
        // printf("%ld: %b %o %x\n", i, i, i, i);
        // fflush(stdout);
        printer("%d: %b %o %x\n", i, i, i, i);
        printer("\n");
    }
    return 0;
}