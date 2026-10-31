#!/usr/bin/env python3
"""Генератор иконок GenGram.

Один источник, три результата:
  design/icons/svg/*.svg             отдельные иконки
  design/icons/*.png                 листы для просмотра (нужен playwright)
  lib/gengram_icons.dart             код, которым иконки рисуются в приложении

Стиль: сетка 24x24, линия 1,7, скруглённые концы, основной цвет текста
и лавандовый акцент. Чтобы поменять иконку, правь её здесь и запусти скрипт:
    python3 tools/make_icons.py
"""
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'design', 'icons')
DART = os.path.join(ROOT, 'lib', 'gengram_icons.dart')

INK = '#E9E6FF'
ACCENT = '#A593FF'
STROKE = 1.7


# ---------- построитель путей (только M L H V C Q Z, абсолютные) ----------

def fmt(v):
    s = f'{v:.2f}'.rstrip('0').rstrip('.')
    return '0' if s in ('', '-0') else s


class P:
    def __init__(self):
        self.t = []

    def _add(self, cmd, *n):
        self.t.append(cmd + ' '.join(fmt(x) for x in n))
        return self

    def M(self, x, y): return self._add('M', x, y)
    def L(self, x, y): return self._add('L', x, y)
    def H(self, x): return self._add('H', x)
    def V(self, y): return self._add('V', y)
    def C(self, *n): return self._add('C', *n)
    def Q(self, *n): return self._add('Q', *n)

    def Z(self):
        self.t.append('Z')
        return self

    def __str__(self):
        return ' '.join(self.t)


def arc(p, cx, cy, r, a0, a1, move=True):
    """Дуга окружности кубическими кривыми. Углы в градусах, ось y вниз."""
    a0, a1 = math.radians(a0), math.radians(a1)
    n = max(1, math.ceil(abs(a1 - a0) / (math.pi / 2) - 1e-9))
    step = (a1 - a0) / n
    if move:
        p.M(cx + r * math.cos(a0), cy + r * math.sin(a0))
    for i in range(n):
        t0 = a0 + i * step
        t1 = t0 + step
        k = 4 / 3 * math.tan((t1 - t0) / 4)
        x3, y3 = cx + r * math.cos(t1), cy + r * math.sin(t1)
        x0, y0 = cx + r * math.cos(t0), cy + r * math.sin(t0)
        p.C(x0 - k * r * math.sin(t0), y0 + k * r * math.cos(t0),
            x3 + k * r * math.sin(t1), y3 - k * r * math.cos(t1), x3, y3)
    return p


def circle(cx, cy, r):
    return arc(P(), cx, cy, r, 0, 360).Z()


def ellipse(cx, cy, rx, ry):
    k = 0.5523
    return (P().M(cx + rx, cy)
            .C(cx + rx, cy + k * ry, cx + k * rx, cy + ry, cx, cy + ry)
            .C(cx - k * rx, cy + ry, cx - rx, cy + k * ry, cx - rx, cy)
            .C(cx - rx, cy - k * ry, cx - k * rx, cy - ry, cx, cy - ry)
            .C(cx + k * rx, cy - ry, cx + rx, cy - k * ry, cx + rx, cy).Z())


def rrect(x, y, w, h, r):
    k = 0.5523 * r
    return (P().M(x + r, y).H(x + w - r)
            .C(x + w - r + k, y, x + w, y + r - k, x + w, y + r).V(y + h - r)
            .C(x + w, y + h - r + k, x + w - r + k, y + h, x + w - r, y + h).H(x + r)
            .C(x + r - k, y + h, x, y + h - r + k, x, y + h - r).V(y + r)
            .C(x, y + r - k, x + r - k, y, x + r, y).Z())


def line(x1, y1, x2, y2):
    return P().M(x1, y1).L(x2, y2)


def poly(*pts, close=False):
    p = P().M(*pts[0])
    for pt in pts[1:]:
        p.L(*pt)
    return p.Z() if close else p


def sq(x, y, s):
    return poly((x, y), (x + s, y), (x + s, y + s), (x, y + s), close=True)


