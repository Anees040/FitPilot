# DESIGN SYSTEM — the only allowed UI values

## Colors (no others exist)

| Token | Hex | Use |
| --- | --- | --- |
| bg | #FAFAF8 | scaffold background |
| surface | #FFFFFF | cards, sheets, nav bar |
| text | #1A1A1A | primary text |
| textSecondary | #6B6862 | secondary text, inactive icons |
| hairline | #E8E6E1 | borders, dividers (1 px) |
| accent | #D9531E | THE only accent: buttons, active tab, links, focus |
| success | #3A7D44 | under limit, streak safe |
| warning | #B7791F | near limit, grace running |
| error | #A63232 | over limit, destructive |

Banned: blue, gradients, glassmorphism, shadows heavier than 8% opacity, dark theme.

## Type (Inter via google_fonts)

| Style | Size / weight | Use |
| --- | --- | --- |
| display | 40 / 700 | big numbers (kcal range on Today) |
| title | 22 / 700 | screen titles |
| body | 17 / 400 | default |
| secondary | 15 / 400 | list subtitles |
| caption | 13 / 500 | labels, chips |

## Layout & components

- 8-pt spacing grid; screen padding 16; cards: white, radius 16, 1 px hairline.
- Bottom nav: 80 px, 5 tabs (Today · Log · Plan · Progress · Profile),
  active #D9531E, inactive #6B6862, top hairline.
- Top bar: 56 px, white, title left-aligned (22/700), no elevation.
- Primary button: 52 px, full width, #D9531E, radius 14, white 17/600 text;
  disabled = 40% opacity. Secondary: white, hairline border, #1A1A1A text.
- Text fields: 52 px, white, hairline border, radius 14; focus border #D9531E.
- Calories ALWAYS render as a range: "420–560 kcal", never one number.
- Touch targets ≥ 48 px; one primary action per screen; empty states have a
  short friendly line + action, never a blank screen.
