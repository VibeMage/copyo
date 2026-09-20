#!/usr/bin/env python3
# Generates the Copyo Mac design artboards (.dc.html) into project/.
import json, os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "project")
MONO = "ui-monospace, 'SF Mono', Menlo, monospace"

L = dict(
    grouped="#F2F2F7", card="#FFFFFF", raised="#FFFFFF", label="#000000",
    meta="rgba(60,60,67,0.78)", sec="rgba(60,60,67,0.60)", ter="rgba(60,60,67,0.34)",
    fill="rgba(118,118,128,0.12)", fill2="rgba(118,118,128,0.20)", sep="rgba(60,60,67,0.24)",
    glass="rgba(255,255,255,0.74)", ring="inset 0 0 0 0.5px rgba(0,0,0,0.06)",
    cring="inset 0 0 0 0.5px rgba(0,0,0,0.05)", desktop="#4E5766",
    d1="#5E6878", d2="#47505E", dock="rgba(255,255,255,0.20)", dockr="rgba(255,255,255,0.28)",
    swatchring="inset 0 0 0 0.5px rgba(0,0,0,0.08)",
)
D = dict(
    grouped="#1C1C1E", card="#2C2C2E", raised="#3A3A3C", label="#FFFFFF",
    meta="rgba(235,235,245,0.72)", sec="rgba(235,235,245,0.60)", ter="rgba(235,235,245,0.34)",
    fill="rgba(118,118,128,0.24)", fill2="rgba(118,118,128,0.32)", sep="rgba(84,84,88,0.60)",
    glass="rgba(58,58,60,0.72)", ring="inset 0 0 0 0.5px rgba(255,255,255,0.15)",
    cring="inset 0 0 0 0.5px rgba(255,255,255,0.06)", desktop="#22262E",
    d1="#2B3039", d2="#1B1F26", dock="rgba(255,255,255,0.12)", dockr="rgba(255,255,255,0.16)",
    swatchring="inset 0 0 0 0.5px rgba(255,255,255,0.10)",
)
ACCENT, DESTRUCT_L, DESTRUCT_D = "#0A84FF", "#FF3B30", "#FF453A"
SUCCESS_L, SUCCESS_D, WARN = "#34C759", "#30D158", "#FF9F0A"
BONE, BRED, BBLUE, INK = "#F7F3EA", "#FF2D55", "#0A84FF", "#16161A"

# kind -> (label_zh, svg_inner, filled)
ICON = {
    "text":  ('文本', '<path d="M3 3.2h10M8 3.2v9.6M5.6 12.8h4.8"></path>', False),
    "rich":  ('富文本', '<path d="M3.2 13L7 3.2h2L12.8 13M5.2 10h5.6"></path>', False),
    "link":  ('链接', '<path d="M6.6 9.4l2.8-2.8M6.2 4.6l1.2-1.2a2.6 2.6 0 0 1 3.7 3.7L9.9 8.3M7 11.4l-1.2 1.2a2.6 2.6 0 0 1-3.7-3.7l1.8-1.8"></path>', False),
    "image": ('图片', '<rect x="1.8" y="3.2" width="12.4" height="9.6" rx="1.6"></rect><path d="M2.4 10.8l3.4-3 2.9 2.4 2.4-1.9 2.9 2.8"></path>', False),
    "color": ('颜色', '<path d="M8 1.6s4.2 4.9 4.2 7.3a4.2 4.2 0 0 1-8.4 0C3.8 6.5 8 1.6 8 1.6z"></path>', True),
    "file":  ('文件', '<path d="M4 1.8h5l3.2 3.2v9.2H4z"></path><path d="M8.9 1.8V5h3.3"></path>', False),
}

def icon(kind, color, size=10):
    label, inner, filled = ICON[kind]
    if filled:
        return ('<svg width="%d" height="%d" viewBox="0 0 16 16" fill="%s" aria-hidden="true">%s</svg>'
                % (size, size, color, inner))
    return ('<svg width="%d" height="%d" viewBox="0 0 16 16" fill="none" stroke="%s" stroke-width="1.7" '
            'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">%s</svg>' % (size, size, color, inner))

def stroke(inner, color, size=14, w=1.6):
    return ('<svg width="%d" height="%d" viewBox="0 0 16 16" fill="none" stroke="%s" stroke-width="%s" '
            'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">%s</svg>' % (size, size, color, w, inner))

