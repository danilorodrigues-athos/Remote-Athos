from PIL import Image, ImageDraw, ImageFont
import os

ROOT = r"C:\Users\RUSSO\Documents\Projeto Padrão\rustdesk"
OUT = os.path.join(ROOT, "branding", "no")
os.makedirs(OUT, exist_ok=True)

NAVY = (27, 37, 89, 255)
CYAN = (31, 169, 216, 255)
CYAN_DARK = (56, 198, 244, 255)
WHITE = (244, 247, 255, 255)
FONT = r"C:\Windows\Fonts\segoeuib.ttf"


def draw_n(draw, ox, oy, s, n_color, node_color):
    def p(x, y):
        return (ox + x * s, oy + y * s)

    w = 46 * s
    for a, b in (((168, 206), (168, 386)),
                 ((168, 206), (344, 386)),
                 ((344, 386), (344, 206))):
        draw.line([p(*a), p(*b)], fill=n_color, width=max(1, int(w)))
    for x, y in ((168, 206), (168, 386), (344, 386), (344, 206)):
        draw.ellipse([ox + (x - 23) * s, oy + (y - 23) * s,
                      ox + (x + 23) * s, oy + (y + 23) * s], fill=n_color)
    for x, y, r in ((168, 168, 38), (344, 386, 22)):
        draw.ellipse([ox + (x - r) * s, oy + (y - r) * s,
                      ox + (x + r) * s, oy + (y + r) * s], fill=node_color)


def wordmark(dark=False):
    ss = 4
    W, H = 320, 160
    img = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    n_color = WHITE if dark else NAVY
    node_color = CYAN_DARK if dark else CYAN
    s = 0.472
    ox, oy = 18, 132 - 386 * s
    draw_n(d, ox * ss, oy * ss, s * ss, n_color, node_color)

    font = ImageFont.truetype(FONT, 118 * ss)
    tx = ox + 366 * s + 8
    d.text((tx * ss, 132 * ss), "Ó", font=font, fill=n_color, anchor="ls")
    return img.resize((W, H), Image.LANCZOS)


for dark in (False, True):
    img = wordmark(dark)
    name = "wordmark_dark.png" if dark else "wordmark_light.png"
    img.save(os.path.join(OUT, name))
    print(name, img.size)
