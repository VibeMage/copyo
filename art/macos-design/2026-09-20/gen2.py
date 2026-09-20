#!/usr/bin/env python3
# Second pass: component plate, token plate, settings. Reuses gen.py's helpers.
import os
BASE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(BASE, "gen.py"), encoding="utf-8").read()
exec(src.split("for name, text in FILES.items():")[0])

F2 = {}
PAD = 40

def h1(th, t, sub=""):
    s = ('<span style="font-size: 12px; color: %s; margin-left: 10px;">%s</span>' % (th["ter"], sub)) if sub else ""
    return ('<div style="font-size: 17px; font-weight: 700; color: %s; display: flex; align-items: baseline;">%s%s</div>'
            % (th["label"], t, s))

def h2(th, t, sub=""):
    s = ('<span style="font-size: 11px; font-weight: 400; color: %s; margin-left: 8px;">%s</span>' % (th["ter"], sub)) if sub else ""
    return ('<div style="font-size: 11px; font-weight: 600; letter-spacing: 0.4px; color: %s; height: 20px; '
            'display: flex; align-items: center;">%s%s</div>' % (th["sec"], t, s))

def note(th, t, w=None):
    ws = ("width: %dpx;" % w) if w else ""
    return '<div style="%s font-size: 11px; line-height: 16px; color: %s;">%s</div>' % (ws, th["meta"], t)

def row(children, gap=12, align="flex-start"):
    return ('<div style="display: flex; gap: %dpx; align-items: %s;">%s</div>' % (gap, align, "".join(children)))

def colstack(children, gap=8):
    return '<div style="display: flex; flex-direction: column; gap: %dpx;">%s</div>' % (gap, "".join(children))

def labelled(th, cardhtml, cap):
    return ('<div style="display: flex; flex-direction: column; gap: 7px;">%s'
            '<div style="font-size: 11px; color: %s; width: 260px;">%s</div></div>' % (cardhtml, th["meta"], cap))

# ============================ Card plate ============================
def kind_row(th):
    demo = [
        ("text", "Xcode", "Xcode · 2 分钟前", body_text(th, "git rebase -i HEAD~3 &amp;&amp; git push --force-with-lease", 7, True), None, None),
        ("rich", "备忘录", "备忘录 · 09:12", body_text(th, "站会纪要 9/4\n· 登录页流程另开一稿\n· 图标最终稿 8a 已定\n· TestFlight 周三发", 7), None, None),
        ("link", "Safari", "Safari · 25 分钟前", body_link(th, "Adopting Liquid Glass | Apple Developer Documentation", "developer.apple.com"), None, None),
        ("image", "备忘录", "备忘录 · 昨天 18:42", body_image(th, "#F0E4BE" if th is not D else "#4A431F"), None, None),
        ("color", "Figma", "Figma · 1 小时前", body_color(th, COLORCLIP[0]), (COLORCLIP[2] if th is D else COLORCLIP[1]), COLORCLIP[0]),
        ("file", "访达", "访达 · 昨天 18:02", body_files(th, "Q3-复盘.key", "另外 4 个文件"), None, None),
    ]
    caps = ["文本 · 代码用等宽 11/15", "富文本 · 角标是最宽的中文", "链接 · 标题 + 域名用 accent",
            "图片 · 缩略图圆角 10", "颜色 · 淡染取剪贴内容本身", "文件 · Mac 独有的多文件堆叠"]
    return row([labelled(th, card(th, k, s, m, b, tint=t, srccol=c), cap)
                for (k, s, m, b, t, c), cap in zip(demo, caps)])

def state_row(th):
    mk = lambda **kw: card(th, "text", "微信", "微信 · 12 分钟前",
                           body_text(th, "周五下午三点在 3 楼小会议室对一下 Q4 的排期，记得把上周的漏斗数据带上，顺便看看新江湾那边场地的报价。"), **kw)
    items = [
        (mk(), "默认"),
        (mk(hover=True), "悬停 · 玻璃动作簇 pin / delete"),
        (mk(sel="select"), "选中 · 面板是 key window，3pt accent"),
        (mk(sel="key-inactive"), "选中 · 面板失焦，降到 45% —— macOS 才有的态"),
        (mk(sel="focus"), "键盘焦点 · 2pt + 5pt @32%"),
        (mk(sel="lift", pinned=True), "拖起 · rotate −2° scale 1.03 + 已固定图钉"),
    ]
    return row([labelled(th, c, cap) for c, cap in items])