def crescent(c1, r1, c2, r2):
    """Контур месяца: внешняя дуга круга 1 и внутренняя дуга круга 2."""
    (x1, y1), (x2, y2) = c1, c2
    d = math.hypot(x2 - x1, y2 - y1)
    a = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
    h = math.sqrt(r1 * r1 - a * a)
    xm, ym = x1 + a * (x2 - x1) / d, y1 + a * (y2 - y1) / d
    pa = (xm + h * (y2 - y1) / d, ym - h * (x2 - x1) / d)
    pb = (xm - h * (y2 - y1) / d, ym + h * (x2 - x1) / d)

    def ang(c, p): return math.degrees(math.atan2(p[1] - c[1], p[0] - c[0]))

    def pick(c, r, a_from, a_to, want_inside_of, inside):
        """Выбрать направление дуги так, чтобы её середина была снаружи/внутри круга."""
        dpos = (a_to - a_from) % 360
        for delta in (dpos, dpos - 360):
            mid = math.radians(a_from + delta / 2)
            m = (c[0] + r * math.cos(mid), c[1] + r * math.sin(mid))
            dist = math.hypot(m[0] - want_inside_of[0][0], m[1] - want_inside_of[0][1])
            if (dist < want_inside_of[1]) == inside:
                return a_from + delta
        return a_to

    a1a, a1b = ang(c1, pa), ang(c1, pb)
    end1 = pick(c1, r1, a1a, a1b, (c2, r2), False)
    p = arc(P(), x1, y1, r1, a1a, end1)
    a2b, a2a = ang(c2, pb), ang(c2, pa)
    end2 = pick(c2, r2, a2b, a2a, (c1, r1), True)
    arc(p, x2, y2, r2, a2b, end2, move=False)
    return p.Z()


# ---------- набор иконок ----------

ICONS = {}


def add(name, label, *shapes):
    ICONS[name] = (label, list(shapes))


def S(p): return dict(d=str(p), accent=False, fill=False)    # линия
def A(p): return dict(d=str(p), accent=True, fill=False)     # линия-акцент
def F(p): return dict(d=str(p), accent=False, fill=True)     # заливка
def AF(p): return dict(d=str(p), accent=True, fill=True)     # заливка-акцент


GHOST_BODY = (P().M(5, 19.5).V(11).C(5, 7, 8, 4, 12, 4).C(16, 4, 19, 7, 19, 11)
              .V(19.5).Q(16.67, 23, 14.33, 19.5).Q(12, 23, 9.67, 19.5)
              .Q(7.33, 23, 5, 19.5).Z())
BUBBLE = (P().M(5, 4.5).H(19).Q(21, 4.5, 21, 6.5).V(14.5).Q(21, 16.5, 19, 16.5)
          .H(11).L(6.5, 20.5).V(16.5).H(5).Q(3, 16.5, 3, 14.5).V(6.5)
          .Q(3, 4.5, 5, 4.5).Z())
EYE_SHAPE = (P().M(2.5, 12).C(5, 7.5, 8.3, 5.5, 12, 5.5).C(15.7, 5.5, 19, 7.5, 21.5, 12)
             .C(19, 16.5, 15.7, 18.5, 12, 18.5).C(8.3, 18.5, 5, 16.5, 2.5, 12).Z())

add('ghost', 'Призрак', S(GHOST_BODY),
    AF(circle(9.5, 11, 1.2)), AF(circle(14.5, 11, 1.2)))
add('ghostVisible', 'Виден в сети', S(GHOST_BODY),
    F(circle(9.5, 11, 1.2)), F(circle(14.5, 11, 1.2)), AF(circle(19.6, 4.4, 2.1)))
add('eye', 'Глаз', S(EYE_SHAPE), A(circle(12, 12, 3)))
add('eyeOff', 'Глаз закрыт', S(EYE_SHAPE), A(circle(12, 12, 3)), S(line(4.5, 4.5, 19.5, 19.5)))
add('trash', 'Удалить',
    S(line(4, 7, 20, 7)), S(poly((9.5, 7), (9.5, 4.5), (14.5, 4.5), (14.5, 7))),
    S(P().M(6, 7).L(7, 19.5).Q(7.1, 21, 8.6, 21).H(15.4).Q(16.9, 21, 17, 19.5).L(18, 7)),
    A(line(10, 11, 10.3, 17)), A(line(14, 11, 13.7, 17)))
add('chat', 'Чат', S(BUBBLE),
    AF(circle(8.5, 10.5, 1.05)), AF(circle(12, 10.5, 1.05)), AF(circle(15.5, 10.5, 1.05)))
add('hiddenChat', 'Скрытый чат', S(BUBBLE),
    AF(circle(9, 10.3, 1.2)), AF(circle(15, 10.3, 1.2)))
