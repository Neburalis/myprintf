#!/usr/bin/env python3
from pathlib import Path
import re
import string
import sys


# =========================
# CONFIG (редактируй здесь)
# =========================

# Диапазон символов (включительно)
RANGE_START = 'b'
RANGE_END = 'x'

LABEL_PREFIX = "printer.internal."

# Дефолтная метка
DEFAULT_LABEL = LABEL_PREFIX + "case_default"

# Явные кейсы
CASES = {
    'c': LABEL_PREFIX + "case_c", # Char
    's': LABEL_PREFIX + "case_s", # String
    'd': LABEL_PREFIX + "case_d", # Decimal
    'i': LABEL_PREFIX + "case_d", # Decimal
    'u': LABEL_PREFIX + "case_u", # Unsigned
    'o': LABEL_PREFIX + "case_o", # Oct
    'x': LABEL_PREFIX + "case_x", # Hex
    'p': LABEL_PREFIX + "case_x", # Pointer
    'b': LABEL_PREFIX + "case_b", # Binary
    'f': LABEL_PREFIX + "case_f", # Float
}


# =========================
# CONSTANTS
# =========================

GENERATED_BLOCK_RE = re.compile(
    r"(?ms)"
    r"^; #" + "=#" * 30 + "\n"
    r"; Don't edit this part #\n"
    r"; it's generated automatically by a generate_jmp_table\.py script #\n"
    r".*?"
    r"; end of generated part\n"
    r"; #" + "=#" * 30 + "\n?"
)

BLOCK_PREFIX = (
    "; #" + "=#" * 30 + "\n"
    "; Don't edit this part #\n"
    "; it's generated automatically by a generate_jmp_table.py script #\n"
)

BLOCK_SUFFIX = (
    "; end of generated part\n"
    "; #" + "=#" * 30 + "\n"
)


# =========================
# GENERATION LOGIC
# =========================

def validate_config() -> None:
    if len(RANGE_START) != 1 or len(RANGE_END) != 1:
        raise ValueError("RANGE_START and RANGE_END must be single characters")

    if RANGE_START not in string.printable or RANGE_END not in string.printable:
        raise ValueError("RANGE_START and RANGE_END must be printable ASCII characters")

    if ord(RANGE_START) > ord(RANGE_END):
        raise ValueError("RANGE_START must be <= RANGE_END")

    for ch, label in CASES.items():
        if len(ch) != 1:
            raise ValueError(f"Invalid CASES key {ch!r}: must be a single character")
        if not (RANGE_START <= ch <= RANGE_END):
            raise ValueError(
                f"CASES key {ch!r} is outside configured range {RANGE_START!r}..{RANGE_END!r}"
            )
        if not label.strip():
            raise ValueError(f"CASES[{ch!r}] label must not be empty")

    if not DEFAULT_LABEL.strip():
        raise ValueError("DEFAULT_LABEL must not be empty")


def generate_table_body() -> str:
    lines = [
        "",
        "; JmpTable:",
        "section .data",
        "align 8",
        "",
        f"; Индекс: (*fmt - '{RANGE_START}')",
        f"; Диапазон: '{RANGE_START}'..'{RANGE_END}'",
        "jmp_table:",
    ]

    max_label_len = max(
        [len(DEFAULT_LABEL), *(len(label) for label in CASES.values())]
    )

    for code in range(ord(RANGE_START), ord(RANGE_END) + 1):
        ch = chr(code)
        label = CASES.get(ch, DEFAULT_LABEL)
        lines.append(f"    dq {label:<{max_label_len}} ; '{ch}'")

    return "\n".join(lines) + "\n"


def build_updated_block() -> str:
    return BLOCK_PREFIX + generate_table_body() + BLOCK_SUFFIX


# =========================
# FILE UPDATE LOGIC
# =========================

def main() -> int:
    validate_config()

    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <filename>", file=sys.stderr)
        return 1

    filename = Path(sys.argv[1])

    if not filename.exists():
        print(f"File not found: {filename}", file=sys.stderr)
        return 1

    content = filename.read_text(encoding="utf-8")
    new_block = build_updated_block()

    new_content, count = GENERATED_BLOCK_RE.subn(new_block, content, count=1)

    if count == 0:
        print("Generated block not found")
        return 2

    filename.write_text(new_content, encoding="utf-8")
    print(f"Updated generated block in {filename}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())