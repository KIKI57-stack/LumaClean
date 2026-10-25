import math
import struct
import zlib

SIZE = 1024

BG_TOP = (13, 45, 41)
BG_BOTTOM = (4, 12, 11)
WHITE = (246, 250, 248)
ACCENT = (74, 222, 158)
DARK = (8, 26, 23)


def clamp(value, low=0.0, high=1.0):
    return low if value < low else high if value > high else value


def coverage(distance):
    return clamp(0.5 - distance)


def sd_round_rect(x, y, cx, cy, hw, hh, r):
    qx = abs(x - cx) - (hw - r)
    qy = abs(y - cy) - (hh - r)
    ax = qx if qx > 0 else 0.0
    ay = qy if qy > 0 else 0.0
    return math.hypot(ax, ay) + min(max(qx, qy), 0.0) - r


def sd_circle(x, y, cx, cy, r):
    return math.hypot(x - cx, y - cy) - r


def make_triangle(points):
    count = len(points)
    cx = sum(p[0] for p in points) / count
    cy = sum(p[1] for p in points) / count
    edges = []
    for index in range(count):
        ax, ay = points[index]
        bx, by = points[(index + 1) % count]
        ex, ey = bx - ax, by - ay
        length = math.hypot(ex, ey)
        cross = (ex * (cy - ay) - ey * (cx - ax)) / length
        edges.append((ax, ay, ex, ey, length))
    sign = 1.0 if cross > 0 else -1.0
    return edges, sign


def sd_triangle(x, y, triangle):
    edges, sign = triangle
    best = 1e9
    for ax, ay, ex, ey, length in edges:
        d = sign * ((ex * (y - ay) - ey * (x - ax)) / length)
        if d < best:
            best = d
    return best


FRAME = (500.0, 455.0, 235.0, 180.0, 42.0)
RING = 34.0
SUN = (392.0, 388.0, 37.0)
PEAK_A = make_triangle([(322.0, 592.0), (452.0, 412.0), (582.0, 592.0)])
PEAK_B = make_triangle([(516.0, 592.0), (598.0, 478.0), (688.0, 592.0)])
BADGE = (752.0, 744.0, 146.0)
CHECK_A = (700.0, 744.0, 740.0, 786.0, 21.0)
CHECK_B = (740.0, 786.0, 814.0, 700.0, 21.0)


def sd_segment(x, y, seg):
    ax, ay, bx, by, r = seg
    pax, pay = x - ax, y - ay
    bax, bay = bx - ax, by - ay
    denom = bax * bax + bay * bay
    t = 0.0 if denom == 0 else clamp((pax * bax + pay * bay) / denom)
    return math.hypot(pax - bax * t, pay - bay * t) - r


def blend(dst, src, alpha):
    if alpha <= 0.0:
        return dst
    if alpha >= 1.0:
        return src
    return (
        dst[0] + (src[0] - dst[0]) * alpha,
        dst[1] + (src[1] - dst[1]) * alpha,
        dst[2] + (src[2] - dst[2]) * alpha,
    )


def render():
    rows = []
    fcx, fcy, fhw, fhh, fr = FRAME
    for y in range(SIZE):
        row = bytearray()
        t = y / (SIZE - 1)
        bg = (
            BG_TOP[0] + (BG_BOTTOM[0] - BG_TOP[0]) * t,
            BG_TOP[1] + (BG_BOTTOM[1] - BG_TOP[1]) * t,
            BG_TOP[2] + (BG_BOTTOM[2] - BG_TOP[2]) * t,
        )
        for x in range(SIZE):
            color = bg

            outer = sd_round_rect(x, y, fcx, fcy, fhw, fhh, fr)
            inner = sd_round_rect(x, y, fcx, fcy, fhw - RING, fhh - RING, fr - RING * 0.7)
            ring = coverage(outer) - coverage(inner)
            if ring > 0:
                color = blend(color, WHITE, ring)

            if inner < 1.0:
                sun = coverage(sd_circle(x, y, SUN[0], SUN[1], SUN[2]))
                if sun > 0:
                    color = blend(color, WHITE, sun)
                peak = max(sd_triangle(x, y, PEAK_A), sd_triangle(x, y, PEAK_B))
                if peak > -1.0:
                    color = blend(color, WHITE, clamp(0.5 + peak))

            badge_outer = coverage(sd_circle(x, y, BADGE[0], BADGE[1], BADGE[2] + 14))
            if badge_outer > 0:
                color = blend(color, DARK, badge_outer)

            badge = coverage(sd_circle(x, y, BADGE[0], BADGE[1], BADGE[2]))
            if badge > 0:
                color = blend(color, ACCENT, badge)
                check = max(coverage(sd_segment(x, y, CHECK_A)), coverage(sd_segment(x, y, CHECK_B)))
                if check > 0:
                    color = blend(color, WHITE, check)

            row.append(int(clamp(color[0], 0, 255)))
            row.append(int(clamp(color[1], 0, 255)))
            row.append(int(clamp(color[2], 0, 255)))
        rows.append(bytes(row))
    return rows


def write_png(path, rows):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)


if __name__ == "__main__":
    import os

    # 同一个图标需要出现在两个位置，分别服务于两条构建通道：
    #   Resources/AppIcon.png                     -> xtool 通道（xtool.yml 的 iconPath）
    #   Assets/.../AppIcon.appiconset/icon-1024.png -> Xcode 通道（actool 读取）
    # 两处内容完全一致，所以只渲染一次、写两次，避免出现两份不同版本的图标。
    rows = render()
    targets = [
        "Resources/AppIcon.png",
        "Assets/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
    ]
    for target in targets:
        parent = os.path.dirname(target)
        if parent:
            os.makedirs(parent, exist_ok=True)
        write_png(target, rows)
        print("wrote", target)
    print("done")

