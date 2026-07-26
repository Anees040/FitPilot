# FitPilot — Design System & UI/UX Specification

## 1. Design Tokens & Color Palette

No other colors or styles exist. Hard bans: gradients, glows, glassmorphism, blue/purple accents, dark theme, drop shadows > 1dp.

### Colors
| Token | Hex | Use |
| --- | --- | --- |
| `bg` | #FAFAF8 | scaffold background |
| `surface` | #FFFFFF | cards, sheets, nav bar |
| `text` | #1A1A1A | primary text |
| `textSecondary` | #6B6862 | secondary text, inactive icons |
| `hairline` | #E8E6E1 | borders, dividers (1 px) |
| `accent` | #D9531E | THE only accent: buttons, active tab, links, focus |
| `success` | #3A7D44 | under limit, streak safe, completed burns |
| `warning` | #B7791F | near limit, low confidence indicator, grace running |
| `error` | #A63232 | over limit, destructive actions |

### Typography (Inter via google_fonts)
| Style | Size / Weight | Use |
| --- | --- | --- |
| `display` | 40 / 700 | big numbers (kcal range on Today) |
| `title` | 22 / 700 | screen titles |
| `body` | 17 / 400 | default text |
| `secondary` | 15 / 400 | list subtitles |
| `caption` | 13 / 500 | labels, chips |

## 2. Layout & Component Guidelines

- **Grid & Spacing:** 8-pt spacing grid (4-pt allowed for tight pairs); screen padding 16.
- **Elevation & Radius:** Flat + 1px hairline borders (`#E8E6E1`); Card radius 16px (or 12px); Chips radius 999px. No heavy drop shadows.
- **Bottom Nav Shell:** 80 px height, 5 tabs (Today · Log · Plan · Progress · Profile), active `#D9531E`, inactive `#6B6862`, top hairline border.
- **Top Bar:** 56 px, white background, title left-aligned (22/700), zero elevation.
- **Primary Button:** 52 px height, full width, `#D9531E`, radius 14, white text (17/600); disabled state = 40% opacity.
- **Secondary Button:** White background, hairline border, `#1A1A1A` text.
- **Input Fields:** 52 px height, white background, hairline border, radius 14; focus border `#D9531E`.
- **Honest Kcal Ranges:** Calories ALWAYS render as a range: e.g., "420–560 kcal", NEVER a single exact number.
- **Touch Targets:** Minimum touch target size ≥ 44×44 px (target 48 px).
- **One Primary Action:** Exactly one primary action per screen.

## 3. Screen Specifications & Flows

- **Log (Camera & Input):** Mode switch: Label · Meal · Text. Text mode: keyboard-first with recent/suggested chips.
- **Result Sheet:** Food name + portion (editable) → Range hero (`520–680 kcal`) with confidence bar → Follow-up chip question if confidence is low → Burn options cards (activity, minutes, MET).
- **Today Screen:** Date + streak flame → Net balance hero + burn-ring (owed vs completed) → Timeline of today's logs → Active burn plan card.
- **Progress Screen:** Streak count + longest streak → 7/30-day bar chart (monochrome + accent for today) → Burn receipts history list.
- **Profile & Settings:** User attributes, calorie allowance, equipment filter.
- **Onboarding (≤6 screens):** Welcome → Weight/Height → Sex/Age → Equipment chips → Goal → Personalized preview ("1 samosa ≈ 18 min brisk walk for you") → Sign-in last.

## 4. UI States & Copy Tone

- **Four Mandatory States:** Every screen must implement Empty, Loading (skeletons), Error (friendly/retry/offline-aware), and Success states.
- **Copy Tone:** Encouraging shopkeeper, not drill sergeant. Never guilt users ("Burn it when you're ready", not "You failed").

## 5. Non-Negotiable Design Constraints Block
```
[DESIGN CONSTRAINTS — NON-NEGOTIABLE]
Inter font via google_fonts. Background #FAFAF8, surfaces #FFFFFF, text #1A1A1A,
secondary #6B6862. Single accent #D9531E for primary actions/active states only;
#3A7D44 only for completed burns. NO gradients, NO glowing/drop shadows, NO blue or
purple, NO glassmorphism, NO confetti. Flat surfaces separated by 1px #E8E6E1
hairlines. 8pt spacing grid. 12px/16px corner radius. 44px minimum touch targets. One
primary action per screen. Big-number typography for kcal ranges and minutes. Calorie
values ALWAYS as ranges with a confidence bar, never one number. Include empty,
loading, error, and offline states.
```
