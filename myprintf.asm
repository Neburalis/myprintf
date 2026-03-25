section .text

%include "linux64_macro.asm"

global _start

_start:

    write_no_pie 1, Msg, MsgLen

    exit 0

section     .data

Msg:        db "__Hllwrld", 0x0a
MsgLen      equ $ - Msg