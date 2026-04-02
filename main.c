#include <stdint.h>

extern int32_t myprintf(const char *fmt, ...);
extern int32_t myfprintf(int fd, const char *fmt, ...);
extern int32_t mysnprintf(char *dst, uint32_t n, const char *fmt, ...);

int main(void) {
    myprintf("%s", "%% %d %c %s\n%b %o %x\n\n");
    myprintf("%% %d %c %s\n%b %o %x\n %d %s %x %d%%%c%b\n", (long) -1, 'x', "Hello", 12, 12, 12, (long) -1, "love", 3802, 100, 33, 126);
    myprintf("\n");
    for (long i = 1; i < 100; i+=3) {
        // printf("%ld: %b %o %x\n", i, i, i, i);
        // fflush(stdout);
        myprintf("%d: %b %o %x\n", i, i, i, i);
        myprintf("\n");
    }

    // test myfprintf (fd=2 = stder)
    myfprintf(2, "--- myfprintf test ---\n");
    myfprintf(2, "fd=2: %d %s %x\n", 42, "hello", 255);
    myfprintf(2, "\n");

    // test snprintf
    myfprintf(1, "--- mysnprintf test ---\n");
    char buf[64];
    int32_t n = mysnprintf(buf, sizeof(buf), "mysnprintf: %d %s %x", (long)-7, "world", 0xAB);
    myfprintf(1, "mysnprintf returned %d, buf=[%s]\n", (long)n, buf);

    return 0;
}