SEARCH_I = '<circle cx="7" cy="7" r="4.6"></circle><path d="M10.4 10.4L14 14"></path>'
GEAR_I = ('<circle cx="8" cy="8" r="2.6"></circle><path d="M8 1.4v1.8M8 12.8v1.8M14.6 8h-1.8M3.2 8H1.4'
          'M12.7 3.3l-1.3 1.3M4.6 11.4l-1.3 1.3M12.7 12.7l-1.3-1.3M4.6 4.6L3.3 3.3"></path>')
CLOUD_OK_I = ('<path d="M4.4 12.4h6.9a2.8 2.8 0 0 0 .3-5.6A4 4 0 0 0 4 6.6a2.9 2.9 0 0 0 .4 5.8z"></path>'
              '<path d="M6.3 9.3l1.3 1.3 2.5-2.6"></path>')
CHEV_I = '<path d="M4 6.5l4 4 4-4"></path>'
PIN_I = '<path d="M6.1 1.9h3.8l-.5 3.9 2 2v1.1H8.6v5.2l-.6.9-.6-.9V8.9H4.6V7.8l2-2z"></path>'
TRASH_I = '<path d="M3 4.2h10M6.4 4.2V2.6h3.2v1.6M4.5 4.2l.6 9.2h5.8l.6-9.2M6.9 6.6v4.6M9.1 6.6v4.6"></path>'
CHECK_I = '<path d="M3.4 8.4l3 3 6.2-6.6"></path>'
CLIP_I = '<rect x="3.6" y="2.8" width="8.8" height="11.4" rx="1.8"></rect><rect x="5.6" y="1.2" width="4.8" height="3" rx="1.2"></rect>'

# sources: name -> (hex, tintLight, tintDark)
SRC = {
    "Xcode":   ("#147EFB", "#E3F0FE", "#273C57"),
    "微信":     ("#07C160", "#E1F8EC", "#254A38"),
    "Safari":  ("#1EA7FD", "#E4F4FF", "#294457"),
    "Figma":   ("#A259FF", "#F4EBFF", "#443558"),
    "备忘录":   ("#FFC300", "#FFF8E0", "#564A25"),
    "VS Code": ("#0098FF", "#E0F3FF", "#234258"),
    "访达":     ("#1EA7FD", "#E4F4FF", "#294457"),
    "本机":     ("#8E8E93", "#F1F1F2", "#404042"),
}
COLORCLIP = ("#FF2D55", "#FFE6EB", "#562E36")   # a color clip tints with ITS OWN colour

def onband(hexv):
    r, g, b = int(hexv[1:3], 16), int(hexv[3:5], 16), int(hexv[5:7], 16)
    lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    return INK if lum > 0.62 else "#FFFFFF"

def badge(kind, bg, dense=True):
    fg = onband(bg)
    h, fs, pad, gap, r = (18, 10, "0 6px 0 5px", 3, 9) if dense else (20, 11, "0 7px 0 6px", 4, 10)
    return ('<span style="display: inline-flex; align-items: center; gap: %dpx; height: %dpx; padding: %s; '
            'border-radius: %dpx; background: %s; color: %s; font-size: %dpx; font-weight: 600; white-space: nowrap; '
            'flex: none;">%s%s</span>' % (gap, h, pad, r, bg, fg, fs, icon(kind, fg, 10 if dense else 11), ICON[kind][0]))

def keycap(t, th):
    return ('<span style="display: inline-flex; align-items: center; justify-content: center; min-width: 20px; '
            'height: 20px; padding: 0 5px; box-sizing: border-box; border-radius: 6px; background: %s; '
            'font-family: %s; font-size: 11px; font-weight: 500; color: %s;">%s</span>'
            % (th["fill2"], MONO, th["meta"], t))

def hint(cap, text, th):
    return ('<span style="display: inline-flex; align-items: center; gap: 5px; font-size: 11px; color: %s;">%s%s</span>'
            % (th["sec"], keycap(cap, th), text))

def chip(text, th, on=False, chev=False):
    if on:
        st = "background: %s; color: #FFFFFF; font-weight: 600;" % ACCENT
    else:
        st = "background: %s; color: %s; font-weight: 500;" % (th["fill"], th["label"])
    inner = "<span>%s</span>%s" % (text, stroke(CHEV_I, th["sec"], 11, 1.8) if chev else "")
    pad = "0 9px 0 11px" if chev else "0 11px"
    return ('<button type="button" style="display: inline-flex; align-items: center; gap: 5px; height: 26px; '
            'padding: %s; border-radius: 8px; font-size: 12px; %s">%s</button>' % (pad, st, inner))

