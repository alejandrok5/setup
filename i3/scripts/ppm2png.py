#!/usr/bin/env python3
"""ppm2png.py — minimal PPM (P6) -> PNG converter, stdlib only.

Reads a binary PPM (P6, 8-bit RGB) on stdin and writes a PNG to argv[1].
Used by lock.sh to turn the wallpaper (djpeg-decoded) into the PNG that plain
i3lock needs — so the lock screen shows the wallpaper without ImageMagick.
"""
import sys
import zlib
import struct


def read_token(buf, i):
    # skip whitespace and #-comments, then read one token
    while i < len(buf):
        c = buf[i:i + 1]
        if c.isspace():
            i += 1
        elif c == b'#':
            while i < len(buf) and buf[i:i + 1] != b'\n':
                i += 1
        else:
            break
    start = i
    while i < len(buf) and not buf[i:i + 1].isspace():
        i += 1
    return buf[start:i], i


def main(out_path):
    data = sys.stdin.buffer.read()
    if data[:2] != b'P6':
        raise SystemExit('ppm2png: not a P6 PPM')
    i = 2
    w_tok, i = read_token(data, i)
    h_tok, i = read_token(data, i)
    m_tok, i = read_token(data, i)
    w, h = int(w_tok), int(h_tok)
    i += 1  # single whitespace byte after maxval
    stride = w * 3
    pixels = data[i:i + stride * h]

    # PNG scanlines: each row prefixed with filter byte 0 (None).
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw += pixels[y * stride:(y + 1) * stride]
    comp = zlib.compress(bytes(raw), 6)

    def chunk(typ, payload):
        return (struct.pack('>I', len(payload)) + typ + payload +
                struct.pack('>I', zlib.crc32(typ + payload) & 0xffffffff))

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))  # RGB, 8-bit
    png += chunk(b'IDAT', comp)
    png += chunk(b'IEND', b'')
    with open(out_path, 'wb') as f:
        f.write(png)


if __name__ == '__main__':
    main(sys.argv[1])
