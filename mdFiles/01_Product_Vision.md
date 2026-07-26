# FitPilot — Product Vision

> Version 1.0 — July 2026 · Owner: Muhammad Anees · Status: Approved

## 1. One-liner
FitPilot lets you log food by **label scan, photo, or plain text** ("2 samosay"), gives you an **honest calorie range** (never fake precision), and instantly converts it into a **personalized burn plan** ("35 min cycling or 20 min HIIT — based on YOUR weight"). Eat it. Burn it.

## 2. Problem
- Existing calorie apps (MyFitnessPal, Cal AI, Lose It!) fail on desi food: no roti/paratha/biryani portions, no Roman Urdu input.
- Photo-calorie apps fake precision ("597 kcal") when real accuracy is ±15–30%. Users learn to distrust them.
- No mainstream app answers the question users actually have after a cheat meal: **"what do I do about it NOW?"**
- Guilt-based streaks punish eating; nobody rewards *burning*.

## 3. Target user
Primary: gym-going students & young professionals in Pakistan/South Asia (18–30) who eat desi food, can't resist cheat meals, and own a mid-range Android phone.
Secondary (v2+): global users via English version.

## 4. Differentiators (the moat)
1. **Burn Converter** — deterministic MET-based conversion of any meal into personalized exercise options. No competitor leads with this.
2. **Honest-uncertainty UX** — ranges + confidence, one smart follow-up question when unsure.
3. **Desi food database** — curated portions for 250M+ South Asians whom global apps ignore.
4. **Label scan as hero feature** — on-device OCR, most accurate input mode, works offline, costs $0 to serve.
5. **Cheat-meal streak psychology** — you don't lose your streak by eating chips; you lose it by not burning them.

## 5. Future vision (post-MVP, do NOT build now)
- Gym machine scanner: photo of machine → identification, use case, correct technique, common mistakes.
- Form check: record exercise video → on-device pose estimation (MediaPipe BlazePose) → real-time technique feedback.
- Planner: weekly gym / outdoor / calisthenics routines, adjusted by logged food and completed burns.
- Watch/step integration; global English release.

## 6. Success metrics
- Week 10: live with 20 beta users, ≥10 logging 3+ days.
- Label-parse accuracy ≥ 75% on real Pakistani packaged foods.
- Crash-free sessions > 99%.
- Kill rule: < 50 active users (or zero engaged beta users) 6 weeks after launch → freeze, write post-mortem, move to next project.

## 7. Non-goals (MVP)
No social feed, no chat, no meal plans, no iOS build, no paid subscriptions, no custom-trained ML models, no wearables.