def tight_row(th):
    items = [
        (card(th, "rich", "备忘录", "Microsoft Word · 昨天 18:42", body_text(th, "第三季度复盘（终稿）—— 渠道、留存、以及那三个没做完的实验。", 6)),
         "最紧：富文本角标 44pt + 长来源名。meta 行省略号从来源名开始吃，时间永不被截"),
        (card(th, "rich", "备忘录", "Word · 昨天", body_text(th, "第三季度复盘（终稿）", 6)), "同一张卡的宽松情形"),
        (card(th, "text", "本机", "本机 · 3 分钟前", body_text(th, "这条是 iPhone 上存进来的，没有来源色，回退到中性灰 #8E8E93。", 6)),
         "无来源色回退 —— iOS 存进来的条目在 Mac 上长这样"),
        (card(th, "text", "Xcode", "Xcode · 2 分钟前", body_text(th, "Thread 1: Fatal error: Unexpectedly found nil while unwrapping an Optional value", 7, True)),
         "等宽长行按词断，不横向滚动"),
    ]
    return row([labelled(th, c, cap) for c, cap in items])

dark_strip = lambda inner: ('<div style="box-sizing: border-box; padding: 20px; border-radius: 16px; background: %s;">%s</div>'
                            % (D["grouped"], inner))

body = ('<div style="width: 1760px; height: 1180px; box-sizing: border-box; padding: %dpx; background: %s; '
        'display: flex; flex-direction: column; gap: 26px;">'
        '%s%s%s%s%s%s%s%s</div>'
        % (PAD, L["grouped"],
           h1(L, "ClipCard · dense", "260 × 184 · 圆角 12 continuous · 内距 12 · 整卡淡染来源色"),
           h2(L, "六种类型 · 浅色"), kind_row(L),
           h2(L, "六种类型 · 深色", "底色从 #1C1C1E 抬到 #2C2C2E，20% 淡染才分得出来"),
           dark_strip(kind_row(D)),
           h2(L, "状态"), state_row(L),
           h2(L, "排版最紧的几种情况") + tight_row(L)))
F2["Card.dc.html"] = page("卡片组件 · ClipCard dense", 1760, 1180, body)

# ============================ Token plate ============================
def swatch(name, lv, dv, note_t=""):
    return ('<div style="display: flex; flex-direction: column; gap: 6px; width: 148px;">'
            '<div style="display: flex; height: 52px; border-radius: 9px; overflow: hidden; box-shadow: %s;">'
            '<div style="flex-grow: 1; background: %s;"></div><div style="flex-grow: 1; background: %s;"></div></div>'
            '<div style="font-family: %s; font-size: 11px; font-weight: 600; color: %s;">%s</div>'
            '<div style="font-family: %s; font-size: 10px; line-height: 14px; color: %s;">%s<br>%s</div>'
            '<div style="font-size: 10px; line-height: 14px; color: %s;">%s</div></div>'
            % (L["swatchring"], lv, dv, MONO, L["label"], name, MONO, L["meta"], lv, dv, L["ter"], note_t))

SW = [
    ("bg.grouped", "#F2F2F7", "#1C1C1E", "深色离开纯黑 —— 窗口里的黑是个洞"),
    ("bg.card", "#FFFFFF", "#2C2C2E", "淡染的基底"),
    ("bg.raised", "#FFFFFF", "#3A3A3C", "新增 · 把 ShareTheme 里那条没回流的补丁转正"),
    ("label", "#000000", "#FFFFFF", ""),
    ("label.secondary", "rgba(60,60,67,.6)", "rgba(235,235,245,.6)", ""),
    ("label.meta", "rgba(60,60,67,.78)", "rgba(235,235,245,.72)", "Mac 专属 · 10pt meta 在淡染上要 4.5:1"),
    ("fill", "rgba(118,118,128,.12)", "rgba(118,118,128,.24)", "搜索框、未选中胶囊"),
    ("fill2", "rgba(118,118,128,.2)", "rgba(118,118,128,.32)", "keycap、色值胶囊"),
    ("separator", "rgba(60,60,67,.24)", "rgba(84,84,88,.6)", ""),
    ("accent", "#0A84FF", "#0A84FF", "钉死，不跟随系统重点色"),
    ("destructive", "#FF3B30", "#FF453A", ""),
    ("success", "#34C759", "#30D158", ""),
    ("warning", "#FF9F0A", "#FF9F0A", ""),
    ("source.local", "#8E8E93", "#8E8E93", "无来源色时的回退，两端必须同一个"),
    ("brand.bone", "#F7F3EA", "#F7F3EA", "只在图标、空态、引导、设置图标砖"),
    ("brand.red", "#FF2D55", "#FF2D55", "同上 —— 正文、描边、控件一律不得使用"),
]