add('lock', 'Закрыто', S(rrect(5, 10.5, 14, 10.5, 2.5)),
    S(P().M(8, 10.5).V(8).C(8, 5.8, 9.8, 4, 12, 4).C(14.2, 4, 16, 5.8, 16, 8).V(10.5)),
    AF(circle(12, 15, 1.3)), A(line(12, 16.2, 12, 18)))
add('unlock', 'Открыто', S(rrect(5, 10.5, 14, 10.5, 2.5)),
    S(P().M(8, 10.5).V(8).C(8, 5.8, 9.8, 4, 12, 4).C(14, 4, 15.6, 5.3, 15.9, 7.2)),
    AF(circle(12, 15, 1.3)), A(line(12, 16.2, 12, 18)))
add('translate', 'Перевод',
    S(poly((3.5, 18), (8.5, 6), (13.5, 18))), S(line(5.2, 14, 11.8, 14)),
    A(poly((14.8, 7.5), (20.5, 7.5))), A(poly((18, 5), (20.5, 7.5), (18, 10))),
    A(poly((20.5, 16.5), (15, 16.5))), A(poly((17.5, 14), (15, 16.5), (17.5, 19))))
add('globe', 'Язык', S(circle(12, 12, 8.5)), A(ellipse(12, 12, 3.8, 8.5)),
    S(line(3.5, 12, 20.5, 12)))
add('moon', 'Фон', S(crescent((12, 12), 8.5, (16.8, 8), 6.6)),
    AF(P().M(18.2, 4.4).L(19, 6.6).L(21.2, 7.4).L(19, 8.2).L(18.2, 10.4)
       .L(17.4, 8.2).L(15.2, 7.4).L(17.4, 6.6).Z()))


def _sliders():
    shapes = []
    rows = [(6, 9), (12, 15), (18, 8)]
    for y, kx in rows:
        if kx - 3.1 > 3.5:
            shapes.append(S(line(3.5, y, kx - 3.1, y)))
        shapes.append(S(line(kx + 3.1, y, 20.5, y)))
        shapes.append(A(circle(kx, y, 2.5)))
    return shapes


add('sliders', 'Настройки', *_sliders())
add('user', 'Человек', A(circle(12, 8, 3.6)),
    S(P().M(4.5, 20).C(4.5, 15.8, 7.8, 13.5, 12, 13.5).C(16.2, 13.5, 19.5, 15.8, 19.5, 20)))
add('group', 'Группа', A(circle(16.6, 8.5, 2.6)),
    A(P().M(16.8, 13.4).C(19.3, 13.7, 21, 15.5, 21, 18.5)),
    S(circle(9, 8.5, 3.2)),
    S(P().M(3, 20).C(3, 16.2, 5.6, 14, 9, 14).C(12.4, 14, 15, 16.2, 15, 20)))
add('channel', 'Канал',
    S(poly((4, 10), (4, 14), (7, 14), (15.5, 18.5), (15.5, 5.5), (7, 10), close=True)),
    S(line(7, 14, 8.4, 19.5)),
    A(arc(P(), 15.5, 12, 4.4, -42, 42)), A(arc(P(), 15.5, 12, 7.2, -36, 36)))
add('bot', 'Бот', S(rrect(4.5, 8.5, 15, 11, 3.5)), S(line(12, 8.5, 12, 5.2)),
    AF(circle(12, 3.9, 1.3)), AF(circle(9, 13.5, 1.3)), AF(circle(15, 13.5, 1.3)),
    S(line(9.5, 17, 14.5, 17)), S(line(2.5, 12.5, 2.5, 16)), S(line(21.5, 12.5, 21.5, 16)))
add('idBadge', 'ID', S(rrect(3, 5.5, 18, 13, 3)), A(line(8.2, 9.8, 8.2, 14.2)),
    A(P().M(11.2, 9.8).V(14.2).H(12.3).C(14.5, 14.2, 16.2, 13.3, 16.2, 12)
      .C(16.2, 10.7, 14.5, 9.8, 12.3, 9.8).Z()))
