#!/usr/bin/env python3
"""Guild Trip: Vorschau-Bild der Seiten (Entwicklerwerkzeug, wird nicht mitgeliefert).

Liest die JSON-Datei aus scripts/render_ui.lua und schreibt eine HTML-Seite, auf der
jede Addon-Seite so gezeichnet ist, wie der Code sie anordnet. Eigene TGA-Bilder werden
als PNG eingebettet, Blizzard-Vorlagen (Knopf, Reiter, Rahmen) nur nachempfunden.

Aufruf: python3 -I scripts/render_ui.py <ui.json> <ausgabe.html> [Titel]
"""
import base64
import html
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
try:
    from PIL import Image
except ImportError:  # ohne Pillow nur Kaesten
    Image = None

_cache = {}


def texture_uri(path):
    """Interface\\AddOns\\ONE_x\\...\\name(.tga) -> data:-URI oder None."""
    if path in _cache:
        return _cache[path]
    uri = None
    m = re.match(r"(?i)interface[\\/]+addons[\\/]+(ONE_\w+)[\\/]+(.*)$", path or "")
    if m and Image:
        rel = m.group(2).replace("\\", "/")
        base = os.path.join(ROOT, "src", m.group(1), rel)
        for cand in (base, base + ".tga", base + ".png", base + ".blp"):
            if os.path.isfile(cand) and not cand.endswith(".blp"):
                try:
                    img = Image.open(cand).convert("RGBA")
                    buf = io.BytesIO()
                    img.save(buf, "PNG")
                    uri = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
                    _cache[path + "#size"] = img.size
                except OSError:
                    pass
                break
    _cache[path] = uri
    return uri


GOLD, WHITE, GREY = (1, .82, 0), (1, 1, 1), (.5, .5, .5)
FONT_COLOR = {"gold": GOLD, "white": WHITE, "grey": GREY, "red": (1, .1, .1), "green": (.1, 1, .1)}


def rgba(c, a=None):
    if not c:
        return "transparent"
    r, g, b = c[0], c[1], c[2]
    al = c[3] if len(c) > 3 else 1
    if a is not None:
        al *= a
    return "rgba(%d,%d,%d,%.2f)" % (r * 255, g * 255, b * 255, al)


def font_color(it):
    if it.get("c"):
        return rgba(it["c"])
    f = (it.get("f") or "GameFontNormal")
    if "Highlight" in f or "White" in f or "Chat" in f:
        return rgba(WHITE)
    if "Disable" in f:
        return rgba(GREY)
    return rgba(GOLD)


WOW_CODE = re.compile(r"\|c([0-9a-fA-F]{8})(.*?)(\|r|$)", re.S)


def wow_text(t):
    t = t.replace("|n", "\n")
    t = re.sub(r"\|T[^|]*\|t", "◆", t)
    t = re.sub(r"\|H[^|]*\|h(.*?)\|h", r"\1", t)
    t = re.sub(r"\|cn[^:]*:", "", t)
    out, pos = [], 0
    for m in WOW_CODE.finditer(t):
        out.append(html.escape(t[pos:m.start()]))
        col = m.group(1)[2:]
        out.append('<span style="color:#%s">%s</span>' % (col, html.escape(m.group(2))))
        pos = m.end()
    out.append(html.escape(t[pos:]))
    return "".join(out).replace("|r", "").replace("\n", "<br>")


