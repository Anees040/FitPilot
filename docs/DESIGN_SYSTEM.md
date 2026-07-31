# FitPilot — Design System & UI/UX Specification

## 1. Design Tokens & Color Palette

Hard bans: gradients, glows, glassmorphism, blue/purple accents, drop shadows > 1dp.

### Colors — Light Theme
| Token | Hex | Use |
| --- | --- | --- |
| `bg` | #FAFAF8 | scaffold background |
| `surface` | #FFFFFF | cards, sheets, nav bar |
| `surfaceRaised` | #FFFFFF | bottom sheets, dialogs |
| `text` | #1A1A1A | primary text |
| `textSecondary` | #6B6862 | secondary text, inactive icons |
| `hairline` | #E8E6E1 | borders, dividers (1 px) |
| `accent` | #D9531E | THE only accent: buttons, active tab, links, focus |
| `accentSoft` | #FBEDE6 | selected chip bg, streak pill bg |
| `success` | #3A7D44 | under limit, streak safe, completed burns |
| `warning` | #B7791F | near limit, low confidence indicator, grace running |
| `error` | #A63232 | over limit, destructive actions |
| `highlight` | #D4A017 | streak flames, achievement moments (sparing use) |

### Colors — Dark Theme
| Token | Hex | Use |
| --- | --- | --- |
| `bg` | #121110 | scaffold background (warm near-black, NOT pure black) |
| `surface` | #1C1A18 | cards, sheets, nav bar |
| `surfaceRaised` | #272420 | bottom sheets, dialogs, snackbars, elevated cards |
| `text` | #F2EFE9 | primary text |
| `textSecondary` | #BDB6AA | captions, labels, meta |
| `hairline` | #3A362F | borders, dividers |
| `accent` | #F08A5A | buttons, active states (brighter than light accent for dark BG) |
| `accentSoft` | #42291D | selected/pill backgrounds |
| `success` | #7CC98B | desaturated per Material dark guidance |
| `warning` | #E8B24A | |
| `error` | #E5807D | |
| `highlight` | #E9C46A | streak flames, achievement moments (sparing use) |

**Dark theme rules:**
- Desaturate all status colors on dark (saturated colors vibrate on dark backgrounds and fail WCAG).
- White text on the dark accent button stays white.
- Elevation in dark = lighter surface steps (`surfaceRaised`), never black shadows.
- Selected chips/cards in dark: `accentSoft` fill + 1px `accent` border (not invisible solid accent fill).
- All text must pass WCAG AA: ≥ 4.5:1 body text, ≥ 3.0:1 large text. Verified by `dark_contrast_test.dart`.

### Typography (Inter via google_fonts)
| Style | Size / Weight | Use |
| --- | --- | --- |
| `display` | 32 / 700 | big numbers (kcal range on Today) |
| `title` | 20 / 700 | screen titles |
| `body` | 16 / 400 | default text |
| `secondary` | 14 / 400 | list subtitles |
| `caption` | 12 / 500 | labels, chips |

## 2. Layout & Component Guidelines

- **Grid & Spacing:** 8-pt spacing grid (4-pt allowed for tight pairs); screen padding 16.
- **Elevation & Radius:** Flat + 1px hairline borders; Card radius 16px (or 12px); Chips radius 999px. No heavy drop shadows. In dark: lighter surface steps replace shadows.
- **Bottom Nav Shell:** 80 px height, 5 tabs (Today · Log · Plan · Progress · Profile), active accent, inactive textSecondary, top hairline border.
- **Top Bar:** 56 px, bg background, title left-aligned (22/700), zero elevation.
- **Primary Button:** 52 px height, full width, accent bg, radius 14, white text (17/600); disabled state = 40% opacity.
- **Secondary Button:** Surface background, hairline border, text-colored text.
- **Input Fields:** 52 px height, surface background, hairline border, radius 14; focus border accent.
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

## 5. Illustrations
- **Style:** Minimalist, thin dark outline (#1A1A1A or equivalent on-surface) line-art on transparent backgrounds.
- **Accent:** A single accent stroke or small element in accent orange. No solid fills except for small dots or the accent path.
- **Adaptability:** Must be legible on dark surfaces. In dark mode, stroke colors adapt via theme (stroke = textSecondary, fill = accentSoft).
- **Usage:** One illustration per screen, max. Never competes with data. Replaces emptiness (Empty States).

## 6. Motion & Micro-interactions
- **Duration:** All animations must complete in under 400ms.
- **Accessibility:** Must fully respect the system's `reduce-motion` setting. If reduced motion is on, skip animations or use simple cross-fades.
- **Interactions:** Use brief, calm confirmations (e.g. snackbars 3.5 seconds) for routine actions like logging food. Use satisfying, short confirmations for rewards (e.g. marking a burn done).

## 7. Non-Negotiable Design Constraints Block
```
[DESIGN CONSTRAINTS — NON-NEGOTIABLE]
Inter font via google_fonts. Light: Background #FAFAF8, surfaces #FFFFFF, text #1A1A1A,
secondary #6B6862. Dark: Background #121110, surfaces #1C1A18, text #F2EFE9,
secondary #BDB6AA. Single accent #D9531E (light) / #F08A5A (dark) for primary
actions/active states only. #3A7D44/#7CC98B for completed burns. NO gradients,
NO glowing/drop shadows, NO blue or purple, NO glassmorphism, NO confetti. Flat
surfaces separated by 1px hairline borders. Dark elevation via lighter surface
steps, not shadows. 8pt spacing grid. 12px/16px corner radius. 44px minimum touch
targets. One primary action per screen. Big-number typography for kcal ranges and
minutes. Calorie values ALWAYS as ranges with a confidence bar, never one number.
Include empty, loading, error, and offline states. Minimalist line-art illustrations
only. Motion under 400ms. All text pairs pass WCAG AA contrast (4.5:1 body, 3:1 large).
```