add('qr', 'QR-код',
    S(rrect(3.5, 3.5, 7, 7, 1.8)), S(rrect(13.5, 3.5, 7, 7, 1.8)), S(rrect(3.5, 13.5, 7, 7, 1.8)),
    AF(sq(5.9, 5.9, 2.2)), AF(sq(15.9, 5.9, 2.2)), AF(sq(5.9, 15.9, 2.2)),
    AF(sq(13.8, 13.8, 2.4)), AF(sq(18.1, 13.8, 2.4)), AF(sq(13.8, 18.1, 2.4)), AF(sq(18.1, 18.1, 2.4)))
add('copy', 'Копировать', S(rrect(8.5, 8.5, 12, 12, 2.5)),
    A(P().M(8.5, 15.5).H(6).Q(3.5, 15.5, 3.5, 13).V(6).Q(3.5, 3.5, 6, 3.5).H(13)
      .Q(15.5, 3.5, 15.5, 6).V(8.5)))
add('send', 'Отправить',
    S(poly((3.5, 11.2), (20.5, 3.8), (15.8, 20.2), (11.2, 13.2), close=True)),
    A(line(20.5, 3.8, 11.2, 13.2)))
add('check', 'Готово', A(poly((5, 12.5), (10, 17.5), (19.5, 7))))
add('doubleCheck', 'Прочитано', S(poly((2, 12.5), (6, 16.5), (14, 7.5))),
    A(poly((10.2, 15.8), (11.5, 17), (21.8, 7.5))))
add('checkCircle', 'Успех', S(circle(12, 12, 8.5)), A(poly((8, 12.3), (10.8, 15), (16.2, 9.2))))
add('timer', 'Таймер', S(circle(12, 13.5, 7.5)), S(line(10, 3.2, 14, 3.2)),
    S(line(12, 3.2, 12, 6)), A(line(12, 13.5, 12, 9.4)), AF(circle(12, 13.5, 1)))
add('refresh', 'Обновить', S(arc(P(), 12, 12, 7.5, -25, 235)), None)  # стрелка добавляется ниже
add('volume', 'Громкость',
    S(P().M(4, 9.5).H(7.5).L(12, 5.5).V(18.5).L(7.5, 14.5).H(4).Z()),
    A(arc(P(), 12, 12, 4.8, -42, 42)), A(arc(P(), 12, 12, 8, -38, 38)))
add('info', 'Профиль', S(circle(12, 12, 8.5)), AF(circle(12, 8.3, 1.05)), A(line(12, 11.4, 12, 16.4)))
add('search', 'Поиск', S(circle(10.5, 10.5, 6)), A(line(15, 15, 20.5, 20.5)))
add('chevron', 'Дальше', S(poly((9.5, 6), (15.5, 12), (9.5, 18))))
add('phone', 'Телефон', S(rrect(7, 3, 10, 18, 2.5)), A(line(10.5, 6, 13.5, 6)), AF(circle(12, 17.8, 0.95)))
add('mail', 'Почта', S(rrect(3, 5.5, 18, 13, 3)), A(poly((4, 7.5), (12, 13), (20, 7.5))))
add('alert', 'Ошибка', S(circle(12, 12, 8.5)), A(line(12, 7.7, 12, 12.6)), AF(circle(12, 15.9, 1.05)))
add('edit', 'Изменить',
    S(P().M(4, 20).L(4.8, 15.6).L(15.9, 4.5).Q(17.2, 3.2, 18.5, 4.5).L(19.5, 5.5)
      .Q(20.8, 6.8, 19.5, 8.1).L(8.4, 19.2).Z()),
    A(line(13.6, 6.8, 17.2, 10.4)))
add('menu', 'Меню', S(line(4, 7, 20, 7)), S(line(4, 12, 20, 12)), S(line(4, 17, 20, 17)))
add('back', 'Назад', S(line(19, 12, 5, 12)), S(poly((11, 6), (5, 12), (11, 18))))
add('close', 'Закрыть', S(line(6, 6, 18, 18)), S(line(18, 6, 6, 18)))
add('pin', 'Закрепить',
    S(poly((9, 4), (15, 4), (14.2, 10), (17, 14), (7, 14), (9.8, 10), close=True)),
    S(line(12, 14, 12, 21)))
add('muted', 'Без звука',
    S(P().M(6, 16).V(11).C(6, 7.7, 8.7, 5, 12, 5).C(15.3, 5, 18, 7.7, 18, 11).V(16).L(19.5, 17.5).H(4.5).Z()),
    S(P().M(10, 19.5).C(10.4, 20.5, 11.1, 21, 12, 21).C(12.9, 21, 13.6, 20.5, 14, 19.5)),
    A(line(4, 4, 20, 20)))