CSS = """
body{background:#20242b;color:#ddd;font-family:'Friz Quadrata TT','Trebuchet MS',sans-serif;margin:16px}
h1{font-size:18px;color:#fc0} h2{font-size:14px;color:#aaa;margin:18px 0 6px}
.page{position:relative;overflow:visible;margin:0 0 10px 0}\n.cell{display:inline-block;vertical-align:top;margin:0 24px 0 0}
.e{position:absolute;box-sizing:border-box}
.fs{white-space:pre-wrap;line-height:1.15;overflow:hidden;text-shadow:1px -1px 0 rgba(0,0,0,.8)}
.portrait{background:linear-gradient(#2a2620,#14110d);border:3px solid #5d523f;border-radius:4px;box-shadow:0 0 0 1px #000,0 6px 24px rgba(0,0,0,.7)}
.inset{background:rgba(0,0,0,.35);border:2px solid #3b342a;box-shadow:inset 0 0 6px #000}
.btn{background:linear-gradient(#a3190f,#5a0b05);border:1px solid #2b0703;border-radius:3px;box-shadow:inset 0 1px 0 rgba(255,200,120,.35),0 0 0 1px #6a5a3a}
.btn.dis{filter:grayscale(1) brightness(.6)}
.tab{background:linear-gradient(#3a2f22,#1d1710);border:2px solid #5d523f;border-top:none;border-radius:0 0 6px 6px}
.tab.sel{background:linear-gradient(#5a4a33,#2a2117);height:36px!important}
.chk{background:#111;border:2px solid #8a7a55;border-radius:3px}
.chk.on::after{content:'✓';color:#fc0;font-size:16px;position:absolute;left:2px;top:-3px}
.edit{background:rgba(0,0,0,.6);border:1px solid #5d523f;border-radius:2px}
.close{background:radial-gradient(#a01b10,#4a0805);border:1px solid #c9a24a;border-radius:4px}
.close::after{content:'×';color:#fff;position:absolute;left:6px;top:-2px;font-size:18px}
.slider{background:#000;border:1px solid #5d523f;border-radius:6px}
.tex{background-repeat:no-repeat}
"""