def card(th, kind, src, meta, body_html, w=260, h=184, sel=None, hover=False, pinned=False, tint=None, srccol=None):
    s_hex, tl, td = SRC.get(src, ("#8E8E93", "#F1F1F2", "#404042"))
    if srccol:
        s_hex = srccol
    t = tint or (td if th is D else tl)
    ring = th["cring"]
    if sel == "focus":
        ring = "0 0 0 2px %s, 0 0 0 7px rgba(10,132,255,0.32)" % ACCENT
    elif sel == "select":
        ring = "0 0 0 3px %s" % ACCENT
    elif sel == "key-inactive":
        ring = "0 0 0 3px rgba(10,132,255,0.45)"
    lift = " transform: rotate(-2deg) scale(1.03);" if sel == "lift" else ""
    if sel == "lift":
        ring = "%s, 0 12px 32px rgba(0,0,0,0.28)" % th["cring"]
    cluster = ""
    if hover:
        btn = ('<button type="button" aria-label="%s" style="width: 24px; height: 24px; border-radius: 7px; '
               'display: flex; align-items: center; justify-content: center;">%s</button>')
        cluster = ('<div style="position: absolute; right: 8px; top: 8px; display: flex; align-items: center; gap: 2px; '
                   'height: 28px; padding: 0 3px; border-radius: 9px; background: %s; backdrop-filter: blur(14px); '
                   '-webkit-backdrop-filter: blur(14px); box-shadow: %s, 0 2px 8px rgba(0,0,0,0.14);">%s%s</div>'
                   % (th["glass"], th["ring"],
                      btn % ("固定到 Pinboard", stroke(PIN_I, ACCENT, 14, 1.5)),
                      btn % ("删除", stroke(TRASH_I, DESTRUCT_D if th is D else DESTRUCT_L, 14, 1.5))))
    pin_mark = ""
    if pinned:
        pin_mark = ('<span style="flex: none; display: inline-flex;" aria-label="已固定">%s</span>'
                    % stroke(PIN_I, ACCENT, 11, 1.6))
    meta_cell = ('<span style="flex-grow: 1; min-width: 0; font-size: 10px; color: %s; white-space: nowrap; '
                 'overflow: hidden; text-overflow: ellipsis;">%s</span>' % (th["meta"], meta))
    return ('<div style="position: relative; width: %dpx; height: %dpx; flex: none; box-sizing: border-box; '
            'padding: 12px; border-radius: 12px; background: %s; box-shadow: %s;%s display: flex; '
            'flex-direction: column; gap: 8px;">'
            '<div style="display: flex; align-items: center; gap: 6px; height: 18px;">%s%s%s</div>'
            '%s'
            '<div style="height: 20px; display: flex; align-items: center; justify-content: flex-end;">'
            '<span style="width: 20px; height: 20px; border-radius: 5px; background: %s; box-shadow: %s;"></span>'
            '</div>%s</div>'
            % (w, h, t, ring, lift, badge(kind, s_hex), meta_cell, pin_mark, body_html, s_hex, th["swatchring"], cluster))

def body_text(th, txt, clamp=7, mono=False):
    fam = ("font-family: %s; font-size: 11px; line-height: 15px;" % MONO) if mono else "font-size: 12px; line-height: 16px;"
    return ('<div style="flex-grow: 1; min-height: 0; white-space: pre-line; %s color: %s; overflow: hidden; display: -webkit-box; '
            '-webkit-line-clamp: %d; -webkit-box-orient: vertical; word-break: break-word;">%s</div>'
            % (fam, th["label"], clamp, txt))

def body_link(th, title, dom):
    return ('<div style="flex-grow: 1; min-height: 0; display: flex; flex-direction: column; gap: 6px; overflow: hidden;">'
            '<div style="font-size: 12px; line-height: 16px; font-weight: 500; color: %s; overflow: hidden; '
            'display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical;">%s</div>'
            '<div style="font-size: 11px; line-height: 15px; color: %s; white-space: nowrap; overflow: hidden; '
            'text-overflow: ellipsis;">%s</div></div>' % (th["label"], title, ACCENT, dom))

def body_color(th, hexv):
    return ('<div style="flex-grow: 1; min-height: 0; display: flex; flex-direction: column; gap: 8px;">'
            '<div style="flex-grow: 1; border-radius: 10px; background: %s; box-shadow: %s;"></div>'
            '<div style="display: inline-flex; align-self: flex-start; align-items: center; height: 22px; padding: 0 8px; '
            'border-radius: 11px; background: %s; font-family: %s; font-size: 11px; font-weight: 600; color: %s;">%s</div>'
            '</div>' % (hexv, th["swatchring"], th["fill2"], MONO, th["label"], hexv))

def body_image(th, fill):
    return ('<div style="flex-grow: 1; min-height: 0; border-radius: 10px; background: %s; box-shadow: %s;"></div>'
            % (fill, th["swatchring"]))