add('clock', 'Часы', S(circle(12, 12, 8.5)), A(poly((12, 7.5), (12, 12), (15, 14))))


def _star(cx, cy, ro, ri):
    pts = []
    for k in range(10):
        r = ro if k % 2 == 0 else ri
        a = math.radians(-90 + k * 36)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


add('star', 'Звезда', S(poly(*_star(12, 12.6, 9, 4), close=True)))
add('coin', 'Звёзды (монета)', S(circle(12, 12, 8.5)), AF(poly(*_star(12, 12.4, 4.6, 2.1), close=True)))
add('gift', 'Подарок',
    S(rrect(4, 10, 16, 10.5, 2)),
    S(rrect(3, 7, 18, 3.5, 1.2)),
    A(line(12, 7, 12, 20.5)),
    A(P().M(12, 7).C(10, 7, 7.5, 6.5, 7.5, 4.8).C(7.5, 3.4, 9.6, 3.2, 10.7, 4.3).C(11.4, 5, 12, 7, 12, 7).Z()),
    A(P().M(12, 7).C(14, 7, 16.5, 6.5, 16.5, 4.8).C(16.5, 3.4, 14.4, 3.2, 13.3, 4.3).C(12.6, 5, 12, 7, 12, 7).Z()))
add('plus', 'Плюс', S(line(12, 5, 12, 19)), S(line(5, 12, 19, 12)))
add('logout', 'Выйти',
    S(P().M(10, 4.5).H(6).C(4.9, 4.5, 4, 5.4, 4, 6.5).V(17.5).C(4, 18.6, 4.9, 19.5, 6, 19.5).H(10)),
    A(line(9, 12, 20, 12)),
    A(poly((16, 8), (20, 12), (16, 16))))

# стрелка у «Обновить»: считаем наконечник по касательной в конце дуги
_a = math.radians(235)
_tip = (12 + 7.5 * math.cos(_a), 12 + 7.5 * math.sin(_a))
_u = (-math.sin(_a), math.cos(_a))
_n = (-_u[1], _u[0])
_t = (_tip[0] + 0.8 * _u[0], _tip[1] + 0.8 * _u[1])
_b = (_t[0] - 3.3 * _u[0], _t[1] - 3.3 * _u[1])
ICONS['refresh'][1][1] = A(poly((_b[0] + 2.7 * _n[0], _b[1] + 2.7 * _n[1]), _t,
                                (_b[0] - 2.7 * _n[0], _b[1] - 2.7 * _n[1])))


# ---------- SVG ----------

def svg(name, size=24, ink=INK, accent=ACCENT):
    parts = []
    for s in ICONS[name][1]:
        col = accent if s['accent'] else ink
        if s['fill']:
            parts.append(f'<path d="{s["d"]}" fill="{col}"/>')
        else:
            parts.append(f'<path d="{s["d"]}" fill="none" stroke="{col}" stroke-width="{STROKE}" '
                         f'stroke-linecap="round" stroke-linejoin="round"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="{size}" '
            f'height="{size}">{"".join(parts)}</svg>')


# ---------- листы для просмотра ----------

CSS = """
*{box-sizing:border-box}
body{margin:0;background:linear-gradient(135deg,#241A5C 0%,#0F0B26 70%);color:#E9E6FF;
font-family:'DejaVu Sans','Segoe UI',system-ui,sans-serif;-webkit-font-smoothing:antialiased}
h1{margin:0;font-size:30px;letter-spacing:-.5px}
.sub{margin:6px 0 0;color:rgba(233,230,255,.68);font-size:15px}
"""


def sheet_html():
    cols = 7
    tiles = []
    for name, (label, _) in ICONS.items():
        tiles.append(f'<div class="t">{svg(name, 56)}<span>{label}</span></div>')
    return f"""<!doctype html><meta charset="utf-8"><style>{CSS}
.wrap{{width:1180px;padding:44px 44px 40px}}
.g{{display:grid;grid-template-columns:repeat({cols},1fr);gap:14px;margin-top:30px}}
.t{{background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.1);border-radius:18px;
height:132px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px}}
.t span{{font-size:13.5px;color:rgba(233,230,255,.8)}}
</style><div class="wrap"><h1>Иконки GenGram</h1>
<p class="sub">{len(ICONS)} иконок на сетке 24 пикселя: линия 1,7 и лавандовый акцент. Все нарисованы кодом.</p>
<div class="g">{''.join(tiles)}</div></div>"""


