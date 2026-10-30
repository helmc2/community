"""
Applet: Baby Age
Summary: Show your baby's age
Description: Shows how old your baby is in hours, days, weeks, months or years, or counts down to the due date.
Author: helmc2
"""

load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

DEFAULT_NAME = "Baby"
DEFAULT_TIMEZONE = "America/Chicago"
DEFAULT_COLOR = "#7FD4FF"

# Shown until a birthdate is configured, so the preview always looks like a
# young baby rather than an ever-older fixed date.
DEFAULT_AGE = "1803h"  # 75 days, 3 hours

WIDTH = 64

UNITS = [
    ("auto", "Automatic"),
    ("hours", "Hours"),
    ("days", "Days"),
    ("weeks", "Weeks"),
    ("months", "Months"),
    ("years", "Years"),
]

def main(config):
    tz = config.get("$tz", DEFAULT_TIMEZONE)
    now = time.now().in_location(tz)

    name = config.str("name", "").strip() or DEFAULT_NAME
    color = config.str("color", DEFAULT_COLOR)
    unit = config.str("unit", "auto")
    show_detail = config.bool("detail", True)

    if config.get("birthdate"):
        birth = time.parse_time(config.get("birthdate")).in_location(tz)
    else:
        birth = now - time.parse_duration(DEFAULT_AGE)

    if birth > now:
        headline, detail = countdown(birth - now)
    else:
        headline, detail = age(birth, now, unit, tz)

    return render_display(name, color, headline, detail if show_detail else None)

def age(birth, now, unit, tz):
    """Returns (headline, detail) strings for a baby born at `birth`."""
    minutes = int((now - birth).minutes)
    hours = minutes // 60
    days = hours // 24
    weeks = days // 7
    months = months_between(birth, now, tz)
    years = months // 12

    if unit == "auto":
        if days < 1:
            unit = "hours"
        elif days <= 30:
            unit = "days"
        elif weeks <= 24:
            unit = "weeks"
        elif months < 24:
            unit = "months"
        else:
            unit = "years"

    count = {
        "hours": hours,
        "days": days,
        "weeks": weeks,
        "months": months,
        "years": years,
    }[unit]
    headline = plural(count, unit[:-1])

    # A finer-grained breakdown for the second line.
    if years > 0:
        detail = "%dy %dm" % (years, months % 12)
    elif months > 0:
        detail = "%dm %dd" % (months, int((now - add_months(birth, months, tz)).hours // 24))
    elif days >= 7:
        detail = "%dw %dd" % (weeks, days % 7)
    elif days > 0:
        detail = "%dd %dh" % (days, hours % 24)
    else:
        detail = "%dh %dm" % (hours, minutes % 60)

    return headline, detail

def countdown(remaining):
    """Returns (headline, detail) strings for a baby that isn't born yet."""
    days = int(remaining.hours // 24)
    if days < 1:
        return "Any time!", "until due date"
    if days <= 30:
        return plural(days, "day"), "until due date"
    return plural(days // 7, "week"), "until due date"

def months_between(start, end, tz):
    """Number of whole calendar months from start to end."""
    months = (end.year - start.year) * 12 + end.month - start.month
    if months > 0 and add_months(start, months, tz) > end:
        months -= 1
    return months

def add_months(t, n, tz):
    """Adds n calendar months to t, clamping to the end of shorter months."""
    total = t.month - 1 + n
    year = t.year + total // 12
    month = total % 12 + 1
    day = min(t.day, days_in_month(year, month))
    return time.time(
        year = year,
        month = month,
        day = day,
        hour = t.hour,
        minute = t.minute,
        location = tz,
    )

def days_in_month(year, month):
    if month == 2:
        leap = year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
        return 29 if leap else 28
    return 30 if month in (4, 6, 9, 11) else 31

def plural(n, word):
    return "%d %s%s" % (n, word, "" if n == 1 else "s")

def render_display(name, color, headline, detail):
    name_font = "tb-8" if detail else "6x13"
    children = [
        fit(render.Text(content = name, font = name_font, color = color)),
        fit(render.Text(content = headline, font = "6x13")),
    ]
    if detail:
        children.append(render.Text(content = detail, font = "tom-thumb", color = "#999"))

    return render.Root(
        delay = 80,
        child = render.Box(
            child = render.Column(
                expanded = True,
                main_align = "space_evenly",
                cross_align = "center",
                children = children,
            ),
        ),
    )

def fit(text):
    """Scrolls text that is too wide for the display."""
    if text.size()[0] <= WIDTH:
        return text
    return render.Marquee(width = WIDTH, child = text, offset_start = 8, offset_end = 8)

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "name",
                name = "Name",
                desc = "Your baby's name.",
                icon = "baby",
                default = DEFAULT_NAME,
            ),
            schema.DateTime(
                id = "birthdate",
                name = "Birthdate",
                desc = "Date and time of birth. Use a future date to count down to the due date.",
                icon = "cakeCandles",
            ),
            schema.Dropdown(
                id = "unit",
                name = "Show age in",
                desc = "Automatic shows hours, then days, weeks, months and years as your baby grows.",
                icon = "ruler",
                default = "auto",
                options = [schema.Option(display = d, value = v) for v, d in UNITS],
            ),
            schema.Toggle(
                id = "detail",
                name = "Show breakdown",
                desc = "Show a smaller line with the exact age, like 3m 12d.",
                icon = "listOl",
                default = True,
            ),
            schema.Color(
                id = "color",
                name = "Name color",
                desc = "Color of your baby's name.",
                icon = "brush",
                default = DEFAULT_COLOR,
                palette = ["#7FD4FF", "#FF9EC7", "#B8F28C", "#FFD166", "#C3A6FF"],
            ),
        ],
    )