def body_files(th, first, more):
    sq = ('<span style="position: absolute; left: %dpx; top: %dpx; width: 30px; height: 30px; border-radius: 7px; '
          'background: %s; box-shadow: %s;"></span>')
    stack = ('<div style="position: relative; width: 46px; height: 38px; flex: none;">%s%s%s</div>'
             % (sq % (0, 6, th["fill2"], th["swatchring"]),
                sq % (7, 3, th["fill2"], th["swatchring"]),
                sq % (14, 0, "#1EA7FD", th["swatchring"])))
    return ('<div style="flex-grow: 1; min-height: 0; display: flex; flex-direction: column; gap: 8px;">%s'
            '<div style="font-size: 12px; line-height: 16px; color: %s; overflow: hidden; display: -webkit-box; '
            '-webkit-line-clamp: 2; -webkit-box-orient: vertical; word-break: break-all;">%s</div>'
            '<div style="font-size: 11px; color: %s;">%s</div></div>'
            % (stack, th["label"], first, th["meta"], more))

CARDS = lambda th: [
    card(th, "text", "Xcode", "Xcode · 2 分钟前",
         body_text(th, "git rebase -i HEAD~3 &amp;&amp; git push --force-with-lease", mono=True)),
    card(th, "text", "微信", "微信 · 12 分钟前",
         body_text(th, "周五下午三点在 3 楼小会议室对一下 Q4 的排期，记得把上周的漏斗数据带上，顺便看看新江湾那边场地的报价。")),
    card(th, "link", "Safari", "Safari · 25 分钟前",
         body_link(th, "Adopting Liquid Glass | Apple Developer Documentation", "developer.apple.com")),
    card(th, "color", "Figma", "Figma · 1 小时前",
         body_color(th, COLORCLIP[0]), tint=(COLORCLIP[2] if th is D else COLORCLIP[1]), srccol=COLORCLIP[0]),
    card(th, "image", "备忘录", "备忘录 · 昨天 18:42",
         body_image(th, "#F0E4BE" if th is not D else "#4A431F")),
]

def topbar(th, query=None, active="全部", showchips=True):
    field_text = (('<span style="flex-grow: 1; font-size: 13px; color: %s;">%s<span style="display: inline-block; '
                   'width: 1.5px; height: 15px; margin-left: 1px; vertical-align: -3px; background: %s;"></span></span>')
                  % (th["label"], query, ACCENT)) if query else \
        ('<label for="q" style="position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0);">搜索历史</label>'
         '<input id="q" type="text" placeholder="搜索历史" style="flex-grow: 1; border: 0; background: none; outline: none; '
         'font-family: inherit; font-size: 13px; color: %s;">' % th["label"])
    ring = "box-shadow: 0 0 0 2px %s, 0 0 0 6px rgba(10,132,255,0.28);" % ACCENT if query else ""
    row1 = ('<div style="display: flex; align-items: center; gap: 8px; height: 32px;">'
            '<div style="flex-grow: 1; display: flex; align-items: center; gap: 6px; height: 32px; padding: 0 10px; '
            'box-sizing: border-box; border-radius: 8px; background: %s; %s">%s%s</div>'
            '<button type="button" aria-label="iCloud 已同步" title="iCloud 已同步" style="width: 32px; height: 32px; '
            'border-radius: 8px; display: flex; align-items: center; justify-content: center;">%s</button>'
            '<button type="button" aria-label="设置" title="设置" style="width: 32px; height: 32px; border-radius: 8px; '
            'display: flex; align-items: center; justify-content: center;">%s</button></div>'
            % (th["fill"], ring, stroke(SEARCH_I, th["sec"]), field_text,
               stroke(CLOUD_OK_I, SUCCESS_D if th is D else SUCCESS_L, 17, 1.5),
               stroke(GEAR_I, th["sec"], 17, 1.5)))
    if not showchips:
        return row1
    names = ["全部", "文本", "链接", "图片", "颜色", "文件"]
    chips = "".join(chip(n, th, on=(n == active)) for n in names)
    row2 = ('<div style="height: 10px;"></div>'
            '<div style="display: flex; align-items: center; gap: 8px; height: 26px;">'
            '<div style="display: flex; align-items: center; gap: 6px; flex-grow: 1;">%s</div>%s</div>'
            % (chips, chip("Pinboard", th, chev=True)))
    return row1 + row2

