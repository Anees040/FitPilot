# FitPilot UI Specification (UI_SPEC.md) — v1

> AUTHORITY: For anything visual, this file wins over every other doc except DOMAIN_RULES.md
> (domain math is never changed for visual reasons). Where an attached mockup image and this
> file disagree, THIS FILE WINS. Read docs/DESIGN_SYSTEM.md for brand rationale; read this
> file for exact build instructions.

---

## 0. Non-negotiables (check every screen against these)

1. Every calorie value is a RANGE with an en dash (– U+2013). The unit "kcal" appears exactly
   once per value. `KcalRange.format()` ALREADY includes " kcal" — never append the unit again.
2. No gradients. No glassmorphism. No blue. One accent color: orange. White space is the
   main design tool.
3. Errors are shown INLINE, next to their cause, with a specific reason and a retry/fix action.
   Snackbars are ONLY for confirmations of successful actions (3 s, floating, max one action: Undo).
4. Every list/data screen implements FOUR states: loading (skeleton), empty (illustration +
   one line + one action), error (specific reason + Retry button), content. A bare error
   string with no retry is a defect.
5. Touch targets >= 48x48 dp. Body text >= 14 sp. Contrast >= 4.5:1 in BOTH themes.
6. The app follows the SYSTEM theme (light/dark) via `themeMode: ThemeMode.system`, with a
   manual override in Profile > App > Appearance.
7. Clamp text scaling: `MediaQuery.textScaler` clamped to 0.85–1.15 at the app root.
8. Respect `MediaQuery.disableAnimations` (reduced motion): skip decorative animations.
9. Numbers that change on screen use tabular figures (`FontFeature.tabularFigures()`), so
   digits don't jitter.
10. No RenderFlex overflow banners at ANY size in section 6's test matrix. Ever.

---

## 1. Design tokens

### 1.1 Color — light theme
| Token | Hex | Use |
|---|---|---|
| bg | #FAFAF8 | Scaffold background |
| surface | #FFFFFF | Cards, sheets, nav bar |
| text | #1A1A1A | Primary text |
| textSecondary | #6B6862 | Captions, labels, meta |
| hairline | #E8E6E1 | Borders, dividers, tracks |
| accent | #D9531E | Primary buttons, active states, key numbers |
| accentSoft | #FBEDE6 | Selected chip bg, streak pill bg, icon circles |
| success | #3A7D44 | Compliant days, verified badges, "left" amounts |
| warning | #B7791F | Grace-window / pending states |
| error | #A63232 | Over amounts, destructive actions, error text |

### 1.2 Color — dark theme (new)
| Token | Hex | Use |
|---|---|---|
| bg | #151311 | Scaffold background (warm near-black, NOT pure black) |
| surface | #1F1C19 | Cards, sheets, nav bar |
| surfaceRaised | #262220 | Bottom sheets, dialogs |
| text | #EDEAE4 | Primary text |
| textSecondary | #A29D95 | Captions |
| hairline | #33302B | Borders |
| accent | #E8794A | Buttons, active states — the light accent #D9531E FAILS contrast on dark; never use it on dark surfaces |
| accentSoft | #3A251C | Selected/pill backgrounds |
| success | #7CB88A | Desaturated per Material dark guidance |
| warning | #D2A056 | |
| error | #D07C7C | |

Rules: desaturate all status colors on dark (saturated colors vibrate on dark backgrounds and
fail WCAG). White text on the dark accent button stays white. Elevation on dark = lighter
surface steps, not shadows.

### 1.3 Typography (Inter, bundled in assets/fonts)
| Role | Size/Weight | Use |
|---|---|---|
| display | 32 / w800 | The one hero number per screen (Eaten today range, streak count) |
| h1 | 24 / w700 | Screen titles |
| h2 | 18 / w600 | Section titles |
| bodyStrong | 15 / w600 | Row titles, values |
| body | 15 / w400 | Default text |
| caption | 13 / w400 | Meta, timestamps, helpers (textSecondary) |
| overline | 11 / w600, +1.2 letterspacing, UPPERCASE | Field labels inside inputs |