def render_page(page, scale, book=False):
    W, H = page.get("w") or 774, page.get("h") or 548
    parts = ['<div class="page" style="width:%dpx;height:%dpx">' % (W * scale, (H + 50) * scale)]
    for it in page["items"]:
        k = it["k"]
        x, y, w, h = it["x"] * scale, it["y"] * scale, it["w"] * scale, it["h"] * scale
        st = "left:%.1fpx;top:%.1fpx;width:%.1fpx;height:%.1fpx;z-index:%d;" % (x, y, w, h, it["z"])
        tpl = it.get("tpl") or ""
        if k == "FontString":
            fs = (it.get("fs") or 12) * scale
            align = {"LEFT": "left", "RIGHT": "right", "CENTER": "center"}.get(it.get("jh") or "", "left")
            if it.get("btn"):
                align = "center"
            if not it.get("w") or it["w"] < 2:
                st += "width:auto;"
            vert = "display:flex;align-items:center;justify-content:%s;" % (
                {"left": "flex-start", "right": "flex-end", "center": "center"}[align]) if it.get("btn") else ""
            parts.append('<div class="e fs" style="%s%sfont-size:%.1fpx;color:%s;text-align:%s">%s</div>' % (
                st, vert, fs, font_color(it), align, wow_text(it["t"])))
            continue
        if k == "Texture":
            a = it.get("a")
            if it.get("grad"):
                g = it["grad"]
                deg = "90deg" if g[0] == "HORIZONTAL" else "0deg"
                parts.append('<div class="e" style="%sbackground:linear-gradient(%s,%s,%s)"></div>' % (st, deg, rgba(g[1]), rgba(g[2])))
                continue
            if it.get("col"):
                col = it["col"]
                if it.get("v"):
                    col = [col[i] * it["v"][i] for i in range(3)] + [col[3] * it["v"][3]]
                parts.append('<div class="e" style="%sbackground:%s;%s"></div>' % (
                    st, rgba(col), "opacity:%.2f;" % a if a is not None else ""))
                continue
            uri = texture_uri(it.get("tex") or "")
            if not uri:
                continue
            bg = "background-image:url(%s);background-size:100%% 100%%;" % uri
            tc = it.get("tc")
            if tc and len(tc) >= 4:
                l, r, t, b = tc[0], tc[1], tc[2], tc[3]
                if len(tc) == 8:  # ULx,ULy,LLx,LLy,URx,URy,LRx,LRy
                    l, t, r, b = tc[0], tc[1], tc[6], tc[7]
                if r > l and b > t:
                    bw, bh = w / (r - l), h / (b - t)
                    bg = "background-image:url(%s);background-size:%.1fpx %.1fpx;background-position:%.1fpx %.1fpx;" % (
                        uri, bw, bh, -l * bw, -t * bh)
            filt = ""
            if it.get("v"):
                v = it["v"]
                if max(v[:3]) - min(v[:3]) <= .15 and max(v[:3]) < 1 and v[3] == 1:
                    # leichte Toenung eines Bildes (z. B. Buch-Papier): als Helligkeit + etwas Sepia
                    filt = "filter:brightness(%.2f) sepia(%.2f);" % (sum(v[:3]) / 3, min(.4, (v[0] - v[2]) * 4))
                elif v[0] == v[1] == v[2] and v[0] != 1:
                    filt = "filter:brightness(%.2f);" % v[0]
                elif not (v[0] == v[1] == v[2] == 1):
                    # Einfaerben grob: Helligkeit + Farbton ueber Mischung
                    filt = "filter:drop-shadow(0 0 0 transparent);"
                    bg += "background-color:transparent;"
                    parts.append('<div class="e tex" style="%s%sopacity:%.2f;-webkit-mask-image:url(%s);mask-image:url(%s);mask-size:100%% 100%%;background:%s"></div>' % (
                        st, "", (a if a is not None else 1) * v[3], uri, uri, rgba(v[:3] + [1])))
                    continue
            parts.append('<div class="e tex" style="%s%s%s%s"></div>' % (
                st, bg, filt, "opacity:%.2f;" % a if a is not None else ""))
            continue
        cls = None
        if book and (it.get("nine") or "PortraitFrame" in tpl or "InsetFrame" in tpl):
            cls = None
        elif "PortraitFrame" in tpl or "ButtonFrameTemplate" in tpl:
            cls = "portrait"
        elif it.get("nine") or "InsetFrame" in tpl:
            cls = "inset"
        elif "PanelTabButton" in tpl or "TabButton" in tpl:
            cls = "tab" + (" sel" if it.get("sel") else "")
        elif "CloseButton" in tpl:
            cls = "close"
        elif "UIPanelButton" in tpl or "UIMenuButtonStretch" in tpl:
            cls = "btn" + (" dis" if it.get("dis") else "")
        elif "CheckButton" in tpl or k == "CheckButton":
            cls = "chk" + (" on" if it.get("chk") else "")
        elif k == "EditBox" or "SearchBox" in tpl or "InputBox" in tpl:
            cls = "edit"
        elif k == "Slider":
            cls = "slider"
        if cls:
            parts.append('<div class="e %s" style="%s"></div>' % (cls, st))
        if it.get("t") and k in ("Button", "CheckButton") and cls and cls.startswith(("btn", "tab")):
            parts.append('<div class="e fs" style="%sdisplay:flex;align-items:center;justify-content:center;font-size:%.1fpx;color:%s;z-index:%d">%s</div>' % (
                st, 12 * scale, rgba(GOLD if not it.get("dis") else GREY), it["z"] + 1, wow_text(it["t"])))
    parts.append("</div>")
    return "".join(parts)


def main():
    data = json.load(open(sys.argv[1], encoding="utf-8"))
    out = sys.argv[2]
    title = sys.argv[3] if len(sys.argv) > 3 else "Guild Trip – Seiten"
    scale = float(os.environ.get("SCALE", "1"))
    body = ["<h1>%s</h1>" % html.escape(title)]
    for page in data["pages"]:
        body.append('<div class="cell"><h2>%s</h2>%s</div>' % (html.escape(page["id"]), render_page(page, scale, data.get("mode") == "book")))
    if data.get("errors"):
        body.append("<h2>Fehler beim Nachzeichnen</h2><pre>%s</pre>" % html.escape("\n".join(data["errors"])))
    with open(out, "w", encoding="utf-8") as f:
        f.write("<!doctype html><meta charset=utf-8><title>%s</title><style>%s</style>%s" % (
            html.escape(title), CSS, "".join(body)))
    print("geschrieben:", out)


if __name__ == "__main__":
    main()
