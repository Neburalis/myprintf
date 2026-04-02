# === config ===
ASM      = nasm
CC       = gcc

ASMFLAGS = -g -f elf64 -l myprintf.lst
CFLAGS   = -fPIC -g

TARGET   = myprintf.out

# === default target ===
all: $(TARGET)

# === codegen ===
myprintf.asm: generate_jmp_table.py
	python3 generate_jmp_table.py myprintf.asm

# === build ===
myprintf.o: myprintf.asm
	$(ASM) $(ASMFLAGS) $<

main.o: main.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(TARGET): myprintf.o main.o
	$(CC) $(CFLAGS) -o $@ myprintf.o main.o

# === run ===
run: $(TARGET)
	./$(TARGET)

# === debug ===
gdb: $(TARGET)
	gdb $(TARGET)

# === clean ===
clean:
	rm -f $(OBJ) $(TARGET) myprintf.lst

.PHONY: all run clean gdb