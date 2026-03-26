# === config ===
ASM      = nasm
LD       = ld

ASMFLAGS = -g -f elf64 -l myprintf.lst
LDFLAGS  =

TARGET   = myprintf.out
SRC      = myprintf.asm
OBJ      = myprintf.o

# === default target ===
all: $(TARGET)

# === build ===
$(OBJ): $(SRC)
	@echo "$(ASM) $(ASMFLAGS) $<"
	$(ASM) $(ASMFLAGS) $<

$(TARGET): $(OBJ)
	@echo "$(LD) -o $@ $<"
	$(LD) -o $@ $<

# === run ===
run: $(TARGET)
	@echo "./$(TARGET)"
	./$(TARGET)

# === debug (опционально) ===
gdb: $(TARGET)
	gdb $(TARGET)

# === clean ===
clean:
	rm -f $(OBJ) $(TARGET) myprintf.lst

.PHONY: all run clean gdb