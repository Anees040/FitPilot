# FitPilot — UI/UX Specification

> Version 1.0 — July 2026 · Philosophy: **invisible UI**. One-handed, at the gym or mid-meal, one primary action per screen.

## 1. Market research — what top fitness apps do right (and what we steal)
| App | What works | What we take |
|---|---|---|
| MyFitnessPal | Instant dashboard of remaining calories; frictionless repeat logging | Big-number "net balance" hero on Today; recent-foods quick log |
| Cal AI | Camera-first: opens straight into capture; momentum-building onboarding that ends in a personalized preview | Log tab defaults to camera; short onboarding (≤6 steps) ending in "your first burn plan" preview — but NO paywall tricks |
| Google Fit | Heart Points ring — a single honest metric with satisfying progress | One burn-ring on Today (burn completed vs owed), flat colors, no confetti |
| Nike Training Club | Bold editorial typography, high-contrast, content-first cards | Type-led hierarchy instead of icon-heavy cards |
| Strava | Effort feels rewarded; clean data-dense summaries | "Burn receipt" summary after completing a plan (itemized: food → activity → minutes) |
| Whoop/Linear-style tools | Muted palettes, hairline dividers, tiny-but-legible secondary text | Overall visual language |
Anti-patterns to avoid (found across student/AI-generated apps): blue-purple gradients, glowing shadows, confetti, icon-in-circle card grids, fake precision numbers, 5-tab navs, paywall-first onboarding.

## 2. Design tokens (single source of truth — implement as Flutter ThemeExtension)
```
Background        #FAFAF8   (near-white, warm)
Surface           #FFFFFF
Text primary      #1A1A1A
Text secondary    #6B6862
Hairline/divider  #E8E6E1   (1px)
Accent (burn)     #D9531E   (burnt orange — primary actions, flame, active states ONLY)
Success (burned)  #3A7D44   (completed burns ONLY)
Warning           #B7791F   (low-confidence indicator)
Error             #A63232
Radius            12        Cards/buttons; 999 for chips
Spacing grid      8pt       (4 allowed for tight pairs)
Elevation         NONE      (flat + hairline borders; no drop shadows)
Font              System (Roboto). Numbers: w700. Display 32/38, Title 20/26, Body 17/24, Caption 13/18
Min touch target  44×44
```
Hard bans: gradients, glows, glassmorphism, blue/purple accents, emoji as icons, confetti, shadows > 1dp.

## 3. Navigation & screens
Bottom nav, 3 tabs: **Log** (center, default) · **Today** · **Progress**. Settings via avatar on Today.

### 3.1 Log (camera-first)
Full-bleed camera with mode switch: **Label · Meal · Text**. Shutter = accent. Text mode: keyboard-first with recent/suggested chips. After capture → Result sheet.

### 3.2 Result sheet (the signature moment)
- Food name + portion (editable)
- **Range as the hero:** `520–680 kcal` in Display type, thin horizontal confidence bar under it (green/amber), NEVER a single number
- If low confidence: ONE follow-up chip-question ("thin crust ya thick?")
- Below: **Burn options** — 3 flat cards: activity, minutes (Display type), tiny MET note. Tap → plan starts.
- Actions: `Log & burn later` (secondary) / card tap (primary)

### 3.3 Today
- Header: date + streak flame (orange only if alive)
- Hero: **net balance** big number + burn-ring (owed vs completed)
- Timeline of today's logs (row: name, range, burn status chip)
- Active burn plan card with `Mark done` / partial slider

### 3.4 Progress
- Streak count + longest; 7/30-day bar chart (thin bars, monochrome + accent for today); "burn receipts" history list

### 3.5 Onboarding (≤6 screens)
Welcome (one line, one button) → weight/height (big steppers) → sex/age → equipment chips → goal → **preview: "1 samosa ≈ 18 min brisk walk for you"** (personalized, instant value) → sign-in LAST (after value shown).

## 4. States (every screen ships all four)
Empty (helpful copy + single CTA) · Loading (skeletons, no spinners > 300ms) · Error (friendly, retry, offline-aware copy) · Success. Photo-quota-hit state explains and points to label scan ("scans are unlimited").

## 5. Copy tone
Encouraging shopkeeper, not drill sergeant. Roman Urdu allowed in follow-ups. Never guilt: "Burn it when you're ready" not "You failed".

## 6. The Antigravity design-constraints block (paste into EVERY UI prompt)
```
[DESIGN CONSTRAINTS — NON-NEGOTIABLE]
System fonts only (Roboto). Background #FAFAF8, surfaces #FFFFFF, text #1A1A1A,
secondary #6B6862. Single accent #D9531E for primary actions/active states only;
#3A7D44 only for completed burns. NO gradients, NO glowing/drop shadows, NO blue or
purple, NO glassmorphism, NO confetti. Flat surfaces separated by 1px #E8E6E1
hairlines. 8pt spacing grid. 12px corner radius. 44px minimum touch targets. One
primary action per screen. Big-number typography (32/w700) for kcal ranges and
minutes. Calorie values ALWAYS as ranges with a confidence bar, never one number.
Include empty, loading, error, and offline states. All components from the shared
design-token ThemeExtension in core/theme/ — never hardcode colors or spacing.
```
