#!/usr/bin/env python3
# Copyo Mac 设计稿 v2（2026-09-27）：按 design-spec 第八节的拍板结果重出全部 A 版画板与设置页。
# 主题字典 L / D、图标常量与 badge / keycap / chip / page 等基础件复用 2026-09-20/gen.py，
# 只覆写本轮改动的部分。用法：python3 gen_v2.py [输出目录]（默认写到本目录，与 canvas.json 并列）。
import json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
V1 = os.path.join(HERE, "..", "2026-09-20", "gen.py")
exec(open(V1, encoding="utf-8").read().split("FILES = {}")[0])
OUT = sys.argv[1] if len(sys.argv) > 1 else HERE

# ============================ 取色：公式为准（第 29 条） ============================
def hx(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

def rhu(x):
    return int(math.floor(x + 0.5))   # round-half-up，只用于画板落 hex；App 里运行时不量化

def mix(src, base, f):
    return "#%02X%02X%02X" % tuple(rhu(f * s + (1 - f) * b) for s, b in zip(hx(src), hx(base)))

def tint(src, th, hover=False):
    if th is D:
        return mix(src, D["card"], 0.26 if hover else 0.20)
    return mix(src, L["card"], 0.16 if hover else 0.12)

def rgba(h, a):
    r, g, b = hx(h)
    return "rgba(%d,%d,%d,%s)" % (r, g, b, a)

SRCHEX = {k: v[0] for k, v in SRC.items()}
SRCHEX.update({"Microsoft Remote Desktop": "#0078D4", "终端": "#1C1C1E", "Keynote": "#1E7BF6"})
LOCAL = "#8E8E93"                     # source.local：取不到来源色（nil）时的回退
BADGE_INK = "rgba(0,0,0,0.78)"        # 第 32(b) 条：角标文字色统一到 iOS

def onband(hexv):
    r, g, b = hx(hexv)
    return BADGE_INK if (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.62 else "#FFFFFF"

def badge(kind, bg):
    fg = onband(bg)
    return ('<span style="display: inline-flex; align-items: center; gap: 3px; height: 18px; padding: 0 6px 0 5px; '
            'border-radius: 9px; background: %s; color: %s; font-size: 10px; font-weight: 600; white-space: nowrap; '
            'flex: none;">%s%s</span>' % (bg, fg, icon(kind, fg, 10), ICON[kind][0]))

# ============================ 图标 ============================
def filled(inner, color, size=14):
    return ('<svg width="%d" height="%d" viewBox="0 0 16 16" fill="%s" stroke="%s" stroke-width="0.8" '
            'stroke-linejoin="round" aria-hidden="true">%s</svg>' % (size, size, color, color, inner))

CLOUD = '<path d="M4.4 12.4h6.9a2.8 2.8 0 0 0 .3-5.6A4 4 0 0 0 4 6.6a2.9 2.9 0 0 0 .4 5.8z"></path>'
CLOUD_WARN_I = CLOUD + '<path d="M8 7.4v2.1M8 11v.1"></path>'
FOLDER = '<path d="M1.8 4.3a1 1 0 0 1 1-1h3.1l1.4 1.5h5.9a1 1 0 0 1 1 1v6.4a1 1 0 0 1-1 1H2.8a1 1 0 0 1-1-1z"></path>'
FOLDER_OK_I = FOLDER + '<path d="M5.9 9.1l1.5 1.5 2.8-2.9"></path>'
FOLDER_Q_I = FOLDER + '<path d="M6.8 7.6a1.3 1.3 0 1 1 1.9 1.2c-.5.3-.7.5-.7 1M8 11.3v.1"></path>'
FOLDER_WARN_I = FOLDER + '<path d="M8 6.8v2.5M8 11.2v.1"></path>'
POWER_I = '<path d="M8 2.2v5.4M4.7 4.3a5 5 0 1 0 6.6 0"></path>'
MENUBAR_I = '<rect x="1.8" y="3.2" width="12.4" height="9.6" rx="1.8"></rect><path d="M1.8 6.2h12.4"></path>'
KEY_I = ('<circle cx="5.2" cy="8" r="2.9" fill="currentColor"></circle><path d="M8 8h6.2M12.2 8v2.4M14 8v1.8"></path>')
CMD_I = ('<path d="M6 6h4v4H6zM6 6V4.6a1.6 1.6 0 1 0-1.6 1.4H6M10 6V4.6a1.6 1.6 0 1 1 1.6 1.4H10'
         'M6 10v1.4A1.6 1.6 0 1 1 4.4 10H6M10 10v1.4a1.6 1.6 0 1 0 1.6-1.4H10"></path>')
INFO_I = '<circle cx="8" cy="8" r="6.2"></circle><path d="M8 7.3v4M8 4.9v.1"></path>'
CLOCK_I = '<circle cx="8" cy="8" r="6.2"></circle><path d="M8 4.8V8l2.2 1.5"></path>'
DOCS_I = ('<rect x="2.6" y="4.4" width="7.8" height="9.8" rx="1.2"></rect>'
          '<path d="M5.6 4.4V2.9a1 1 0 0 1 1-1h5.8a1 1 0 0 1 1 1v7.8a1 1 0 0 1-1 1h-2"></path>')
PLAIN_I = '<path d="M4 1.8h5l3.2 3.2v9.2H4z"></path><path d="M6.2 8h3.6M6.2 10.4h3.6M6.2 5.6h1.6"></path>'
EYE_I = ('<path d="M1.6 8s2.4-4.4 6.4-4.4 6.4 4.4 6.4 4.4-2.4 4.4-6.4 4.4S1.6 8 1.6 8z"></path>'
         '<circle cx="8" cy="8" r="2"></circle>')
PLUS_I = '<path d="M8 3.2v9.6M3.2 8h9.6"></path>'
MINUS_I = '<path d="M3.2 8h9.6"></path>'
CHEV_R_I = '<path d="M6 3.8l4.2 4.2L6 12.2"></path>'
UPDOWN_I = '<path d="M5.2 6.2L8 3.4l2.8 2.8M5.2 9.8L8 12.6l2.8-2.8"></path>'
WARN_TRI_I = '<path d="M8 2.2l6.2 11H1.8z"></path><path d="M8 6.4v3.2M8 11.3v.1"></path>'

# ============================ 卡片 ============================
def meta_line(th, src, time):
    # 第 37 条：拆成两段。来源名可截断，「 · 时间」固有宽、永不被截；src 为 None 即整段隐藏
    s = ('<span style="min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">%s</span>'
         '<span style="flex: none; white-space: pre;"> · </span>' % src) if src else ""
    return ('<span style="flex-grow: 1; min-width: 0; display: flex; font-size: 10px; color: %s;">%s'
            '<span style="flex: none; white-space: nowrap;">%s</span></span>' % (th["meta"], s, time))

def card(th, kind, src, time, body_html, w=260, h=184, state=None, hover=False, pinned=False,
         srccol=None, shown_src=None):
    s_hex = srccol or SRCHEX.get(src, LOCAL)
    ring = th["cring"]
    if hover:
        ring = "inset 0 0 0 0.5px %s" % rgba(s_hex, 0.4)
    if state == "current":
        ring = "0 0 0 2px %s, 0 0 0 7px rgba(10,132,255,0.32)" % ACCENT
    elif state == "inactive":
        ring = "0 0 0 3px rgba(10,132,255,0.45)"
    lift = ""
    if state == "lift":
        lift = " transform: rotate(-2deg) scale(1.03);"
        ring = "%s, 0 12px 32px rgba(0,0,0,0.28)" % th["cring"]
    cluster = ""
    if hover:
        btn = ('<button type="button" aria-label="%s" style="width: 24px; height: 24px; border-radius: 7px; '
               'display: flex; align-items: center; justify-content: center;">%s</button>')
        pin_btn = (btn % ("取消固定", filled(PIN_I, ACCENT, 14))) if pinned else \
                  (btn % ("固定到 Pinboard", stroke(PIN_I, ACCENT, 14, 1.5)))
        cluster = ('<div style="position: absolute; right: 8px; top: 8px; display: flex; align-items: center; gap: 2px; '
                   'height: 28px; padding: 0 3px; border-radius: 9px; background: %s; backdrop-filter: blur(14px); '
                   '-webkit-backdrop-filter: blur(14px); box-shadow: %s, 0 2px 8px rgba(0,0,0,0.14);">%s%s</div>'
                   % (th["glass"], th["ring"], pin_btn,
                      btn % ("删除", stroke(TRASH_I, DESTRUCT_D if th is D else DESTRUCT_L, 14, 1.5))))
    pin_mark = ('<span style="flex: none; display: inline-flex;" aria-label="已固定">%s</span>'
                % filled(PIN_I, ACCENT, 11)) if pinned and not hover else ""
    return ('<div style="position: relative; width: %dpx; height: %dpx; flex: none; box-sizing: border-box; '
            'padding: 12px; border-radius: 12px; background: %s; box-shadow: %s;%s display: flex; '
            'flex-direction: column; gap: 8px;">'
            '<div style="display: flex; align-items: center; gap: 6px; height: 18px;">%s%s%s</div>'
            '%s'
            '<div style="height: 20px; display: flex; align-items: center; justify-content: flex-end;">'
            '<span style="width: 20px; height: 20px; border-radius: 5px; background: %s; box-shadow: %s;"></span>'
            '</div>%s</div>'
            % (w, h, tint(s_hex, th, hover), ring, lift, badge(kind, s_hex),
               meta_line(th, shown_src if shown_src is not None else src, time), pin_mark,
               body_html, s_hex, th["swatchring"], cluster))

def body_text(th, txt, clamp=6, mono=False):
    # 第 38 条：clamp 6；第 35 条：等宽正文 Regular
    fam = ("font-family: %s; font-size: 11px; line-height: 15px;" % MONO) if mono else "font-size: 12px; line-height: 16px;"
    return ('<div style="flex-grow: 1; min-height: 0; white-space: pre-line; %s color: %s; overflow: hidden; display: -webkit-box; '
            '-webkit-line-clamp: %d; -webkit-box-orient: vertical; word-break: break-word;">%s</div>'
            % (fam, th["label"], clamp, txt))

def body_files(th, first, more, top="#1EA7FD"):
    sq = ('<span style="position: absolute; left: %dpx; top: %dpx; width: 30px; height: 30px; border-radius: 7px; '
          'background: %s; box-shadow: %s; display: flex; align-items: center; justify-content: center;">%s</span>')
    stack = ('<div style="position: relative; width: 46px; height: 38px; flex: none;">%s%s%s</div>'
             % (sq % (0, 6, th["fill2"], th["swatchring"], ""),
                sq % (7, 3, th["fill2"], th["swatchring"], ""),
                sq % (14, 0, top, th["swatchring"], icon("file", onband(top), 14))))
    extra = ('<div style="font-size: 11px; color: %s;">%s</div>' % (th["meta"], more)) if more else ""
    return ('<div style="flex-grow: 1; min-height: 0; display: flex; flex-direction: column; gap: 8px;">%s'
            '<div style="font-size: 12px; line-height: 16px; color: %s; overflow: hidden; display: -webkit-box; '
            '-webkit-line-clamp: 2; -webkit-box-orient: vertical; word-break: break-all;">%s</div>%s</div>'
            % (stack, th["label"], first, extra))

def body_image_pending(th):
    # 7.5.5：图片未就绪 / 解码失败 = 来源淡染底上居中 photo 符号，label.tertiary
    return ('<div style="flex-grow: 1; min-height: 0; border-radius: 10px; box-shadow: %s; display: flex; '
            'align-items: center; justify-content: center;">%s</div>'
            % (th["swatchring"], stroke(ICON["image"][1], th["ter"], 28, 1.4)))

MARK = ('<mark style="background: rgba(10,132,255,0.22); color: inherit; border-radius: 3px; padding: 0 1px;">%s</mark>')
WX = "周五下午三点在 3 楼小会议室对一下 Q4 的排期，记得把上周的漏斗数据带上，顺便看看新江湾那边场地的报价。"
NOTES = "站会纪要 9/4\n· 登录页流程另开一稿\n· 图标最终稿 8a 已定\n· TestFlight 周三发"

def CARDS(th, current=0, hover=None):
    img = "#F0E4BE" if th is not D else "#4A431F"
    specs = [
        ("text", "Xcode", "2 分钟前", body_text(th, "git rebase -i HEAD~3 &amp;&amp; git push --force-with-lease", mono=True), None),
        ("text", "微信", "12 分钟前", body_text(th, WX), None),
        ("link", "Safari", "25 分钟前", body_link(th, "Adopting Liquid Glass | Apple Developer Documentation", "developer.apple.com"), None),
        ("color", "Figma", "1 小时前", body_color(th, COLORCLIP[0]), COLORCLIP[0]),
        ("image", "备忘录", "昨天 18:42", body_image(th, img), None),
    ]
    return [card(th, k, s, t, b, srccol=c, state=("current" if i == current else None), hover=(i == hover))
            for i, (k, s, t, b, c) in enumerate(specs)]

# ============================ 面板骨架 ============================
SYNC = {
    "icloud-ok":   ("iCloud 已同步", CLOUD_OK_I, "ok"),
    "icloud-warn": ("iCloud 同步需要处理", CLOUD_WARN_I, "warn"),
    "folder-ok":   ("共享文件夹已同步", FOLDER_OK_I, "ok"),
    "folder-unset": ("还没有选择同步文件夹", FOLDER_Q_I, "unset"),
    "folder-warn": ("同步文件夹需要重新选择", FOLDER_WARN_I, "warn"),
}

def sync_cell(th, sync):
    if sync == "off":
        return ""
    label, inner, tone = SYNC[sync]
    col = {"ok": SUCCESS_D if th is D else SUCCESS_L, "warn": WARN, "unset": th["sec"]}[tone]
    return ('<button type="button" aria-label="%s" title="%s" style="width: 32px; height: 32px; border-radius: 8px; '
            'display: flex; align-items: center; justify-content: center; flex: none;">%s</button>'
            % (label, label, stroke(inner, col, 17, 1.5)))

def gear(th):
    return ('<button type="button" aria-label="设置" title="设置" style="width: 32px; height: 32px; border-radius: 8px; '
            'display: flex; align-items: center; justify-content: center; flex: none;">%s</button>'
            % stroke(GEAR_I, th["sec"], 17, 1.5))

def search_field(th, query=None, count=None, focused=False):
    if query:
        txt = ('<span style="flex-grow: 1; font-size: 13px; color: %s;">%s<span style="display: inline-block; '
               'width: 1.5px; height: 15px; margin-left: 1px; vertical-align: -3px; background: %s;"></span></span>'
               % (th["label"], query, ACCENT))
    else:
        txt = ('<label for="q" style="position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0);">搜索历史</label>'
               '<input id="q" type="text" placeholder="搜索历史" style="flex-grow: 1; min-width: 0; border: 0; background: none; '
               'outline: none; font-family: inherit; font-size: 13px; color: %s;">' % th["label"])
    cnt = ('<span style="flex: none; font-size: 11px; color: %s;">%s</span>' % (th["meta"], count)) if count else ""
    ring = ("box-shadow: 0 0 0 2px %s, 0 0 0 6px rgba(10,132,255,0.28);" % ACCENT) if (query or focused) else ""
    return ('<div style="flex-grow: 1; min-width: 0; display: flex; align-items: center; gap: 6px; height: 32px; '
            'padding: 0 10px; box-sizing: border-box; border-radius: 8px; background: %s; %s">%s%s%s</div>'
            % (th["fill"], ring, stroke(SEARCH_I, th["sec"]), txt, cnt))

def pinboard_chip(th, label="Pinboard", on=False, editing=None):
    if editing is not None:
        return ('<div style="display: inline-flex; align-items: center; gap: 6px; width: 188px; height: 26px; padding: 0 9px; '
                'box-sizing: border-box; border-radius: 8px; background: %s; box-shadow: 0 0 0 2px %s, 0 0 0 5px rgba(10,132,255,0.25);">'
                '%s<span style="flex-grow: 1; font-size: 12px; color: %s;">%s<span style="display: inline-block; width: 1.5px; '
                'height: 14px; margin-left: 1px; vertical-align: -3px; background: %s;"></span></span></div>'
                % (th["card"], ACCENT, stroke(PIN_I, ACCENT, 12, 1.5), th["label"], editing, ACCENT))
    if on:
        return ('<button type="button" style="display: inline-flex; align-items: center; gap: 5px; height: 26px; '
                'padding: 0 9px 0 11px; border-radius: 8px; font-size: 12px; background: %s; color: #FFFFFF; font-weight: 600;">'
                '<span>%s</span>%s</button>' % (ACCENT, label, stroke(CHEV_I, "rgba(255,255,255,0.85)", 11, 1.8)))
    return chip(label, th, chev=True)

def topbar(th, query=None, count=None, active="全部", sync="icloud-ok", chips=True, pinboard=None):
    row1 = ('<div style="display: flex; align-items: center; gap: 8px; height: 32px;">%s%s%s</div>'
            % (search_field(th, query, count), sync_cell(th, sync), gear(th)))
    if not chips:
        return row1
    names = ["全部", "文本", "链接", "图片", "颜色", "文件"]
    cs = "".join(chip(n, th, on=(n == active)) for n in names)
    pb = pinboard if pinboard is not None else pinboard_chip(th)
    return row1 + ('<div style="height: 10px;"></div>'
                   '<div style="display: flex; align-items: center; gap: 8px; height: 26px;">'
                   '<div style="display: flex; align-items: center; gap: 6px; flex-grow: 1;">%s</div>%s</div>' % (cs, pb))

DEFAULT_HINTS = [("↩", "复制"), ("空格", "预览"), ("⌘P", "固定"), ("⌘⌫", "删除")]

def hintbar(th, right="复制后回到原来的 App，按 ⌘V 粘贴", items=DEFAULT_HINTS):
    return ('<div style="display: flex; align-items: center; gap: 14px; height: 24px;">%s'
            '<span style="flex-grow: 1;"></span><span style="font-size: 11px; color: %s;">%s</span></div>'
            % ("".join(hint(c, t, th) for c, t in items), th["sec"], right))

GAP = lambda n: '<div style="height: %dpx; flex: none;"></div>' % n

def panel_body(th, top, middle, hints, mid_h=184):
    return (top + GAP(12) + ('<div style="display: flex; gap: 12px; height: %dpx; overflow: hidden; flex: none;">%s</div>'
                             % (mid_h, middle)) + GAP(12) + hints)

def centered(inner, h=184):
    return ('<div style="flex-grow: 1; height: %dpx; display: flex; align-items: center; justify-content: center; gap: 24px;">%s</div>'
            % (h, inner))

PLATE = ('<div style="position: relative; width: 96px; height: 96px; flex: none;">'
         '<div style="position: absolute; left: 0; top: 0; width: 96px; height: 96px; border-radius: 22px; background: %s; '
         'box-shadow: 0 8px 24px rgba(0,0,0,0.12);"></div>'
         '<div style="position: absolute; left: 20px; top: 24px; width: 52px; height: 8px; border-radius: 2px; background: %s; opacity: 0.9;"></div>'
         '<div style="position: absolute; left: 24px; top: 28px; width: 52px; height: 8px; border-radius: 2px; background: %s; opacity: 0.85; mix-blend-mode: multiply;"></div>'
         '<div style="position: absolute; left: 22px; top: 52px; width: 36px; height: 8px; border-radius: 4px; background: %s;"></div>'
         '<div style="position: absolute; left: 22px; top: 64px; width: 52px; height: 8px; border-radius: 4px; background: %s;"></div>'
         '<div style="position: absolute; left: 22px; top: 76px; width: 24px; height: 8px; border-radius: 4px; background: %s;"></div>'
         '</div>' % (BONE, BRED, BBLUE, INK, INK, INK))

def empty_copy(th, title, body, foot=""):
    return ('%s<div style="display: flex; flex-direction: column; gap: 6px; max-width: 420px;">'
            '<div style="font-size: 17px; font-weight: 700; color: %s;">%s</div>'
            '<div style="font-size: 12px; line-height: 17px; color: %s;">%s</div>%s</div>'
            % (PLATE, th["label"], title, th["meta"], body, foot))

def desktop(th, w, h, layers, dock=True):
    d = ('<div style="position: absolute; left: %dpx; top: %dpx; width: 560px; height: 64px; border-radius: 18px; '
         'background: %s; box-shadow: inset 0 0 0 0.5px %s;"></div>' % ((w - 560) // 2, h - 72, th["dock"], th["dockr"])) if dock else ""
    return ('<div style="width: %dpx; height: %dpx; box-sizing: border-box; position: relative; overflow: hidden; background: %s;">'
            '<div style="position: absolute; left: 118px; top: 44px; width: 420px; height: 420px; border-radius: 210px; background: %s;"></div>'
            '<div style="position: absolute; left: %dpx; top: -60px; width: 520px; height: 520px; border-radius: 260px; background: %s;"></div>'
            '%s%s</div>' % (w, h, th["desktop"], th["d1"], w - 560, th["d2"], d,
                            "".join('<div style="position: absolute; left: %dpx; top: %dpx;">%s</div>' % l for l in layers)))

def flat(th, w, h, layers):
    return ('<div style="width: %dpx; height: %dpx; box-sizing: border-box; position: relative; overflow: hidden; background: %s;">%s</div>'
            % (w, h, th["desktop"],
               "".join('<div style="position: absolute; left: %dpx; top: %dpx;">%s</div>' % l for l in layers)))

# 第 1 条：面板宽 min(1280, visibleFrame.width − 32)、水平居中、底边 = Dock 顶 − 12
def panel_y(h):
    return h - 72 - 12 - 332

FILES = {}

# ---------- 01 主态 · 浅 / 深 ----------
for th, name, title in ((L, "Main.dc.html", "面板 · 主态 · 浅色"), (D, "A-panel-dark.dc.html", "面板 · 主态 · 深色")):
    inner = panel_body(th, topbar(th), "".join(CARDS(th)), hintbar(th))
    FILES[name] = page(title, 1440, 520, desktop(th, 1440, 520, [(80, panel_y(520), panel(th, inner))]))

# ---------- 01b 悬停 ----------
th = L
inner = panel_body(th, topbar(th), "".join(CARDS(th, current=0, hover=1)), hintbar(th))
FILES["A-hover.dc.html"] = page("面板 · 悬停动作簇", 1360, 412, flat(th, 1360, 412, [(40, 40, panel(th, inner))]))

# ---------- 01g 已复制轻提示：面板已收起，独立小窗在原面板底边处 ----------
toast = ('<div style="display: flex; align-items: center; gap: 7px; height: 36px; padding: 0 16px; border-radius: 18px; '
         'background: %s; backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); box-shadow: %s, 0 6px 20px rgba(0,0,0,0.18); '
         'font-size: 13px; font-weight: 500; color: %s; white-space: nowrap;">%s已复制 · 按 ⌘V 粘贴</div>'
         % (L["glass"], L["ring"], L["label"], stroke(CHECK_I, SUCCESS_L, 14, 2)))
FILES["A-toast.dc.html"] = page("已复制轻提示 · 独立小窗", 1440, 520,
                                desktop(L, 1440, 520, [(0, 520 - 72 - 12 - 36, '<div style="width: 1440px; display: flex; justify-content: center;">%s</div>' % toast)]))

# ---------- 01c 搜索中：计数进搜索框，轨道恒 184 ----------
th = L
scs = [
    card(th, "text", "微信", "12 分钟前",
         body_text(th, "周五下午三点在 3 楼小" + MARK % "会议" + "室对一下 Q4 的排期，记得把上周的漏斗数据带上。"), state="current"),
    card(th, "text", "备忘录", "昨天 09:12", body_text(th, "站" + MARK % "会议" + "纪要 9/4\n· 登录页流程另开一稿\n· 图标最终稿 8a 已定\n· TestFlight 周三发")),
]
inner = panel_body(th, topbar(th, query="会议", count="2 条结果", active="文本"), "".join(scs),
                   hintbar(th, "Esc 清空搜索 · 再按一次关闭面板"))
FILES["A-search.dc.html"] = page("面板 · 搜索中", 1360, 412, flat(th, 1360, 412, [(40, 40, panel(th, inner))]))

# ---------- 01e 搜索无结果：一行字，不用插画 ----------
none_line = ('<span style="font-size: 13px; color: %s;">没有匹配「发票抬头」的内容</span>' % th["sec"])
inner = panel_body(th, topbar(th, query="发票抬头"), centered(none_line),
                   hintbar(th, "Esc 清空搜索 · 再按一次关闭面板"))
FILES["A-search-empty.dc.html"] = page("面板 · 搜索无结果", 1360, 412, flat(th, 1360, 412, [(40, 40, panel(th, inner))]))

# ---------- 01d 历史为空：空态区 220（第 4 条） ----------
foot = ('<div style="display: flex; align-items: center; gap: 6px; margin-top: 6px; font-size: 11px; color: %s;">%s'
        '<span>随时按 ⇧⌘V 唤出这个面板</span></div>' % (th["sec"], keycap("⇧⌘V", th)))
inner = (topbar(th, chips=False) + GAP(12) +
         ('<div style="display: flex; height: 220px; flex: none;">%s</div>'
          % centered(empty_copy(th, "还没有内容", "复制任何东西，它都会出现在这里。Copyo 在后台自动记录，不需要你做任何事。", foot), 220)) +
         GAP(12) + hintbar(th, "Esc 关闭"))
FILES["A-empty.dc.html"] = page("面板 · 历史为空", 1360, 412, flat(th, 1360, 412, [(40, 40, panel(th, inner))]))

# ---------- 01f Pinboard 为空：复用插画 + 引导 ----------
inner = panel_body(th, topbar(th, active=None, pinboard=pinboard_chip(th, "发版清单", on=True)),
                   centered(empty_copy(th, "这个 Pinboard 还是空的",
                                       "在卡片上右键 → 固定到 Pinboard，常用的内容就会一直留在这里。")),
                   hintbar(th, "Esc 关闭"))
FILES["A-pinboard-empty.dc.html"] = page("面板 · Pinboard 为空", 1360, 412, flat(th, 1360, 412, [(40, 40, panel(th, inner))]))

# ---------- 03c 新建 Pinboard：胶囊原地变输入框（第 20 条） ----------
inner = panel_body(th, topbar(th, pinboard=pinboard_chip(th, editing="发版清单")), "".join(CARDS(th, current=1)),
                   hintbar(th, "建好后把当前卡固定进去", items=[("↩", "创建并固定"), ("esc", "取消")]))
FILES["A-pinboard-new.dc.html"] = page("面板 · 新建 Pinboard", 1360, 412, flat(th, 1360, 412, [(40, 40, panel(th, inner))]))

# ---------- 03 卡片右键菜单（第 22 条：带符号） ----------
def menu(th, items, w=224):
    rows = []
    for it in items:
        if it == "sep":
            rows.append('<div style="height: 1px; margin: 5px 10px; background: %s;"></div>' % th["sep"])
            continue
        label, ic, kind = it
        hi = kind == "hi"
        fg = "#FFFFFF" if hi else (DESTRUCT_L if kind == "danger" else th["label"])
        icf = "#FFFFFF" if hi else (DESTRUCT_L if kind == "danger" else th["label"])
        lead = ic if ic.startswith("<span") else stroke(ic, icf, 15, 1.4)
        tail = stroke(CHEV_R_I, "#FFFFFF" if hi else th["sec"], 11, 1.8) if kind in ("hi", "sub") else ""
        rows.append('<div style="display: flex; align-items: center; gap: 8px; height: 24px; padding: 0 8px; margin: 0 5px; '
                    'border-radius: 6px; background: %s; color: %s; font-size: 13px;">%s<span style="flex-grow: 1;">%s</span>%s</div>'
                    % (ACCENT if hi else "transparent", fg, lead, label, tail))
    return ('<div role="menu" style="width: %dpx; padding: 5px 0; box-sizing: border-box; border-radius: 12px; '
            'background: rgba(246,246,248,0.86); backdrop-filter: blur(30px) saturate(180%%); -webkit-backdrop-filter: blur(30px) saturate(180%%); '
            'box-shadow: 0 0 0 0.5px rgba(0,0,0,0.16), 0 10px 32px rgba(0,0,0,0.22);">%s</div>' % (w, "".join(rows)))

dot = lambda c: ('<span style="width: 15px; height: 15px; flex: none; display: flex; align-items: center; justify-content: center;">'
                 '<span style="width: 10px; height: 10px; border-radius: 3px; background: %s;"></span></span>' % c)
m1 = menu(th, [("复制", DOCS_I, ""), ("纯文本复制", PLAIN_I, ""), "sep",
               ("固定到 Pinboard", PIN_I, "hi"), ("预览", EYE_I, ""), "sep", ("删除", TRASH_I, "danger")])
m2 = menu(th, [("设计 Token", dot(ACCENT), ""), ("常用短语", dot("#30D158"), ""), ("发版清单", dot(WARN), ""), "sep",
               ("新建 Pinboard…", PLUS_I, "")], 188)
inner = panel_body(th, topbar(th), "".join(CARDS(th, current=1)), hintbar(th))
FILES["A-menu.dc.html"] = page("面板 · 卡片右键菜单", 1360, 412,
                               flat(th, 1360, 412, [(40, 40, panel(th, inner)), (452, 190, m1), (672, 249, m2)]))

# ---------- 02 预览浮层：面板上方的独立子窗口（第 2 条） ----------
PV = ("站会纪要 9/4\n\n· 登录页流程另开一稿，周三前给到评审\n· 图标最终稿 8a 已定，导出 1024 / 512 / 128 三档\n"
      "· TestFlight 周三发，外部测试组先加 20 人\n· Mac 面板重做：本周定稿设计，下周进开发\n\n待跟进：设置页的同步文案还要再过一遍。")
pv_chars = sum(1 for c in PV if not c.isspace())
pv_h = 380
preview = ('<div style="width: 720px; height: %dpx; box-sizing: border-box; padding: 12px; border-radius: 20px; background: %s; '
           'backdrop-filter: blur(24px); -webkit-backdrop-filter: blur(24px); box-shadow: %s, 0 1px 3px rgba(0,0,0,0.10), 0 24px 56px rgba(0,0,0,0.30); '
           'display: flex; flex-direction: column; gap: 8px;">'
           '<div style="flex-grow: 1; min-height: 0; box-sizing: border-box; padding: 16px 20px; border-radius: 12px; background: %s; '
           'box-shadow: %s; font-size: 13px; line-height: 20px; color: %s; white-space: pre-line; overflow: hidden;">%s</div>'
           '<div style="height: 28px; flex: none; display: flex; align-items: center; gap: 8px; padding: 0 4px;">%s'
           '<span style="font-size: 11px; color: %s;">备忘录 · 3 小时前 · %d 字</span><span style="flex-grow: 1;"></span>%s%s</div></div>'
           % (pv_h, L["glass"], L["ring"], tint(SRCHEX["备忘录"], L), L["cring"], L["label"], PV,
              badge("rich", SRCHEX["备忘录"]), L["meta"], pv_chars, hint("↩", "复制", L), hint("空格", "关闭", L)))
cs = CARDS(L, current=None)
cs[1] = card(L, "rich", "备忘录", "3 小时前", body_text(L, NOTES), state="current")
inner = panel_body(L, topbar(L), "".join(cs), hintbar(L))
py = panel_y(900)
FILES["A-preview.dc.html"] = page("预览浮层 · 独立子窗口", 1440, 900,
                                  desktop(L, 1440, 900, [(80, py, panel(L, inner)), (360, py - 12 - pv_h, preview)]))

# ---------- 顶栏右侧那一格：同步状态（第 13–15 条） ----------
def mini_bar(th, sync):
    return ('<div style="width: 340px; box-sizing: border-box; padding: 10px; border-radius: 14px; background: %s; '
            'box-shadow: %s, 0 8px 24px rgba(0,0,0,0.12); display: flex; align-items: center; gap: 8px;">%s%s%s</div>'
            % (th["glass"], th["ring"], search_field(th), sync_cell(th, sync), gear(th)))

def h1(th, t, sub=""):
    s = ('<span style="font-size: 12px; font-weight: 400; color: %s; margin-left: 10px;">%s</span>' % (th["ter"], sub)) if sub else ""
    return ('<div style="font-size: 17px; font-weight: 700; color: %s; display: flex; align-items: baseline;">%s%s</div>'
            % (th["label"], t, s))

def h2(th, t, sub=""):
    s = ('<span style="font-size: 11px; font-weight: 400; color: %s; margin-left: 8px;">%s</span>' % (th["ter"], sub)) if sub else ""
    return ('<div style="font-size: 11px; font-weight: 600; letter-spacing: 0.4px; color: %s; height: 20px; flex: none; '
            'display: flex; align-items: center;">%s%s</div>' % (th["sec"], t, s))

rows = []
for key, cap in (("icloud-ok", "iCloud · 正常"), ("icloud-warn", "iCloud · 需要处理"), ("folder-ok", "共享文件夹 · 正常"),
                 ("folder-unset", "共享文件夹 · 还没选择文件夹"), ("folder-warn", "共享文件夹 · 需要重新选择"), ("off", "同步已关闭 · 整格隐藏")):
    rows.append('<div style="display: flex; align-items: center; gap: 20px;">'
                '<div style="width: 200px; font-size: 12px; color: %s;">%s</div>'
                '<div style="padding: 8px; border-radius: 20px; background: %s;">%s</div>'
                '<div style="padding: 8px; border-radius: 20px; background: %s;">%s</div></div>'
                % (L["label"], cap, L["desktop"], mini_bar(L, key), D["desktop"], mini_bar(D, key)))
body = ('<div style="width: 1040px; height: 620px; box-sizing: border-box; padding: 40px; background: %s; '
        'display: flex; flex-direction: column; gap: 14px;">%s%s</div>'
        % (L["grouped"], h1(L, "顶栏右侧 · 同步格", "形状随同步方式；只分「正常 / 需要处理」；未配置用灰；点一下打开设置 · 同步"), "".join(rows)))
FILES["A-sync-states.dc.html"] = page("顶栏 · 同步格的状态", 1040, 620, body)

# ============================ 设置窗口 ============================
def tile(color, inner, filled_icon=False):
    fg = onband(color)
    ic = filled(inner, fg, 15) if filled_icon else stroke(inner, fg, 15, 1.6)
    return ('<span style="width: 26px; height: 26px; flex: none; border-radius: 7px; background: %s; display: flex; '
            'align-items: center; justify-content: center; color: %s;">%s</span>' % (color, fg, ic))

def toggle(on=True):
    return ('<span role="switch" aria-checked="%s" style="width: 38px; height: 22px; flex: none; border-radius: 11px; background: %s; '
            'position: relative; display: inline-block;"><span style="position: absolute; top: 2px; %s width: 18px; height: 18px; '
            'border-radius: 9px; background: #FFFFFF; box-shadow: 0 1px 3px rgba(0,0,0,0.2);"></span></span>'
            % ("true" if on else "false", SUCCESS_L if on else "rgba(118,118,128,0.24)", "left: 18px;" if on else "left: 2px;"))

def popup(th, text, w=None):
    ws = ("width: %dpx;" % w) if w else ""
    return ('<button type="button" style="display: inline-flex; align-items: center; gap: 6px; height: 24px; padding: 0 6px 0 10px; %s '
            'box-sizing: border-box; border-radius: 6px; background: %s; box-shadow: 0 0 0 0.5px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.08); '
            'font-size: 12px; color: %s;"><span style="flex-grow: 1; text-align: left;">%s</span>%s</button>'
            % (ws, th["card"], th["label"], text, stroke(UPDOWN_I, th["sec"], 11, 1.6)))

def pbutton(th, text, danger=False):
    return ('<button type="button" style="display: inline-flex; align-items: center; height: 24px; padding: 0 10px; '
            'border-radius: 6px; background: %s; box-shadow: 0 0 0 0.5px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.08); '
            'font-size: 12px; color: %s; white-space: nowrap; flex: none;">%s</button>'
            % (th["card"], DESTRUCT_L if danger else th["label"], text))

def srow(th, lead, label, right="", sub="", last=False, label_color=None):
    border = "" if last else "border-bottom: 0.5px solid %s;" % th["sep"]
    subh = ('<div style="font-size: 10px; line-height: 14px; color: %s; margin-top: 1px;">%s</div>' % (th["meta"], sub)) if sub else ""
    return ('<div style="display: flex; align-items: center; gap: 10px; min-height: 40px; padding: 7px 12px; '
            'box-sizing: border-box; %s">%s<div style="flex-grow: 1; min-width: 0;">'
            '<div style="font-size: 13px; color: %s;">%s</div>%s</div>%s</div>'
            % (border, lead, label_color or th["label"], label, subh, right))

def value(th, t):
    return '<span style="font-size: 12px; color: %s; flex: none;">%s</span>' % (th["meta"], t)

def group(th, rows_html):
    return ('<div style="border-radius: 10px; overflow: hidden; background: %s; box-shadow: %s; flex: none;">%s</div>'
            % (th["card"], th["cring"], rows_html))

def foot(th, t):
    return '<div style="font-size: 11px; line-height: 15px; color: %s; padding: 0 4px; flex: none;">%s</div>' % (th["meta"], t)

def seg(th, items, active):
    out = []
    for i in items:
        on = i == active
        out.append('<button type="button" aria-pressed="%s" style="height: 24px; padding: 0 12px; border-radius: 6px; font-size: 12px; '
                   'font-weight: %s; background: %s; color: %s; box-shadow: %s;">%s</button>'
                   % ("true" if on else "false", "600" if on else "400", th["card"] if on else "transparent", th["label"],
                      "0 1px 2px rgba(0,0,0,0.12)" if on else "none", i))
    return ('<div style="display: inline-flex; gap: 2px; padding: 3px; border-radius: 8px; background: %s;">%s</div>'
            % (th["fill"], "".join(out)))

TABS = ["通用", "同步", "快捷键", "历史", "关于"]   # 第 9 条：顺序按设计稿

def win(th, tab, content, gap=12):
    bar = ('<div style="height: 38px; flex: none; box-sizing: border-box; padding: 0 14px; display: flex; align-items: center; '
           'gap: 12px; background: %s; border-bottom: 0.5px solid %s;">'
           '<div style="display: flex; gap: 8px;"><span style="width: 12px; height: 12px; border-radius: 6px; background: #FF5F57;"></span>'
           '<span style="width: 12px; height: 12px; border-radius: 6px; background: rgba(118,118,128,0.3);"></span>'
           '<span style="width: 12px; height: 12px; border-radius: 6px; background: rgba(118,118,128,0.3);"></span></div>'
           '<span style="flex-grow: 1; text-align: center; font-size: 13px; font-weight: 600; color: %s; margin-left: -56px;">设置</span></div>'
           % (th["glass"], th["sep"], th["label"]))
    tabs = '<div style="padding: 12px 16px 4px; display: flex; justify-content: center; flex: none;">%s</div>' % seg(th, TABS, tab)
    return ('<div style="width: 540px; height: 460px; flex: none; border-radius: 11px; overflow: hidden; display: flex; flex-direction: column; '
            'background: %s; box-shadow: 0 0 0 0.5px rgba(0,0,0,0.2), 0 24px 56px rgba(0,0,0,0.34);">%s%s'
            '<div style="flex-grow: 1; min-height: 0; box-sizing: border-box; padding: 12px 16px 16px; display: flex; flex-direction: column; '
            'gap: %dpx; overflow: hidden;">%s</div></div>' % (th["grouped"], bar, tabs, gap, content))

def settings_board(title, wins):
    w = 36 * 2 + 540 * len(wins) + 40 * (len(wins) - 1)
    body = ('<div style="width: %dpx; height: 532px; box-sizing: border-box; padding: 36px; background: %s; display: flex; gap: 40px;">%s</div>'
            % (w, L["desktop"], "".join(wins)))
    return w, page(title, w, 532, body)

th = L
general = (h2(th, "启动") +
           group(th, srow(th, tile("#34C759", POWER_I), "登录时启动 Copyo", toggle()) +
                 srow(th, tile("#8E8E93", MENUBAR_I), "在菜单栏显示图标", toggle(),
                      sub="关闭后可按 ⇧⌘V 或在访达中再次打开 Copyo 找回设置", last=True)) +
           h2(th, "捕获") +
           group(th, srow(th, tile(ACCENT, CLIP_I), "自动记录剪贴板", toggle(), sub="Copyo 在后台记录，不需要任何权限") +
                 srow(th, tile("#FF9F0A", KEY_I), "忽略密码管理器", value(th, "始终开启"),
                      sub="来自 1Password、钥匙串的内容不会被记录", last=True)) +
           foot(th, "复制后 Copyo 把内容写回系统剪贴板并把焦点交还给原来的 App，由你自己按 ⌘V —— Copyo 从不代你粘贴。"))

def keyrow(label, caps, last=False):
    border = "" if last else "border-bottom: 0.5px solid %s;" % th["sep"]
    return ('<div style="display: flex; align-items: center; gap: 6px; height: 34px; padding: 0 12px; box-sizing: border-box; %s">'
            '<span style="flex-grow: 1; font-size: 13px; color: %s; white-space: nowrap;">%s</span>%s</div>'
            % (border, th["label"], label, "".join(keycap(c, th) for c in caps)))

left = [("复制选中项", ["↩"]), ("纯文本复制", ["⇧↩"]), ("预览", ["空格", "⌘Y"]), ("固定到 Pinboard", ["⌘P"]), ("删除", ["⌘⌫"])]
right = [("聚焦搜索", ["⌘F"]), ("在筛选间循环", ["⇥"]), ("直接复制第 N 张", ["⌘1–9"]), ("关闭面板", ["esc"])]
kgroup = lambda rs: ('<div style="flex: 1 1 0; min-width: 0; border-radius: 10px; overflow: hidden; background: %s; box-shadow: %s; align-self: flex-start;">%s</div>'
                     % (th["card"], th["cring"], "".join(keyrow(a, b, i == len(rs) - 1) for i, (a, b) in enumerate(rs))))
recorder = ('<button type="button" style="display: inline-flex; align-items: center; justify-content: center; min-width: 88px; '
            'height: 26px; padding: 0 10px; border-radius: 7px; background: %s; box-shadow: 0 0 0 0.5px rgba(0,0,0,0.12); font-family: %s; '
            'font-size: 12px; font-weight: 500; color: %s; flex: none;">⇧⌘V</button>' % (th["card"], MONO, th["label"]))
shortcuts = (h2(th, "唤出", "点一下可以改") +
             group(th, srow(th, tile("#5856D6", CMD_I), "唤出面板", recorder, last=True)) +
             ('<div style="display: flex; align-items: center; gap: 6px; font-size: 11px; color: %s; padding: 0 4px; flex: none;">%s'
              '<span>这个组合已被另一个 App 占用，已恢复为 ⇧⌘V</span></div>'
              % (DESTRUCT_L, stroke('<circle cx="8" cy="8" r="6.2"></circle><path d="M8 4.8v4M8 10.8v.4"></path>', DESTRUCT_L, 13, 1.6))) +
             h2(th, "面板内") +
             '<div style="display: flex; gap: 12px; flex: none;">%s%s</div>' % (kgroup(left), kgroup(right)))

w1, FILES["Settings-general.dc.html"] = settings_board("设置 · 通用 / 快捷键", [win(th, "通用", general), win(th, "快捷键", shortcuts)])

path_row = ('<div style="flex-grow: 1; min-width: 0; font-family: %s; font-size: 11px; color: %s; white-space: nowrap; overflow: hidden; '
            'text-overflow: ellipsis;">~/Library/Mobile Documents/com~apple~CloudDocs/Copyo</div>' % (MONO, th["meta"]))
sync_folder = (group(th, srow(th, tile(ACCENT, FOLDER), "同步方式", popup(th, "共享文件夹", 132), last=True)) +
               foot(th, "把历史存成快照放进一个文件夹，iCloud Drive 或任意共享目录都行；删除不会同步到其他设备。") +
               h2(th, "同步文件夹") +
               group(th, '<div style="display: flex; align-items: center; gap: 10px; min-height: 40px; padding: 7px 12px; box-sizing: border-box; '
                         'border-bottom: 0.5px solid %s;">%s%s</div>' % (th["sep"], path_row, pbutton(th, "选择文件夹…")) +
                     srow(th, stroke(FOLDER_OK_I, SUCCESS_L, 18, 1.5), "已同步", value(th, "3 分钟前")) +
                     srow(th, stroke(FOLDER_WARN_I, WARN, 18, 1.5), "无法访问这个文件夹", pbutton(th, "重新选择…"),
                          sub="失败时这一行替换上一行：目录被移走、改名或授权失效", last=True)) +
               '<div style="display: flex; justify-content: flex-end; flex: none;">%s</div>' % pbutton(th, "恢复默认位置"))
sync_icloud = (group(th, srow(th, tile(ACCENT, CLOUD), "同步方式", popup(th, "iCloud", 132), last=True)) +
               foot(th, "直接镜像到你的 iCloud，删除会在所有设备生效。") +
               h2(th, "状态") +
               group(th, srow(th, stroke(CLOUD_OK_I, SUCCESS_L, 18, 1.5), "iCloud 账户", value(th, "可用")) +
                     srow(th, stroke(CLOUD_WARN_I, WARN, 18, 1.5), "改了同步方式，重启后生效", pbutton(th, "重启 Copyo"),
                          sub="只在切换方式后出现", last=True)))
w2, FILES["Settings-sync.dc.html"] = settings_board("设置 · 同步（共享文件夹 / iCloud）",
                                                    [win(th, "同步", sync_folder), win(th, "同步", sync_icloud)])

def app_row(name, bid, color, last=False):
    ic = ('<span style="width: 24px; height: 24px; flex: none; border-radius: 6px; background: %s; box-shadow: %s;"></span>'
          % (color, th["swatchring"]))
    border = "" if last else "border-bottom: 0.5px solid %s;" % th["sep"]
    return ('<div style="display: flex; align-items: center; gap: 10px; height: 36px; padding: 0 12px; box-sizing: border-box; %s">%s'
            '<span style="font-size: 13px; color: %s;">%s</span><span style="font-family: %s; font-size: 10px; color: %s;">%s</span></div>'
            % (border, ic, th["label"], name, MONO, th["ter"], bid))

pm = ('<div style="display: flex; height: 24px; border-top: 0.5px solid %s; background: %s;">'
      '<button type="button" aria-label="添加 App" style="width: 28px; display: flex; align-items: center; justify-content: center; '
      'border-right: 0.5px solid %s;">%s</button>'
      '<button type="button" aria-label="移除所选 App" style="width: 28px; display: flex; align-items: center; justify-content: center; '
      'border-right: 0.5px solid %s;">%s</button></div>'
      % (th["sep"], th["card"], th["sep"], stroke(PLUS_I, th["label"], 11, 1.6), th["sep"], stroke(MINUS_I, th["label"], 11, 1.6)))
history = (group(th, srow(th, tile("#FF9F0A", CLOCK_I), "最多保留", popup(th, "500 条", 96), last=True)) +
           h2(th, "不记录这些 App", "从它们复制的内容不会进历史") +
           group(th, app_row("终端", "com.apple.Terminal", SRCHEX["终端"]) +
                 app_row("Microsoft Remote Desktop", "com.microsoft.rdc.macos", SRCHEX["Microsoft Remote Desktop"], last=True) + pm) +
           group(th, srow(th, tile(DESTRUCT_L, TRASH_I), "清空历史…", sub="只清除没有固定到 Pinboard 的条目", label_color=DESTRUCT_L) +
                 srow(th, tile("#8E8E93", TRASH_I), "删除所有数据…", sub="包括所有 Pinboard 与已固定的条目", last=True,
                      label_color=DESTRUCT_L)))
about = ('<div style="flex-grow: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 10px;">'
         '%s<div style="font-size: 17px; font-weight: 700; color: %s; margin-top: 4px;">Copyo</div>'
         '<div style="font-size: 12px; line-height: 18px; color: %s; text-align: center; max-width: 380px;">复制过的东西都在这里，按 ⇧⌘V 随时取回。<br>'
         '你的历史只存在这台 Mac 和你自己选的同步位置里，Copyo 不收集任何数据。</div></div>'
         % (PLATE, th["label"], th["meta"]) +
         group(th, srow(th, tile("#30B0C7", INFO_I), "版本", value(th, "1.1.0"), last=True)))
w3, FILES["Settings-history.dc.html"] = settings_board("设置 · 历史 / 关于", [win(th, "历史", history), win(th, "关于", about)])

# ============================ 组件板 ============================
def labelled(th, cardhtml, cap):
    return ('<div style="display: flex; flex-direction: column; gap: 7px;">%s'
            '<div style="font-size: 11px; line-height: 15px; color: %s; width: 260px;">%s</div></div>' % (cardhtml, th["meta"], cap))

def rowx(children, gap=12):
    return '<div style="display: flex; gap: %dpx; align-items: flex-start;">%s</div>' % (gap, "".join(children))

def kind_row(th):
    img = "#F0E4BE" if th is not D else "#4A431F"
    demo = [
        ("text", "Xcode", "2 分钟前", body_text(th, "git rebase -i HEAD~3 &amp;&amp; git push --force-with-lease", mono=True), None, "文本 · 代码用等宽 11/15 Regular"),
        ("rich", "备忘录", "3 小时前", body_text(th, NOTES), None, "富文本 · 角标最宽（54pt）"),
        ("link", "Safari", "25 分钟前", body_link(th, "Adopting Liquid Glass | Apple Developer Documentation", "developer.apple.com"), None, "链接 · 标题 + 域名用 accent"),
        ("image", "备忘录", "昨天 18:42", body_image(th, img), None, "图片 · 缩略图圆角 10"),
        ("color", "Figma", "1 小时前", body_color(th, COLORCLIP[0]), COLORCLIP[0], "颜色 · 淡染取剪贴内容本身"),
        ("file", "访达", "昨天 18:02", body_files(th, "Q3-复盘.key", "另外 4 个文件"), None, "文件 · 图标按扩展名取，不读文件"),
    ]
    return rowx([labelled(th, card(th, k, s, t, b, srccol=c), cap) for k, s, t, b, c, cap in demo])

def state_row(th):
    mk = lambda **kw: card(th, "text", "微信", "12 分钟前", body_text(th, WX), **kw)
    return rowx([labelled(th, c, cap) for c, cap in [
        (mk(), "默认"),
        (mk(hover=True), "悬停 · 淡染 12→16%、来源色 40% 描边、玻璃动作簇"),
        (mk(state="current"), "当前卡 · 面板是 key window：2px + 7px @32%"),
        (mk(state="inactive"), "当前卡 · 面板失焦：3px @45%"),
        (mk(state="lift", pinned=True), "拖起 · rotate −2° scale 1.03 + 已固定 pin.fill"),
    ]])

def tight_row(th):
    return rowx([labelled(th, c, cap) for c, cap in [
        (card(th, "rich", "Microsoft Remote Desktop", "昨天 18:42", body_text(th, "第三季度复盘（终稿）—— 渠道、留存、以及那三个没做完的实验。"), pinned=True),
         "最紧：富文本角标 + 图钉 + 长来源名。省略号只吃来源名，时间永不被截"),
        (card(th, "rich", "备忘录", "上周", body_text(th, "第三季度复盘（终稿）")), "同一类卡的宽松情形"),
        (card(th, "text", None, "3 分钟前", body_text(th, "这条是 iPhone 上存进来的，来源色是 nil，显示时回退到 #8E8E93。"), shown_src="iPhone"),
         "来源色为 nil —— 两端走同一条回退"),
        (card(th, "text", "Xcode", "2 分钟前", body_text(th, "Thread 1: Fatal error: Unexpectedly found nil while unwrapping an Optional value", mono=True)),
         "等宽长行按词断，不横向滚动"),
    ]])

def degraded_row(th):
    return rowx([labelled(th, c, cap) for c, cap in [
        (card(th, "image", "备忘录", "昨天 18:42", body_image_pending(th)), "图片未就绪 / 解码失败 · 淡染底 + photo 符号"),
        (card(th, "file", "访达", "2 天前", body_files(th, "季度预算-终稿.numbers", "", top=SRCHEX["访达"])), "单个文件 · 文件名两行截断"),
        (card(th, "color", "Figma", "1 小时前", body_text(th, "rgb(255, 45, 85, 1.2)"), srccol=SRCHEX["Figma"]),
         "颜色解析失败 · 回退来源色，按普通卡画"),
    ]])

dark_strip = lambda inner: ('<div style="box-sizing: border-box; padding: 20px; border-radius: 16px; background: %s; align-self: flex-start;">%s</div>'
                            % (D["grouped"], inner))
body = ('<div style="width: 1760px; height: 1440px; box-sizing: border-box; padding: 40px; background: %s; '
        'display: flex; flex-direction: column; gap: 24px;">%s</div>'
        % (L["grouped"], "".join([
            h1(L, "ClipCard · dense", "260 × 184 · 圆角 12 · 内距 12 · 正文最多 6 行 · 整卡淡染来源色"),
            h2(L, "六种类型 · 浅色"), kind_row(L),
            h2(L, "六种类型 · 深色", "底色 #2C2C2E，淡染 20%"), dark_strip(kind_row(D)),
            h2(L, "状态", "「选中」与「键盘焦点」已合并为「当前卡」"), state_row(L),
            h2(L, "排版最紧的几种情况"), tight_row(L),
            h2(L, "降级态"), degraded_row(L)])))
FILES["Card.dc.html"] = page("卡片组件 · ClipCard dense", 1760, 1440, body)

# ============================ Token 板 ============================
def swatch(name, lv, dv, note_t=""):
    return ('<div style="display: flex; flex-direction: column; gap: 6px; width: 148px;">'
            '<div style="display: flex; height: 52px; border-radius: 9px; overflow: hidden; box-shadow: %s;">'
            '<div style="flex-grow: 1; background: %s;"></div><div style="flex-grow: 1; background: %s;"></div></div>'
            '<div style="font-family: %s; font-size: 11px; font-weight: 600; color: %s;">%s</div>'
            '<div style="font-family: %s; font-size: 10px; line-height: 14px; color: %s;">%s<br>%s</div>'
            '<div style="font-size: 10px; line-height: 14px; color: %s;">%s</div></div>'
            % (L["swatchring"], lv, dv, MONO, L["label"], name, MONO, L["meta"], lv, dv, L["ter"], note_t))

SW = [
    ("bg.grouped", "#F2F2F7", "#1C1C1E", "深色离开纯黑"),
    ("bg.card", "#FFFFFF", "#2C2C2E", "淡染的基底；rowOpaque 是它的别名"),
    ("label", "#000000", "#FFFFFF", ""),
    ("label.secondary", "rgba(60,60,67,.6)", "rgba(235,235,245,.6)", ""),
    ("label.tertiary", "rgba(60,60,67,.34)", "rgba(235,235,245,.34)", "macOS 取 .34，iOS 保持 .3"),
    ("label.meta", "rgba(60,60,67,.78)", "rgba(235,235,245,.72)", "Mac 专属 · 10pt meta 在淡染上要 4.5:1"),
    ("fill", "rgba(118,118,128,.12)", "rgba(118,118,128,.24)", "搜索框、未选中胶囊；悬停换 fill2"),
    ("fill2", "rgba(118,118,128,.2)", "rgba(118,118,128,.32)", "keycap、色值胶囊"),
    ("separator", "rgba(60,60,67,.24)", "rgba(84,84,88,.6)", ""),
    ("accent", "#0A84FF", "#0A84FF", "钉死，不跟随系统重点色"),
    ("destructive", "#FF3B30", "#FF453A", ""),
    ("success", "#34C759", "#30D158", "同步正常"),
    ("warning", "#FF9F0A", "#FF9F0A", "同步需要处理"),
    ("source.local", "#8E8E93", "#8E8E93", "来源色为 nil 时显示层回退"),
    ("brand.bone", "#F7F3EA", "#F7F3EA", "只在 App 图标、空态插画"),
    ("brand.red", "#FF2D55", "#FF2D55", "同上 —— 正文、描边、控件一律不得使用"),
]

def tintdemo(name, hexv):
    tl, td, hl, hd = tint(hexv, L), tint(hexv, D), tint(hexv, L, True), tint(hexv, D, True)
    blk = lambda c, ring: '<div style="height: 30px; border-radius: 8px; background: %s; box-shadow: %s;"></div>' % (c, ring)
    return ('<div style="display: flex; flex-direction: column; gap: 5px; width: 128px;">'
            '<div style="display: flex; align-items: center; gap: 6px;">'
            '<span style="width: 16px; height: 16px; border-radius: 4px; background: %s; box-shadow: %s;"></span>'
            '<span style="font-size: 11px; color: %s;">%s</span></div>%s%s%s%s'
            '<div style="font-family: %s; font-size: 9px; line-height: 13px; color: %s;">%s · %s<br>%s · %s</div></div>'
            % (hexv, L["swatchring"], L["meta"], name, blk(tl, L["swatchring"]), blk(hl, L["swatchring"]),
               blk(td, D["swatchring"]), blk(hd, D["swatchring"]), MONO, L["ter"], tl, hl, td, hd))

def typerow(sample, spec, style):
    return ('<div style="display: flex; align-items: baseline; gap: 18px; height: 30px;">'
            '<div style="width: 260px; %s color: %s;">%s</div>'
            '<div style="font-family: %s; font-size: 11px; color: %s;">%s</div></div>'
            % (style, L["label"], sample, MONO, L["meta"], spec))

def radrow(label, px, size=56):
    return ('<div style="display: flex; flex-direction: column; align-items: center; gap: 6px;">'
            '<div style="width: %dpx; height: %dpx; border-radius: %dpx; background: %s; box-shadow: %s;"></div>'
            '<div style="font-family: %s; font-size: 10px; color: %s;">%d</div>'
            '<div style="font-size: 10px; color: %s;">%s</div></div>'
            % (size, size, px, L["card"], L["swatchring"], MONO, L["label"], px, L["ter"], label))

tints = [("Xcode", SRCHEX["Xcode"]), ("微信", SRCHEX["微信"]), ("Safari / 访达", SRCHEX["Safari"]),
         ("备忘录", SRCHEX["备忘录"]), ("颜色条目 · 取自身", COLORCLIP[0]), ("nil → source.local", LOCAL)]
body = ('<div style="width: 1760px; height: 1000px; box-sizing: border-box; padding: 40px; background: %s; '
        'display: flex; flex-direction: column; gap: 24px;">%s%s'
        '<div style="display: flex; flex-wrap: wrap; gap: 16px;">%s</div>'
        '<div style="display: flex; gap: 56px;">'
        '<div style="display: flex; flex-direction: column; gap: 12px;">%s%s<div style="display: flex; gap: 12px;">%s</div></div>'
        '<div style="display: flex; flex-direction: column; gap: 12px;">%s%s</div>'
        '<div style="display: flex; flex-direction: column; gap: 12px;">%s<div style="display: flex; gap: 20px;">%s</div></div>'
        '</div></div>'
        % (L["grouped"],
           h1(L, "Tokens", "左半格 = 浅色，右半格 = 深色 · 2026-09-27 拍板后"),
           h2(L, "语义色"), "".join(swatch(*s) for s in SW),
           h2(L, "来源淡染", "运行时按公式算：浅 12% / 悬停 16%，深 20% / 悬停 26%"),
           '<div style="font-size: 11px; line-height: 16px; color: %s; width: 600px;">每列自上而下：浅 · 浅悬停 · 深 · 深悬停。'
           '两端用同一个 mix，不量化；这里的 hex 只是画板示意。</div>' % L["meta"],
           "".join(tintdemo(n, v) for n, v in tints),
           h2(L, "字号 · macOS dense", "固定点数，不随系统文字大小"),
           "".join([
               typerow("还没有内容", "17 / 22 Bold — 空态标题、关于", "font-size: 17px; line-height: 22px; font-weight: 700;"),
               typerow("搜索历史", "13 / 18 Regular — 搜索框、设置行、菜单", "font-size: 13px; line-height: 18px;"),
               typerow("周五下午三点在 3 楼小会议室", "12 / 16 Regular — 卡片正文", "font-size: 12px; line-height: 16px;"),
               typerow("git rebase -i HEAD~3", "11 / 15 Regular mono — 代码正文", "font-family: %s; font-size: 11px; line-height: 15px;" % MONO),
               typerow("Xcode · 2 分钟前", "10 / 13 Regular — 卡片 meta", "font-size: 10px; line-height: 13px;"),
               typerow("文本", "10 Semibold — 类型角标", "font-size: 10px; font-weight: 600;"),
               typerow("⌘P 固定", "11 Regular + keycap 11 mono — 底部提示条", "font-size: 11px;"),
           ]),
           h2(L, "圆角"),
           "".join([radrow("面板", 26), radrow("预览窗", 20), radrow("卡片 · 预览块", 12), radrow("缩略图 · 色块", 10),
                    radrow("胶囊 · 搜索框", 8), radrow("角标", 9, 40), radrow("keycap", 6, 40)])))
FILES["Tokens.dc.html"] = page("Tokens · 色 / 淡染 / 字号 / 圆角", 1760, 1000, body)

os.makedirs(OUT, exist_ok=True)
for name, text in FILES.items():
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        f.write(text)
    print("wrote", name, len(text))
print("settings widths", w1, w2, w3)