This REPLACES the old 40/22/17/15/13 scale. Nothing on a phone screen exceeds 32 except
nothing.

### 1.4 Shape, spacing, elevation
- Radii: cards 16, buttons/fields 14, chips 999 (full pill), bottom sheets 20 top corners.
- Spacing: strict 8-pt grid. Screen H-padding 16. Card padding 16. Gap between sections 24,
  between cards 12, inside cards 12.
- Elevation: NO drop shadows. 1 px hairline borders in light; surface-step lightening in dark.
- Buttons/fields height 52. List rows 56–64. Bottom nav 80. Top area uses large title, no 56px app bar on tab screens.

### 1.5 Motion
- Standard: 200 ms, Curves.easeOutCubic (state changes, chips, selections).
- Emphasized: 300 ms (sheet open/close, tab content switch — subtle fade+slide 8 dp).
- Number changes: AnimatedSwitcher, 150 ms fade + 4 dp slide-up.
- Nothing bounces. Nothing loops forever. Decorative motion is skipped under reduced motion.

---

## 2. Component library (build in lib/core/ui/, use EVERYWHERE — no one-off styles)

- **PrimaryButton**: 52 dp, accent bg, white 16/w600 label, radius 14. Pressed: 8% black overlay.
  Disabled: hairline bg + textSecondary label. Loading: 20 dp spinner replaces label, width unchanged,
  taps ignored (no double submit).
- **SecondaryButton**: 52 dp, surface bg, hairline border, text-colored label.
- **TertiaryButton**: text-only, textSecondary, 44 dp min height.
- **AppTextField**: 56 dp, surface fill, hairline border, focus border accent 1.5 px, overline label
  top-left inside, trailing icon slot. Error: 13 sp error-colored line BELOW the field. Never a red
  border without a message.
- **AppCard**: surface, radius 16, hairline border, padding 16.
- **SelectChip**: 40 dp, 14/w500. Selected: accent bg + white label. Unselected: surface + hairline.
  Use in Wrap, never in a fixed Row that can overflow.
- **AppBottomSheet**: drag handle 32x4, title h2, safe-area padded, top radius 20.
- **EmptyState**: line-art illustration 160 dp, one body line, one action button.
- **ErrorState**: icon + SPECIFIC reason text ("Couldn't read 2 saved foods") + Retry SecondaryButton.
- **SkeletonList**: 3 shimmer cards, 800 ms cycle.
- **confirmSnackbar(context, msg, {onUndo})**: the ONLY allowed snackbar entry point.

---

## 3. Bottom navigation

- Material 3 `NavigationBar`, 80 dp, 5 fixed destinations, labels always visible (12/w500):
  **Today** (flame), **Log** (search/list icon — NOT a plus; a plus icon implies an action,
  but this tab is a destination), **Plan** (calendar), **Progress** (bar chart), **Profile** (person).
- Active: filled icon variant, accent color, accentSoft pill indicator 64x32 that scales in
  0.8 -> 1.0 over 200 ms. Inactive: outlined variant, textSecondary.
- On select: icon scales 1.0 -> 1.15 -> 1.0 over 250 ms.
- Capture is NOT a tab: FAB on Today + scan icon inside the Log search field.
- Future features never add tabs: exercise library/planner/programs live under Plan;
  machine scanner/form check are Capture modes; all settings live under Profile.

---

## 4. Screen specs