def in_app_html():
    rows = [
        ('ghost', 'Режим призрака', 'Другие не видят, что ты в сети'),
        ('lock', 'Скрытые чаты', 'Откроются жестом, закроются сами'),
        ('volume', 'Двойное нажатие громкости', 'Открывает и закрывает скрытые чаты'),
        ('timer', 'Сколько показывать', 'Закроются раньше, если свернуть окно'),
        ('trash', 'Сохранять удалённые', 'Копия с пометкой в красной рамке'),
        ('moon', 'Работать в фоне', 'Окно уходит в трей, а не закрывается'),
        ('translate', 'Автоперевод', 'Текст заменяется переводом'),
        ('globe', 'Переводить на', 'Русский'),
        ('idBadge', 'ID', '1234567890'),
    ]
    items = ''.join(
        f'<div class="r">{svg(n, 24)}<div><b>{t}</b><small>{s}</small></div></div>' for n, t, s in rows)
    bar = ''.join(f'<div class="b">{svg(n, 24)}</div>' for n in ('ghost', 'unlock', 'refresh', 'sliders'))
    field = lambda n, txt: f'<div class="f">{svg(n, 24)}<span>{txt}</span></div>'
    sizes = ''.join(f'<div class="z">{svg("ghost", s)}<small>{s}</small></div>' for s in (16, 20, 24, 32, 48))
    pairs = ''.join(f'<div class="z">{svg(n, 32)}</div>' for n in (
        'user', 'group', 'channel', 'bot', 'send', 'doubleCheck', 'copy', 'qr', 'search', 'chevron'))
    return f"""<!doctype html><meta charset="utf-8"><style>{CSS}
.wrap{{width:1000px;padding:44px;display:flex;gap:40px}}
.c{{width:440px;background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.1);border-radius:24px;overflow:hidden}}
.h{{padding:18px 20px;font-size:18px;font-weight:700;border-bottom:1px solid rgba(255,255,255,.08)}}
.r{{display:flex;gap:18px;align-items:center;padding:13px 20px}}
.r b{{display:block;font-weight:500;font-size:15.5px}}
.r small{{display:block;color:rgba(233,230,255,.6);font-size:12.5px;margin-top:2px}}
.col{{flex:1;display:flex;flex-direction:column;gap:26px}}
.lab{{font-size:13px;color:rgba(233,230,255,.6);margin-bottom:10px}}
.bar{{display:flex;align-items:center;background:#241A5C;border-radius:16px;padding:10px 14px;gap:6px}}
.bar .t{{font-weight:700;font-size:18px;flex:1}}.b{{padding:8px;display:flex}}
.f{{display:flex;gap:12px;align-items:center;background:rgba(255,255,255,.07);border-radius:16px;
padding:16px;margin-bottom:10px;color:rgba(233,230,255,.55);font-size:16px}}
.row{{display:flex;gap:22px;align-items:flex-end}}.z{{display:flex;flex-direction:column;align-items:center;gap:6px}}
.z small{{font-size:11px;color:rgba(233,230,255,.5)}}
</style><div class="wrap"><div class="c"><div class="h">Настройки GenGram</div>{items}</div>
<div class="col"><div><div class="lab">Верхняя панель списка чатов</div>
<div class="bar"><span class="t">GenGram</span>{bar}</div></div>
<div><div class="lab">Поля входа</div>{field('phone', '+375 29 123 45 67')}{field('mail', 'name@example.com')}
{field('lock', 'Пароль')}</div>
<div><div class="lab">Размеры: 16, 20, 24, 32, 48</div><div class="row">{sizes}</div></div>
<div><div class="lab">Остальные в размере 32</div><div class="row" style="flex-wrap:wrap">{pairs}</div></div></div></div>"""


# ---------- Dart ----------

