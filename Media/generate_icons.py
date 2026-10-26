"""Build the small monochrome header icons as antialiased RGBA TGA assets."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
SCALE = 4

def make_icon(name, draw_icon):
    image = Image.new("RGBA", (32 * SCALE, 32 * SCALE))
    draw = ImageDraw.Draw(image)
    def line(points):
        draw.line([(x*SCALE, y*SCALE) for x,y in points], fill="white", width=2*SCALE, joint="curve")
    def ellipse(box):
        draw.ellipse(tuple(v*SCALE for v in box), outline="white", width=2*SCALE)
    draw_icon(line, ellipse)
    image.resize((32, 32), Image.Resampling.LANCZOS).save(ROOT / (name + ".tga"))

make_icon("IconCopy", lambda line, circle: (
    line([(10,8),(10,5),(26,5),(26,22),(23,22)]),
    line([(6,11),(20,11),(20,28),(6,28),(6,11)]),
))
make_icon("IconProfile", lambda line, circle: (
    circle((11,4,21,14)),
    line([(5,27),(5,24),(7,20),(11,18),(21,18),(25,20),(27,24),(27,27)]),
))
make_icon("IconInvite", lambda line, circle: (
    circle((7,4,17,14)),
    line([(3,27),(3,24),(5,20),(9,18),(15,18),(18,20)]),
    line([(24,17),(24,27)]), line([(19,22),(29,22)]),
))
make_icon("IconClose", lambda line, circle: (
    line([(8,8),(24,24)]), line([(24,8),(8,24)]),
))
