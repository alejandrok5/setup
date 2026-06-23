#!/usr/bin/env python3
"""make-lock-image.py — build the lock image (orb avatar + optional wallpaper bg).

Stdlib only. Decodes an avatar PNG, scales/circular-masks it, and composites it
centred over a black backing disc on a canvas. The canvas is either solid black
or a dimmed, centre-cropped wallpaper (passed as a raw P6 PPM, e.g. from djpeg).
Output is the PNG lock.sh feeds to i3lock; the picom 3D shader spins the centre.

    make-lock-image.py <avatar.png> <out.png> [diameter] [bg.ppm] [backing_r] [dim] [shape]

Defaults: diameter=290, no bg (black), backing_r=168, dim=0.40, shape=circle,
canvas 2880x1800. shape='square' keeps the avatar square (for the globe shader).
"""
import sys
import zlib
import struct

CW, CH = 2880, 1800


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    return a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)


def read_png(path):
    d = open(path, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n', 'not a PNG'
    i, w, h, ct, idat = 8, 0, 0, 0, bytearray()
    while i < len(d):
        ln = struct.unpack('>I', d[i:i + 4])[0]
        typ = d[i + 4:i + 8]
        payload = d[i + 8:i + 8 + ln]
        if typ == b'IHDR':
            w, h, bd, ct = struct.unpack('>IIBB', payload[:10])
            assert bd == 8 and payload[12] == 0, 'need 8-bit non-interlaced PNG'
        elif typ == b'IDAT':
            idat += payload
        elif typ == b'IEND':
            break
        i += 12 + ln
    raw = zlib.decompress(bytes(idat))
    ch = 4 if ct == 6 else 3 if ct == 2 else None
    assert ch, 'need RGB or RGBA PNG'
    stride = w * ch
    out = bytearray(w * h * 4)
    prev = bytearray(stride)
    pos = 0
    for y in range(h):
        f = raw[pos]; pos += 1
        line = bytearray(raw[pos:pos + stride]); pos += stride
        for x in range(stride):
            a = line[x - ch] if x >= ch else 0
            b = prev[x]
            c = prev[x - ch] if x >= ch else 0
            if f == 1:   line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4: line[x] = (line[x] + _paeth(a, b, c)) & 255
        prev = line
        o = y * w * 4
        for x in range(w):
            s = x * ch
            out[o+x*4]=line[s]; out[o+x*4+1]=line[s+1]; out[o+x*4+2]=line[s+2]
            out[o+x*4+3] = line[s+3] if ch == 4 else 255
    return w, h, out


def read_ppm(path):
    d = open(path, 'rb').read()
    assert d[:2] == b'P6', 'bg must be a P6 PPM'
    i, vals = 2, []
    while len(vals) < 3:
        while d[i:i+1].isspace(): i += 1
        if d[i:i+1] == b'#':
            while d[i:i+1] != b'\n': i += 1
            continue
        s = i
        while not d[i:i+1].isspace(): i += 1
        vals.append(int(d[s:i]))
    w, h, _ = vals
    i += 1
    return w, h, d[i:i + w*h*3]


def sample(px, w, h, fx, fy):
    x0 = max(0, min(w-1, int(fx))); y0 = max(0, min(h-1, int(fy)))
    x1 = min(w-1, x0+1); y1 = min(h-1, y0+1)
    dx = fx - x0; dy = fy - y0
    out = [0, 0, 0, 0]
    for k in range(4):
        p00=px[(y0*w+x0)*4+k]; p10=px[(y0*w+x1)*4+k]
        p01=px[(y1*w+x0)*4+k]; p11=px[(y1*w+x1)*4+k]
        out[k] = (p00+(p10-p00)*dx) + ((p01+(p11-p01)*dx)-(p00+(p10-p00)*dx))*dy
    return out


def main():
    avatar, out = sys.argv[1], sys.argv[2]
    diameter   = int(sys.argv[3]) if len(sys.argv) > 3 else 290
    bg_ppm     = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] not in ('', '-') else None
    backing_r  = int(sys.argv[5]) if len(sys.argv) > 5 else 168
    dim        = float(sys.argv[6]) if len(sys.argv) > 6 else 0.40
    shape      = sys.argv[7] if len(sys.argv) > 7 else 'circle'  # 'square' for globe

    cx, cy = CW // 2, CH // 2
    canvas = bytearray(CW * CH * 3)                 # black

    # 1) background: dimmed, centre-cropped wallpaper
    if bg_ppm:
        pw, ph, bp = read_ppm(bg_ppm)
        offx, offy = max(0, (pw - CW)//2), max(0, (ph - CH)//2)
        table = bytes(int(i*dim) for i in range(256))
        for y in range(CH):
            srow = ((y+offy)*pw + offx)*3
            canvas[y*CW*3:(y+1)*CW*3] = bp[srow:srow + CW*3].translate(table)

    # 2) black backing disc so the orb reads clean over the wallpaper
    if backing_r > 0:
        br2 = backing_r*backing_r
        for y in range(cy-backing_r, cy+backing_r):
            for x in range(cx-backing_r, cx+backing_r):
                if (x-cx)**2 + (y-cy)**2 <= br2:
                    idx = (y*CW + x)*3
                    canvas[idx]=0; canvas[idx+1]=0; canvas[idx+2]=0

    # 3) avatar, scaled to fit `diameter`. shape='circle' masks it round (for the
    #    old flat orb); shape='square' keeps the full square (the spinning-globe
    #    shader reads it as an equirectangular texture, so it must be a square).
    sw, sh, px = read_png(avatar)
    scale = diameter / max(sw, sh)
    tw, th = int(sw*scale), int(sh*scale)
    ox, oy = cx - tw//2, cy - th//2
    r = diameter/2.0; r2 = r*r
    for ty in range(th):
        for tx in range(tw):
            X, Y = ox+tx, oy+ty
            if shape != 'square' and (X-cx)**2 + (Y-cy)**2 > r2: continue
            rr, gg, bb, aa = sample(px, sw, sh, tx/scale, ty/scale)
            a = aa/255.0; idx = (Y*CW + X)*3
            canvas[idx]   = int(rr*a)
            canvas[idx+1] = int(gg*a)
            canvas[idx+2] = int(bb*a)

    def chunk(t, p):
        return struct.pack('>I', len(p)) + t + p + struct.pack('>I', zlib.crc32(t+p) & 0xffffffff)
    raw = bytearray()
    for y in range(CH):
        raw.append(0); raw += canvas[y*CW*3:(y+1)*CW*3]
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', CW, CH, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 6))
    png += chunk(b'IEND', b'')
    open(out, 'wb').write(png)


if __name__ == '__main__':
    main()
