"""Extract text from a legacy Word .doc (OLE compound) file.

Usage:
    python tools/read_doc.py docs/L298N驱动模块说明书.doc

Tries methods in order:
  1. pywin32 + Word COM   (best fidelity, needs MS Word installed)
  2. olefile WordDocument (no Word needed, needs `pip install olefile`)
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def extract_with_word(path: Path) -> str:
    import win32com.client  # type: ignore

    word = win32com.client.Dispatch("Word.Application")
    word.Visible = False
    try:
        doc = word.Documents.Open(str(path.resolve()), ReadOnly=True)
        try:
            return doc.Content.Text
        finally:
            doc.Close(SaveChanges=False)
    finally:
        word.Quit()


def extract_with_olefile(path: Path) -> str:
    """Pull readable text out of the WordDocument stream without parsing
    the full FIB. Crude but works for plain-text .doc files."""
    import olefile  # type: ignore

    if not olefile.isOleFile(str(path)):
        raise ValueError(f"{path} is not an OLE compound file")

    with olefile.OleFileIO(str(path)) as ole:
        if not ole.exists("WordDocument"):
            raise ValueError("No WordDocument stream — not a Word .doc?")
        raw = ole.openstream("WordDocument").read()

    # Word stores text as UTF-16LE runs interspersed with binary structures.
    # Grab printable UTF-16LE runs of length >= 4.
    out: list[str] = []
    i = 0
    buf: list[str] = []
    while i + 1 < len(raw):
        lo, hi = raw[i], raw[i + 1]
        cp = lo | (hi << 8)
        if cp == 0x000D or cp == 0x000A or cp == 0x0009 or 0x20 <= cp <= 0xFFFD:
            try:
                buf.append(chr(cp))
            except ValueError:
                if buf:
                    if len(buf) >= 4:
                        out.append("".join(buf))
                    buf.clear()
        else:
            if buf:
                if len(buf) >= 4:
                    out.append("".join(buf))
                buf.clear()
        i += 2
    if len(buf) >= 4:
        out.append("".join(buf))

    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("path", type=Path, help="Path to .doc file")
    ap.add_argument(
        "--method",
        choices=("auto", "word", "olefile"),
        default="auto",
        help="Extraction backend (default: auto — try word, fall back to olefile)",
    )
    args = ap.parse_args()

    if not args.path.is_file():
        print(f"error: file not found: {args.path}", file=sys.stderr)
        return 2

    methods = (
        ["word", "olefile"] if args.method == "auto" else [args.method]
    )

    last_err: Exception | None = None
    for m in methods:
        try:
            text = extract_with_word(args.path) if m == "word" else extract_with_olefile(args.path)
            sys.stdout.write(text)
            if not text.endswith("\n"):
                sys.stdout.write("\n")
            return 0
        except ImportError as e:
            print(f"[{m}] missing dependency: {e}", file=sys.stderr)
            last_err = e
        except Exception as e:
            print(f"[{m}] failed: {e}", file=sys.stderr)
            last_err = e

    print("All methods failed.", file=sys.stderr)
    print("Install one of:", file=sys.stderr)
    print("  pip install pywin32      # uses MS Word", file=sys.stderr)
    print("  pip install olefile      # no Word needed", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