def hintbar(th, right="复制后回到原来的 App，按 ⌘V 粘贴"):
    return ('<div style="display: flex; align-items: center; gap: 14px; height: 24px;">%s%s%s%s'
            '<span style="flex-grow: 1;"></span>'
            '<span style="font-size: 11px; color: %s;">%s</span></div>'
            % (hint("↩", "复制", th), hint("空格", "预览", th), hint("⌘P", "固定", th), hint("⌘⌫", "删除", th),
               th["sec"], right))

def panel(th, inner, w=1280, h=332):
    return ('<div style="width: %dpx; height: %dpx; box-sizing: border-box; padding: 16px; border-radius: 26px; '
            'background: %s; backdrop-filter: blur(24px); -webkit-backdrop-filter: blur(24px); '
            'box-shadow: %s, 0 1px 3px rgba(0,0,0,0.10), 0 24px 56px rgba(0,0,0,0.30); display: flex; '
            'flex-direction: column;">%s</div>' % (w, h, th["glass"], th["ring"], inner))

def track(cards_html, h=184):
    return '<div style="display: flex; gap: 12px; height: %dpx; overflow: hidden;">%s</div>' % (h, cards_html)

def page(title, w, h, body, lang="zh-CN", bg="#ECEBE7"):
    return ('<!doctype html>\n<html lang="%s">\n<head>\n<meta charset="utf-8">\n<title>%s</title>\n'
            '<script src="./support.js"></script>\n</head>\n<body>\n<x-dc>\n<helmet>\n<style>\n'
            'body { margin: 0; font-family: -apple-system, "SF Pro Text", "PingFang SC", system-ui, sans-serif; background: %s; }\n'
            'a { color: #0A84FF; } a:hover { color: #0066CC; }\n'
            'button { font-family: inherit; border: 0; background: none; padding: 0; cursor: default; }\n'
            '</style>\n</helmet>\n%s\n</x-dc>\n'
            '<script type="text/x-dc" data-dc-script data-props=\'{"$preview":{"width":%d,"height":%d}}\'>\n'
            'class Component extends DCLogic {\n  renderVals() {\n    return {};\n  }\n}\n</script>\n</body>\n</html>\n'
            % (lang, title, bg, body, w, h))