def tintdemo(name, hexv, tl, td):
    return ('<div style="display: flex; flex-direction: column; gap: 5px; width: 128px;">'
            '<div style="display: flex; align-items: center; gap: 6px;">'
            '<span style="width: 16px; height: 16px; border-radius: 4px; background: %s; box-shadow: %s;"></span>'
            '<span style="font-size: 11px; color: %s;">%s</span></div>'
            '<div style="height: 34px; border-radius: 8px; background: %s; box-shadow: %s;"></div>'
            '<div style="height: 34px; border-radius: 8px; background: %s; box-shadow: %s;"></div>'
            '<div style="font-family: %s; font-size: 9px; line-height: 13px; color: %s;">%s<br>%s</div></div>'
            % (hexv, L["swatchring"], L["meta"], name, tl, L["swatchring"], td, D["swatchring"], MONO, L["ter"], tl, td))

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

body = ('<div style="width: 1760px; height: 1000px; box-sizing: border-box; padding: %dpx; background: %s; '
        'display: flex; flex-direction: column; gap: 24px;">'
        '%s'
        '%s<div style="display: flex; flex-wrap: wrap; gap: 16px;">%s</div>'
        '<div style="display: flex; gap: 56px;">'
        '<div style="display: flex; flex-direction: column; gap: 12px;">%s%s'
        '<div style="display: flex; gap: 12px;">%s</div></div>'
        '<div style="display: flex; flex-direction: column; gap: 12px;">%s%s</div>'
        '<div style="display: flex; flex-direction: column; gap: 12px;">%s<div style="display: flex; gap: 20px;">%s</div></div>'
        '</div></div>'
        % (PAD, L["grouped"],
           h1(L, "Tokens", "左半格 = 浅色，右半格 = 深色。数值逐字取自 iOS 规格，标注处为 macOS 修订"),
           h2(L, "语义色"),
           "".join(swatch(*s) for s in SW),
           h2(L, "来源淡染", "mix(sourceColor, bg.card, 12%) 浅 · 20% 深"),
           note(L, "上格浅色 · 下格深色。颜色类条目取剪贴内容本身的颜色，不取来源 App —— 这是相对 iOS 的一处修订。", 560),
           "".join(tintdemo(n, v[0], v[1], v[2]) for n, v in
                   [("Xcode", SRC["Xcode"]), ("微信", SRC["微信"]), ("Safari", SRC["Safari"]),
                    ("备忘录", SRC["备忘录"]), ("本机 / iOS 来源", SRC["本机"])]),
           h2(L, "字号 · macOS dense"),
           "".join([
               typerow("历史", "17 / 22 Bold — 窗口标题、详情标题", "font-size: 17px; line-height: 22px; font-weight: 700;"),
               typerow("搜索历史", "13 / 18 Regular — 搜索框、侧栏行", "font-size: 13px; line-height: 18px;"),
               typerow("周五下午三点在 3 楼小会议室", "12 / 16 Regular — 卡片正文", "font-size: 12px; line-height: 16px;"),
               typerow("git rebase -i HEAD~3", "11 / 15 Medium mono — 代码正文（Mac 上是新增）", "font-family: %s; font-size: 11px; line-height: 15px; font-weight: 500;" % MONO),
               typerow("Xcode · 2 分钟前", "10 / 13 Regular — 卡片 meta", "font-size: 10px; line-height: 13px;"),
               typerow("文本", "10 Semibold — 类型角标", "font-size: 10px; font-weight: 600;"),
               typerow("⌘P 固定", "11 Regular + keycap 11 mono — 底部提示条", "font-size: 11px;"),
           ]),
           h2(L, "圆角"),
           "".join([radrow("面板", 26), radrow("卡片 · 预览块", 12), radrow("缩略图 · 色块", 10),
                    radrow("胶囊 · 搜索框", 8), radrow("角标", 9, 40), radrow("keycap", 6, 40)])))