### 4.1 Welcome (3 swipeable slides — matches mockup 1)
Top to bottom: logo 96 dp (radius 24) at ~12% height; "FitPilot" 32/w800; "Eat it. Burn it."
15 textSecondary; flexible hero illustration area (min 200 dp, house line-art style: thin
#1A1A1A outlines + single accent stroke); headline 28/w700 centered; support line 16
textSecondary, max 2 lines; page dots (active = 24x6 accent pill); PrimaryButton "Get started";
SecondaryButton "I already have an account"; TertiaryButton "Continue without an account".
Buttons persist on all slides.

| Slide | Headline | Support | Illustration |
|---|---|---|---|
| 1 | Honest calorie ranges | 350–520 kcal — because nobody really knows it's exactly 437. | Range slider with 350 / 520 handles (as in mockup) |
| 2 | Overeat? Burn it. | Go over and FitPilot gives you real options: a 34 min walk or 13 min of jump rope. | Line-art walking + jump-rope figures |
| 3 | Works offline. Free. | Log anywhere. Everything syncs when you're back online. | Line-art phone with checkmark |

### 4.2 Sign up / Log in (mockup 2, with 3 corrections)
REMOVED vs mockup: the "Join 10M+ users" line (invented social proof — never fake numbers),
the Google and Apple buttons, and the OR divider (out of scope; revisit post-launch).
Layout: back arrow; logo 40 dp centered; "Create your account" h1; subtitle "Free forever.
Your logs stay on your device."; full-width segmented control [Sign up | Log in] 48 dp
(thumb slides 200 ms); EMAIL field; PASSWORD field with visibility toggle; live requirement
checklist ("8+ characters", "Letters and digits") whose check circles turn success as satisfied;
PrimaryButton "Create account"; privacy card (lock icon: "Privacy first. Your logs stay on your
device. An account adds secure cloud backup."); terms footer 13.
Log in tab: email, password, right-aligned "Forgot password?" tertiary, PrimaryButton "Log in".
Errors: INLINE under the relevant field: "Email or password is incorrect." — never a snackbar,
never persistent. Button enters loading state during the request.

### 4.3 OTP + Forgot password
OTP: "Check your email" h1, six 48 dp digit boxes, auto-advance, paste support, resend tertiary
with 60 s countdown, inline error "That code didn't match. Try again."
Forgot: single email field + PrimaryButton "Send reset link"; success replaces the form with an
illustration + "Sent. Check your inbox."

### 4.4 Profile setup — 2 steps (mockup 3, with 2 fixes)
Header: back arrow, "1 of 2" caption, 2 dp accent linear progress.
Step 1 "About you": Body card (Weight kg + Height cm side by side, Age full width, Gender as a
WRAP CHIP ROW — Male / Female / Prefer not to say — the mockup's 3-segment control wraps badly
and is banned); Goal card (three 56 dp radio rows: Lose fat / Stay fit / Build muscle with icons;
selected = accentSoft bg + accent border); sticky PrimaryButton "Continue".
Step 2 "Allowance & gear": Cheat allowance card — "300 kcal" 24/w700, REAL Material Slider
0–1000 step 50 with visible track and thumb (the mockup's floating empty circle is a broken
render, not a design), helper "Eat this much extra without breaking your streak — as long as you
burn it."; Equipment card — Wrap chips Jump rope / Bicycle / Gym / Pool, helper "We only suggest
workouts you can actually do. Walking is always included."; sticky PrimaryButton "Start tracking".
Validation inline: weight 30–300, height 100–250, age 13–100. Numeric keyboards.

### 4.5 Today (mockup 4 — implement almost exactly)
Header: "Today" h1 + date caption; right: streak pill (accentSoft, flame + count) — HIDDEN when
streak is 0. Never render "0" anything as an achievement.
Card "Eaten today": label caption; range "1,240–1,510" display/tabular + "kcal" 16 textSecondary
baseline-aligned; 8 dp progress bar (within-limit portion accent, over portion error color, track
hairline); summary caption "Allowance 300 kcal · Burned 220 kcal · 180 over" with the "180 over"
span in error color — or "480 left" in success color when under.
Card "Burn it off" (ONLY when over): flame + title, "180 kcal over — pick one:", two option rows
(icon; name bodyStrong; "34 min · ≈3,500 steps" caption; outlined 36 dp "Done" pill), "See all
options →" tertiary to Plan. On Done: row fades out 200 ms, bar animates down, confirmSnackbar
"Nice — 220 kcal burned."
When under: single quiet line card "You're 480 kcal under. Keep it up." No confetti.
"Logged today" h2 + "3 items" caption; rows 64 dp: 40 dp accentSoft icon circle, name bodyStrong +
time caption, trailing range bodyStrong/tabular. Swipe-left delete with Undo snackbar. Tap opens
quantity sheet.
Empty state: plate line-art, "Nothing logged yet.", PrimaryButton "Log your first meal" -> Log.
FAB 56 dp accent scan icon -> Capture; hides on scroll down.

### 4.6 Log
Pinned search field (scan icon trailing -> Capture). Recent-foods chip row (last 6). Results list
rows: name, portion caption, range, 14 dp verified badge.
States: skeleton; ErrorState with the SPECIFIC cause + Retry ("Error loading foods" with no retry
is the exact defect being fixed in F1); empty search "No foods match 'xyz'" + "Add it manually".
Quantity sheet: food name title, portion caption, 44 dp stepper, live range (animated), PrimaryButton
"Add to today".

### 4.7 Plan
Top: purpose line "Your daily burn plan".
Over: kcal-over headline + full burn options list (icon, activity, minutes/steps, Done).
Under + goal=build: fork-icon card "You still need to eat 2,962 kcal to hit your target."
Nothing to do: EmptyState "Nothing to burn today. Enjoy it." with resting line-art figure.
Every number here MUST come from the same provider as Today — one source of truth.

### 4.8 Progress
Order: streak card (count display + phase line); 5-week heatmap 7x5 (12 dp squares, 4 dp gap):
green = compliant WITH logs, red = over-unresolved, hairline outline = NO DATA (never green);
legend row below. Weekly Summary card: Total Intake (range), Total Burned — NO "Planner
Adherence" row until Milestone C ships a planner. Recent Days rows: date; "X–Y kcal logged ·
Z kcal burned"; status icon ✅ compliant / ⚠ over / — (dash) no data. Weight trend: fl_chart
line + dashed goal line + "Log weight" button.

### 4.9 Profile (restructure into grouped settings — WhatsApp/Instagram pattern)
Header card: 64 dp avatar circle (initial), name/email or "Guest" + "Sign in to back up your
data" tertiary, one calm sync caption ("Synced just now" / "3 items waiting to sync").
Section **Your plan**: Daily target row "2,962 kcal" -> sheet explaining the TDEE math + override;
Cheat tolerance "300 kcal"; Goal.
Section **Your body**: Weight / Goal weight / Height / Age / Gender — 56 dp rows, label left,
value right, chevron -> edit sheet. Labels NEVER truncate ("Goal Wt (opt…" is banned; write
"Goal weight" and let rows wrap to 2 lines if needed).
Section **Equipment**: read-only chips + Edit.
Section **App**: Notifications, Appearance (System/Light/Dark), About.
Bottom: "Sign out" row in error color.
The target number shown here must equal the target shown on Plan; tolerance is listed separately,
never silently folded into a bigger "limit".

### 4.10 Capture
Keep the 4-mode pill; "Scan Food" shows a lock icon + "Coming in a later update". Barcode result
sheet adds provenance: product name + "Data from Open Food Facts". Torch state persists per
session. Any capture failure -> inline sheet with the reason + "Try again" — never a dead end.

---

## 5. Illustration house style
Thin dark-outline line-art figures (like the exercise card mockups), single accent-colored
stroke as emphasis, no fills, no faces detailed enough to imply identity. Used in: welcome
slides, all empty states. Store as SVG-derived PNGs in assets/illustrations/. Four pieces
minimum: range slider, walker+jump-roper, phone-with-check, empty plate.

---

## 6. Responsiveness test matrix (widget tests must pump ALL of these)
| Case | Size | textScaler |
|---|---|---|
| Small phone | 320 x 640 | 1.0 |
| Normal phone | 412 x 915 | 1.0 |
| Large text | 412 x 915 | 1.15 (clamped max) |
| Landscape | 915 x 412 | 1.0 |

Assertions: zero exceptions, zero overflow errors, all four screen states reachable on Today,
Log, Progress, Profile. Max content width 480 dp centered when width > 600.