def dart_code():
    names = list(ICONS)
    shapes = []
    for name in names:
        items = []
        for s in ICONS[name][1]:
            flags = ''.join([', accent: true' if s['accent'] else '', ', fill: true' if s['fill'] else ''])
            items.append(f"    _Shape('{s['d']}'{flags}),")
        shapes.append(f'  GIcon.{name}: [\n' + '\n'.join(items) + '\n  ],')
    return f"""// ЭТОТ ФАЙЛ СОЗДАЁТСЯ СКРИПТОМ tools/make_icons.py. Правь иконки там, а не здесь.
import 'package:flutter/material.dart';

/// Собственные иконки GenGram.
enum GIcon {{
  {', '.join(names)},
}}

/// Иконка GenGram: линия основного цвета и лавандовый акцент.
/// Цвет и размер берутся из ближайшего IconTheme, как у обычных иконок.
class GenIcon extends StatelessWidget {{
  const GenIcon(this.icon, {{super.key, this.size, this.color, this.accent}});

  final GIcon icon;
  final double? size;
  final Color? color;
  final Color? accent;

  @override
  Widget build(BuildContext context) {{
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24.0;
    return SizedBox.square(
      dimension: s,
      child: CustomPaint(
        painter: _IconPainter(
            icon, color ?? theme.color ?? Colors.white, accent ?? const Color(0xFFA593FF)),
      ),
    );
  }}
}}

class _Shape {{
  const _Shape(this.d, {{this.accent = false, this.fill = false}});
  final String d;
  final bool accent;
  final bool fill;
}}

class _IconPainter extends CustomPainter {{
  _IconPainter(this.icon, this.base, this.accent);

  final GIcon icon;
  final Color base;
  final Color accent;

  static final _cache = <String, Path>{{}};

  @override
  void paint(Canvas canvas, Size size) {{
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    for (final shape in _shapes[icon]!) {{
      final path = _cache.putIfAbsent(shape.d, () => _parse(shape.d));
      final paint = Paint()
        ..isAntiAlias = true
        ..color = shape.accent ? accent : base
        ..style = shape.fill ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = {STROKE}
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
    }}
    canvas.restore();
  }}

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.base != base || old.accent != accent;
}}

/// Разбирает путь из команд M L H V C Q Z (только большие буквы).
Path _parse(String d) {{
  final path = Path();
  final tokens = RegExp(r'[MLHVCQZ]|-?\\d*\\.?\\d+')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  var i = 0;
  var cmd = '';
  var x = 0.0, y = 0.0;
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {{
    final t = tokens[i];
    if (RegExp(r'[A-Z]').hasMatch(t)) {{
      cmd = t;
      i++;
      if (cmd == 'Z') {{
        path.close();
        continue;
      }}
    }}
    switch (cmd) {{
      case 'M':
        x = n();
        y = n();
        path.moveTo(x, y);
        cmd = 'L';
      case 'L':
        x = n();
        y = n();
        path.lineTo(x, y);
      case 'H':
        x = n();
        path.lineTo(x, y);
      case 'V':
        y = n();
        path.lineTo(x, y);
      case 'C':
        {{
          final x1 = n(), y1 = n(), x2 = n(), y2 = n();
          x = n();
          y = n();
          path.cubicTo(x1, y1, x2, y2, x, y);
        }}
      case 'Q':
        {{
          final x1 = n(), y1 = n();
          x = n();
          y = n();
          path.quadraticBezierTo(x1, y1, x, y);
        }}
      default:
        i++;
    }}
  }}
  return path;
}}

const _shapes = <GIcon, List<_Shape>>{{
{chr(10).join(shapes)}
}};
"""


def render_pngs(files):
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print('playwright не установлен: PNG-листы пропущены')
        return
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        for html_path, png_path, width in files:
            page = browser.new_page(viewport={'width': width, 'height': 600}, device_scale_factor=2)
            page.goto('file://' + html_path)
            page.screenshot(path=png_path, full_page=True)
            page.close()
        browser.close()


def main():
    os.makedirs(os.path.join(OUT, 'svg'), exist_ok=True)
    for name in ICONS:
        with open(os.path.join(OUT, 'svg', f'{name}.svg'), 'w', encoding='utf-8') as f:
            f.write(svg(name, 24))
    with open(DART, 'w', encoding='utf-8') as f:
        f.write(dart_code())
    sheet = os.path.join(OUT, 'sheet.html')
    inapp = os.path.join(OUT, 'in-app.html')
    open(sheet, 'w', encoding='utf-8').write(sheet_html())
    open(inapp, 'w', encoding='utf-8').write(in_app_html())
    render_pngs([(sheet, os.path.join(OUT, 'gengram-icons.png'), 1180),
                 (inapp, os.path.join(OUT, 'gengram-icons-in-app.png'), 1000)])
    print(f'иконок: {len(ICONS)}')


if __name__ == '__main__':
    sys.exit(main())