F2["Tokens.dc.html"] = page("Tokens · 色 / 淡染 / 字号 / 圆角", 1760, 1000, body)

# ============================ Settings ============================
TILE = {
    "sync": (ACCENT, CLOUD_OK_I), "key": ("#5856D6", None), "hist": ("#FF9F0A", CLIP_I),
    "start": ("#34C759", None), "priv": ("#8E8E93", None), "about": ("#30B0C7", None),
    "danger": (DESTRUCT_L, TRASH_I),
}

def tile(color, inner=None, glyph=None):
    core = stroke(inner, onband(color), 15, 1.6) if inner else \
        ('<span style="font-family: %s; font-size: 13px; font-weight: 600; color: %s;">%s</span>' % (MONO, onband(color), glyph))
    return ('<span style="width: 26px; height: 26px; flex: none; border-radius: 7px; background: %s; display: flex; '
            'align-items: center; justify-content: center;">%s</span>' % (color, core))

def srow(th, tilehtml, label, value="", last=False, sub=""):
    border = "" if last else "border-bottom: 0.5px solid %s;" % th["sep"]
    subh = ('<div style="font-size: 10px; line-height: 14px; color: %s; margin-top: 1px;">%s</div>' % (th["ter"], sub)) if sub else ""
    val = ('<span style="font-size: 12px; color: %s;">%s</span>' % (th["meta"], value)) if value else ""
    return ('<div style="display: flex; align-items: center; gap: 10px; min-height: 40px; padding: 7px 12px; '
            'box-sizing: border-box; %s">%s<div style="flex-grow: 1; min-width: 0;">'
            '<div style="font-size: 13px; color: %s;">%s</div>%s</div>%s</div>'
            % (border, tilehtml, th["label"], label, subh, val))

def toggle(on=True):
    return ('<span style="width: 38px; height: 22px; flex: none; border-radius: 11px; background: %s; position: relative; '
            'display: inline-block;"><span style="position: absolute; top: 2px; %s width: 18px; height: 18px; '
            'border-radius: 9px; background: #FFFFFF; box-shadow: 0 1px 3px rgba(0,0,0,0.2);"></span></span>'
            % (SUCCESS_L if on else "rgba(118,118,128,0.24)", "left: 18px;" if on else "left: 2px;"))

def group(th, rows_html):
    return ('<div style="border-radius: 10px; overflow: hidden; background: %s; box-shadow: %s;">%s</div>'
            % (th["card"], th["cring"], rows_html))

def seg(items, active):
    out = []
    for i in items:
        on = i == active
        out.append('<button type="button" style="height: 24px; padding: 0 12px; border-radius: 6px; font-size: 12px; '
                   'font-weight: %s; background: %s; color: %s; box-shadow: %s;">%s</button>'
                   % ("600" if on else "400", L["card"] if on else "transparent", L["label"],
                      "0 1px 2px rgba(0,0,0,0.12)" if on else "none", i))
    return ('<div style="display: inline-flex; gap: 2px; padding: 3px; border-radius: 8px; background: %s;">%s</div>'
            % (L["fill"], "".join(out)))

def win(th, tab, content, w=540, h=460):
    bar = ('<div style="height: 38px; flex: none; box-sizing: border-box; padding: 0 14px; display: flex; align-items: center; '
           'gap: 12px; background: %s; border-bottom: 0.5px solid %s;">'
           '<div style="display: flex; gap: 8px;"><span style="width: 12px; height: 12px; border-radius: 6px; background: #FF5F57;"></span>'
           '<span style="width: 12px; height: 12px; border-radius: 6px; background: rgba(118,118,128,0.3);"></span>'
           '<span style="width: 12px; height: 12px; border-radius: 6px; background: rgba(118,118,128,0.3);"></span></div>'
           '<span style="flex-grow: 1; text-align: center; font-size: 13px; font-weight: 600; color: %s; margin-left: -56px;">设置</span></div>'
           % (th["glass"], th["sep"], th["label"]))
    tabs = ('<div style="padding: 12px 16px 4px; display: flex; justify-content: center;">%s</div>'
            % seg(["通用", "同步", "快捷键", "历史", "关于"], tab))
    return ('<div style="width: %dpx; height: %dpx; border-radius: 11px; overflow: hidden; display: flex; flex-direction: column; '
            'background: %s; box-shadow: 0 0 0 0.5px rgba(0,0,0,0.2), 0 24px 56px rgba(0,0,0,0.34);">%s%s'
            '<div style="flex-grow: 1; box-sizing: border-box; padding: 12px 16px 16px; display: flex; flex-direction: column; '
            'gap: 14px; overflow: hidden;">%s</div></div>' % (w, h, th["grouped"], bar, tabs, content))