def desktop_frame(th, panel_html, w=1440, h=520, px=80, py=92, dock=True):
    d = ('<div style="position: absolute; left: %dpx; top: %dpx; width: 560px; height: 64px; border-radius: 18px; '
         'background: %s; box-shadow: inset 0 0 0 0.5px %s;"></div>' % ((w - 560) // 2, h - 72, th["dock"], th["dockr"])) if dock else ""
    return ('<div style="width: %dpx; height: %dpx; box-sizing: border-box; position: relative; overflow: hidden; background: %s;">'
            '<div style="position: absolute; left: 118px; top: 44px; width: 420px; height: 420px; border-radius: 210px; background: %s;"></div>'
            '<div style="position: absolute; left: %dpx; top: -60px; width: 520px; height: 520px; border-radius: 260px; background: %s;"></div>'
            '%s<div style="position: absolute; left: %dpx; top: %dpx;">%s</div></div>'
            % (w, h, th["desktop"], th["d1"], w - 560, th["d2"], d, px, py, panel_html))

def flat_frame(th, panel_html, w=1360, h=412, px=40, py=40):
    return ('<div style="width: %dpx; height: %dpx; box-sizing: border-box; position: relative; overflow: hidden; background: %s;">'
            '<div style="position: absolute; left: %dpx; top: %dpx;">%s</div></div>'
            % (w, h, th["desktop"], px, py, panel_html))

FILES = {}

# ---------- 2. A 版 面板 · 深色 ----------
inner = topbar(D) + '<div style="height: 12px;"></div>' + track("".join(CARDS(D))) + \
        '<div style="height: 12px;"></div>' + hintbar(D)
FILES["A-panel-dark.dc.html"] = page("A 版 · 悬浮面板 · 深色", 1440, 520,
                                     desktop_frame(D, panel(D, inner)))

# ---------- 3. A 版 悬停 + Toast ----------
th = L
cs = CARDS(th)
cs[1] = card(th, "text", "微信", "微信 · 12 分钟前",
             body_text(th, "周五下午三点在 3 楼小会议室对一下 Q4 的排期，记得把上周的漏斗数据带上，顺便看看新江湾那边场地的报价。"),
             hover=True)
cs[0] = card(th, "text", "Xcode", "Xcode · 2 分钟前",
             body_text(th, "git rebase -i HEAD~3 &amp;&amp; git push --force-with-lease", mono=True), sel="focus")
toast = ('<div style="position: absolute; left: 50%%; bottom: 60px; transform: translateX(-50%%); display: flex; '
         'align-items: center; gap: 7px; height: 36px; padding: 0 16px; border-radius: 18px; background: %s; '
         'backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); box-shadow: %s, 0 6px 20px rgba(0,0,0,0.18); '
         'font-size: 13px; font-weight: 500; color: %s;">%s已复制 · 按 ⌘V 粘贴</div>'
         % (th["glass"], th["ring"], th["label"], stroke(CHECK_I, SUCCESS_L, 14, 2)))
inner = topbar(th) + '<div style="height: 12px;"></div>' + track("".join(cs)) + \
        '<div style="height: 12px;"></div>' + hintbar(th)
body = ('<div style="width: 1360px; height: 452px; box-sizing: border-box; position: relative; overflow: hidden; background: %s;">'
        '<div style="position: absolute; left: 118px; top: 24px; width: 420px; height: 420px; border-radius: 210px; background: %s;"></div>'
        '<div style="position: absolute; left: 40px; top: 40px;">%s</div>%s</div>'
        % (th["desktop"], th["d1"], panel(th, inner), toast))
FILES["A-hover-toast.dc.html"] = page("A 版 · 悬停动作簇 + 已复制轻提示", 1360, 452, body)

# ---------- 4. A 版 搜索中 ----------
th = L
scs = [
    card(th, "text", "微信", "微信 · 12 分钟前",
         body_text(th, "周五下午三点在 3 楼小<mark style=\"background: rgba(10,132,255,0.22); color: inherit; border-radius: 3px; padding: 0 1px;\">会议</mark>室对一下 Q4 的排期，记得把上周的漏斗数据带上。"),
         sel="focus"),
    card(th, "text", "备忘录", "备忘录 · 昨天 09:12",
         body_text(th, "站<mark style=\"background: rgba(10,132,255,0.22); color: inherit; border-radius: 3px; padding: 0 1px;\">会议</mark>纪要 9/4\n· 登录页流程另开一稿\n· 图标最终稿 8a 已定\n· TestFlight 周三发")),
]
inner = topbar(th, query="会议", active="文本") + \
        '<div style="height: 12px;"></div>' + \
        ('<div style="display: flex; align-items: center; gap: 8px; height: 18px;">'
         '<span style="font-size: 11px; color: %s;">2 条结果</span></div>' % th["meta"]) + \
        '<div style="height: 8px;"></div>' + track("".join(scs), 158) + \
        '<div style="height: 12px;"></div>' + hintbar(th, "Esc 清空搜索 · 再按一次关闭面板")
FILES["A-search.dc.html"] = page("A 版 · 搜索中", 1360, 452, flat_frame(th, panel(th, inner, 1280, 332), 1360, 452))

# ---------- 5. A 版 空态 ----------
th = L
plate = ('<div style="position: relative; width: 96px; height: 96px; flex: none;">'
         '<div style="position: absolute; left: 0; top: 0; width: 96px; height: 96px; border-radius: 22px; background: %s; '
         'box-shadow: 0 8px 24px rgba(0,0,0,0.12);"></div>'
         '<div style="position: absolute; left: 20px; top: 24px; width: 52px; height: 8px; border-radius: 2px; background: %s; opacity: 0.9;"></div>'
         '<div style="position: absolute; left: 24px; top: 28px; width: 52px; height: 8px; border-radius: 2px; background: %s; opacity: 0.85; mix-blend-mode: multiply;"></div>'
         '<div style="position: absolute; left: 22px; top: 52px; width: 36px; height: 8px; border-radius: 4px; background: %s;"></div>'
         '<div style="position: absolute; left: 22px; top: 64px; width: 52px; height: 8px; border-radius: 4px; background: %s;"></div>'
         '<div style="position: absolute; left: 22px; top: 76px; width: 24px; height: 8px; border-radius: 4px; background: %s;"></div>'
         '</div>' % (BONE, BRED, BBLUE, INK, INK, INK))
empty = ('<div style="flex-grow: 1; display: flex; align-items: center; justify-content: center; gap: 24px;">%s'
         '<div style="display: flex; flex-direction: column; gap: 6px; max-width: 420px;">'
         '<div style="font-size: 17px; font-weight: 700; color: %s;">还没有内容</div>'
         '<div style="font-size: 12px; line-height: 17px; color: %s;">复制任何东西，它都会出现在这里。Copyo 在后台自动记录，不需要你做任何事。</div>'
         '<div style="display: flex; align-items: center; gap: 6px; margin-top: 6px; font-size: 11px; color: %s;">%s'
         '<span>随时按 ⇧⌘V 唤出这个面板</span></div></div></div>'
         % (plate, th["label"], th["meta"], th["sec"], keycap("⇧⌘V", th)))
inner = topbar(th, showchips=False) + '<div style="height: 12px;"></div>' + \
        ('<div style="display: flex; flex-direction: column; height: 222px;">%s</div>' % empty) + \
        '<div style="height: 12px;"></div>' + hintbar(th, "Esc 关闭")
FILES["A-empty.dc.html"] = page("A 版 · 空态", 1360, 452, flat_frame(th, panel(th, inner, 1280, 332), 1360, 452))

# ---------- 6 / 7. B 版 主窗口 ----------
def sidebar_row(th, label, count, on=False, dot=None):
    bg = ("background: %s;" % ACCENT) if on else ""
    fg = "#FFFFFF" if on else th["label"]
    sub = "rgba(255,255,255,0.75)" if on else th["ter"]
    mark = ('<span style="width: 18px; height: 18px; border-radius: 5px; background: %s; flex: none; display: flex; '
            'align-items: center; justify-content: center;">%s</span>'
            % (dot[0], icon(dot[1], onband(dot[0]), 11))) if dot else \
           ('<span style="width: 18px; height: 18px; flex: none;"></span>')
    return ('<div style="display: flex; align-items: center; gap: 8px; height: 28px; padding: 0 8px; box-sizing: border-box; '
            'border-radius: 6px; %s">%s<span style="flex-grow: 1; font-size: 13px; font-weight: %s; color: %s;">%s</span>'
            '<span style="font-size: 11px; color: %s; font-variant-numeric: tabular-nums;">%s</span></div>'
            % (bg, mark, "600" if on else "400", fg, label, sub, count))

def pin_row(th, label, color, count):
    return ('<div style="display: flex; align-items: center; gap: 8px; height: 28px; padding: 0 8px; box-sizing: border-box; '
            'border-radius: 6px;"><span style="width: 18px; height: 18px; border-radius: 5px; background: %s; flex: none;"></span>'
            '<span style="flex-grow: 1; font-size: 13px; color: %s;">%s</span>'
            '<span style="font-size: 11px; color: %s; font-variant-numeric: tabular-nums;">%s</span></div>'
            % (color, th["label"], label, th["ter"], count))

def b_window(th, name):
    sec = ('<div style="padding: 14px 8px 4px; font-size: 11px; font-weight: 600; letter-spacing: 0.4px; color: %s;">%s</div>')
    side = ('<div style="width: 228px; flex: none; box-sizing: border-box; padding: 8px; display: flex; flex-direction: column; '
            'background: %s; border-right: 0.5px solid %s;">'
            '%s%s%s%s%s%s%s%s%s%s%s'
            '<div style="flex-grow: 1;"></div>'
            '<div style="display: flex; align-items: center; gap: 8px; height: 28px; padding: 0 8px; box-sizing: border-box;">'
            '%s<span style="font-size: 12px; color: %s;">设置</span></div></div>'
            % (th["grouped"], th["sep"],
               sec % (th["ter"], "历史"),
               sidebar_row(th, "全部", "1 284", on=True, dot=("#8E8E93", "text")),
               sidebar_row(th, "文本", "902", dot=(SRC["Xcode"][0], "text")),
               sidebar_row(th, "链接", "211", dot=("#30B0C7", "link")),
               sidebar_row(th, "图片", "96", dot=(WARN, "image")),
               sidebar_row(th, "颜色", "41", dot=(BRED, "color")),
               sidebar_row(th, "文件", "34", dot=("#8E8E93", "file")),
               sec % (th["ter"], "PINBOARD"),
               pin_row(th, "设计 Token", ACCENT, "12"),
               pin_row(th, "常用短语", "#30D158", "31"),
               pin_row(th, "命令", "#FF9F0A", "17"),
               stroke(GEAR_I, th["sec"], 15, 1.5), th["meta"]))
    toolbar = ('<div style="height: 52px; flex: none; box-sizing: border-box; padding: 0 16px; display: flex; align-items: center; '
               'gap: 12px; border-bottom: 0.5px solid %s; background: %s;">'
               '<div style="display: flex; gap: 8px;">'
               '<span style="width: 12px; height: 12px; border-radius: 6px; background: #FF5F57;"></span>'
               '<span style="width: 12px; height: 12px; border-radius: 6px; background: #FEBC2E;"></span>'
               '<span style="width: 12px; height: 12px; border-radius: 6px; background: #28C840;"></span></div>'
               '<span style="width: 6px;"></span>'
               '<span style="font-size: 13px; font-weight: 600; color: %s;">全部</span>'
               '<span style="font-size: 12px; color: %s;">1 284 条</span>'
               '<span style="flex-grow: 1;"></span>'
               '<div style="display: flex; align-items: center; gap: 6px; width: 240px; height: 28px; padding: 0 10px; '
               'box-sizing: border-box; border-radius: 8px; background: %s;">%s'
               '<label for="bq-%s" style="position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0);">搜索历史</label>'
               '<input id="bq-%s" type="text" placeholder="搜索历史" style="flex-grow: 1; border: 0; background: none; outline: none; '
               'font-family: inherit; font-size: 12px; color: %s;"></div>'
               '<button type="button" aria-label="iCloud 已同步" title="iCloud 已同步" style="width: 28px; height: 28px; '
               'border-radius: 7px; display: flex; align-items: center; justify-content: center;">%s</button></div>'
               % (th["sep"], th["glass"], th["label"], th["ter"], th["fill"], stroke(SEARCH_I, th["sec"], 13),
                  name, name, th["label"],
                  stroke(CLOUD_OK_I, SUCCESS_D if th is D else SUCCESS_L, 16, 1.5)))
    W = 268
    col = lambda items: ('<div style="display: flex; flex-direction: column; gap: 12px; width: %dpx;">%s</div>' % (W, "".join(items)))
    c1 = [
        card(th, "text", "Xcode", "Xcode · 2 分钟前",
             body_text(th, "git rebase -i HEAD~3 &amp;&amp; git push --force-with-lease", 4, mono=True), W, 150),
        card(th, "color", "Figma", "Figma · 1 小时前", body_color(th, COLORCLIP[0]), W, 196,
             tint=(COLORCLIP[2] if th is D else COLORCLIP[1]), srccol=COLORCLIP[0]),
        card(th, "text", "访达", "访达 · 昨天 11:04",
             body_text(th, "~/Projects/copyo/art/macos-design/2026-09-20", 3, mono=True), W, 132),
    ]
    c2 = [
        card(th, "text", "微信", "微信 · 12 分钟前",
             body_text(th, "周五下午三点在 3 楼小会议室对一下 Q4 的排期，记得把上周的漏斗数据带上，顺便看看新江湾那边场地的报价。", 6), W, 186),
        card(th, "image", "备忘录", "备忘录 · 昨天 18:42", body_image(th, "#F0E4BE" if th is not D else "#4A431F"), W, 206),
        card(th, "rich", "备忘录", "备忘录 · 昨天 09:12",
             body_text(th, "站会纪要 9/4 —— 登录页流程另开一稿；图标最终稿 8a 已定。", 3), W, 132),
    ]
    c3 = [
        card(th, "link", "Safari", "Safari · 25 分钟前",
             body_link(th, "Adopting Liquid Glass | Apple Developer Documentation", "developer.apple.com"), W, 168, pinned=True),
        card(th, "file", "访达", "访达 · 昨天 18:02", body_files(th, "Q3-复盘.key", "另外 4 个文件"), W, 214),
        card(th, "text", "VS Code", "VS Code · 前天 22:31",
             body_text(th, "npm run dist --sign", 2, mono=True), W, 110),
    ]
    content = ('<div style="flex-grow: 1; box-sizing: border-box; padding: 16px; display: flex; gap: 12px; align-items: flex-start; '
               'overflow: hidden; background: %s;">%s%s%s</div>' % (th["grouped"], col(c1), col(c2), col(c3)))
    win = ('<div style="width: 1080px; height: 700px; border-radius: 12px; overflow: hidden; display: flex; flex-direction: column; '
           'background: %s; box-shadow: 0 0 0 0.5px rgba(0,0,0,0.20), 0 28px 68px rgba(0,0,0,0.38);">%s'
           '<div style="flex-grow: 1; display: flex; min-height: 0;">%s%s</div></div>'
           % (th["grouped"], toolbar, side, content))
    return ('<div style="width: 1180px; height: 800px; box-sizing: border-box; position: relative; overflow: hidden; background: %s;">'
            '<div style="position: absolute; left: 60px; top: 50px; width: 420px; height: 420px; border-radius: 210px; background: %s;"></div>'
            '<div style="position: absolute; left: 50px; top: 50px;">%s</div></div>'
            % (th["desktop"], th["d1"], win))

FILES["B-window-light.dc.html"] = page("B 版 · 主窗口 · 浅色", 1180, 800, b_window(L, "l"))
FILES["B-window-dark.dc.html"] = page("B 版 · 主窗口 · 深色", 1180, 800, b_window(D, "d"))

for name, text in FILES.items():
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        f.write(text)
    print("wrote", name, len(text))