gen_content = (h2(L, "启动") +
               group(L, srow(L, tile("#34C759", CHECK_I), "登录时启动 Copyo", "") + srow(L, tile("#8E8E93", GEAR_I), "在菜单栏显示图标", "", last=True)) +
               h2(L, "捕获") +
               group(L, srow(L, tile(ACCENT, CLIP_I), "自动记录剪贴板", sub="Copyo 在后台记录，不需要任何权限") +
                     srow(L, tile("#FF9F0A", None, "A"), "忽略密码管理器", sub="来自 1Password、钥匙串的内容不会被记录", last=True)) +
               note(L, "复制后 Copyo 把内容写回系统剪贴板并把焦点交还给原来的 App，由你自己按 ⌘V —— Copyo 从不代你粘贴。", 460))

key_rows = [("唤出面板", "⇧⌘V"), ("复制选中项", "↩"), ("纯文本复制", "⇧↩"), ("预览", "空格"),
            ("固定到 Pinboard", "⌘P"), ("删除", "⌘⌫"), ("聚焦搜索", "⌘F"), ("在筛选间循环", "⇥"),
            ("直接取第 N 张卡", "⌘1–9"), ("关闭面板", "esc")]
def keyrow(label, cap, last=False):
    border = "" if last else "border-bottom: 0.5px solid %s;" % L["sep"]
    return ('<div style="display: flex; align-items: center; gap: 10px; height: 34px; padding: 0 12px; box-sizing: border-box; %s">'
            '<span style="flex-grow: 1; font-size: 13px; color: %s;">%s</span>%s</div>'
            % (border, L["label"], label, keycap(cap, L)))

key_content = (h2(L, "唤出", "点一下可以改") +
               group(L, ('<div style="display: flex; align-items: center; gap: 10px; min-height: 44px; padding: 8px 12px; box-sizing: border-box;">'
                         '%s<span style="flex-grow: 1; font-size: 13px; color: %s;">唤出面板</span>'
                         '<button type="button" style="display: inline-flex; align-items: center; justify-content: center; min-width: 88px; '
                         'height: 26px; padding: 0 10px; border-radius: 7px; background: %s; box-shadow: 0 0 0 2px %s; font-family: %s; '
                         'font-size: 12px; font-weight: 500; color: %s;">⇧⌘V</button></div>'
                         % (tile("#5856D6", None, "⌘"), L["label"], L["card"], ACCENT, MONO, L["label"]))) +
               ('<div style="display: flex; align-items: center; gap: 6px; font-size: 11px; color: %s;">%s'
                '<span>这个组合已被另一个 App 占用，Copyo 收不到它</span></div>'
                % (DESTRUCT_L, stroke('<circle cx="8" cy="8" r="6.2"></circle><path d="M8 4.8v4M8 10.8v.4"></path>', DESTRUCT_L, 13, 1.6))) +
               h2(L, "面板内") +
               group(L, "".join(keyrow(a, b, i == len(key_rows) - 2) for i, (a, b) in enumerate(key_rows[1:]))))

body = ('<div style="width: 1240px; height: 600px; box-sizing: border-box; padding: 36px; background: %s; '
        'display: flex; gap: 40px; align-items: flex-start;">'
        '<div style="display: flex; flex-direction: column; gap: 10px;">%s%s</div>'
        '<div style="display: flex; flex-direction: column; gap: 10px;">%s%s</div></div>'
        % (L["desktop"],
           win(L, "通用", gen_content), note(dict(meta="rgba(255,255,255,0.7)"), "通用 · 540 × 460，结构不动，只换行样式与彩色图标砖", 540),
           win(L, "快捷键", key_content),
           note(dict(meta="rgba(255,255,255,0.7)"), "快捷键 · 商店截图 04 就是这一页；keycap 转为共享组件，并补上「快捷键被占用」这个今天完全不存在的失败态", 540)))
F2["Settings.dc.html"] = page("设置 · 换肤（通用 / 快捷键）", 1240, 600, body)

for name, text in F2.items():
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        f.write(text)
    print("wrote", name, len(text))
