"""Regenerates assets/seed/programs.json for FitPilot.

- Patches the dangling `air-squats` reference (deleted by DB migration 18).
- Backfills browse metadata on the 5 legacy programs (no "unknown" focus bucket).
- Appends the wave-1 goal programs.
- Verifies every referenced exercise id exists in exercises.json before writing.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path("D:/fitpilot")
SEED = ROOT / "assets" / "seed"

exercises = json.loads((SEED / "exercises.json").read_text(encoding="utf-8-sig"))
VALID = {e["id"] for e in exercises}
MET = {e["id"]: e["met"] for e in exercises}

# Written back without a BOM, matching the other three seed files.
programs = json.loads((SEED / "programs.json").read_text(encoding="utf-8-sig"))


# ---------------------------------------------------------------- legacy fixes
def patch_legacy(progs):
    for p in progs:
        for w in p.get("weeks", []):
            for s in w["sessions"]:
                if s.get("exercise_id") == "air-squats":
                    # Removed from the catalog in migration 18. Closest
                    # beginner bodyweight leg hold still in the library.
                    s["exercise_id"] = "wall-sit"


LEGACY_META = {
    "weight-loss-kickstart": dict(
        level="beginner", focus="weight_loss", equipment="minimal",
        days_per_week=4, hero_image="assets/illustrations/goal_lose_fat.png",
        sort_index=20),
    "daily-walk-challenge": dict(
        level="beginner", focus="cardio", equipment="none",
        days_per_week=5, hero_image="assets/illustrations/walker_rope.png",
        sort_index=30),
    "calisthenics-foundations": dict(
        level="intermediate", focus="full_body", equipment="minimal",
        days_per_week=4, hero_image="assets/illustrations/calisthenics_hero.png",
        sort_index=40),
    "home-hiit-burner": dict(
        level="intermediate", focus="cardio", equipment="minimal",
        days_per_week=3, hero_image="assets/illustrations/hiit_hero.png",
        sort_index=50),
    "gym-strength-basics": dict(
        level="intermediate", focus="strength", equipment="gym",
        days_per_week=4, hero_image="assets/illustrations/powerlifting_hero.png",
        sort_index=60),
}


def apply_meta(progs):
    for p in progs:
        meta = LEGACY_META.get(p["id"])
        if not meta:
            continue
        days = sum(len(w["sessions"]) for w in p["weeks"])
        ordered = {
            "id": p["id"], "name": p["name"], "icon": p["icon"],
            "goal": p["goal"], "level": meta["level"], "focus": meta["focus"],
            "equipment": meta["equipment"], "duration_days": days,
            "days_per_week": meta["days_per_week"],
            "hero_image": meta["hero_image"], "sort_index": meta["sort_index"],
            "weeks": p["weeks"],
        }
        p.clear()
        p.update(ordered)


# ------------------------------------------------------------------- builders
def mins(sets, work_s, rest_s=30):
    """Realistic wall-clock minutes for `sets` rounds of work + rest."""
    return max(2, round(sets * (work_s + rest_s) / 60))


def ex(eid, minutes, detail):
    assert eid in VALID, f"unknown exercise id: {eid}"
    return {"exercise_id": eid, "minutes": minutes, "detail": detail}


def rest(title, notes):
    return {"title": title, "kind": "rest", "notes": notes}


def workout(title, focus, notes, items):
    return {"title": title, "focus": focus, "notes": notes, "exercises": items}


def weeks_from(days, per_week=7):
    """Chunks a flat day list into 7-day weeks."""
    out = []
    for i in range(0, len(days), per_week):
        out.append({
            "week_number": i // per_week + 1,
            "sessions": days[i:i + per_week],
        })
    return out


# ------------------------------------------------------------- six-pack-30
# sets, plank hold s, crunch reps, leg-raise reps, mountain-climber s, cardio s
SIXPACK = {
    1: (3, 30, 15, 12, 30, 45),
    2: (3, 40, 18, 14, 40, 50),
    3: (4, 45, 20, 16, 45, 55),
    4: (4, 60, 22, 18, 50, 60),
    5: (4, 75, 25, 20, 60, 60),
}


def sixpack_days():
    days = []
    for week in range(1, 6):
        s, hold, cr, lr, mc, cardio = SIXPACK[week]
        wk = [
            workout(
                "Core Foundations", "Core",
                f"Week {week}: {s} rounds. Brace your abs and breathe — never hold your breath.",
                [
                    ex("plank", mins(s, hold), f"{s} × {hold} s hold"),
                    ex("crunches", mins(s, cr * 3), f"{s} × {cr} reps"),
                    ex("glute-bridge", mins(s, cr * 3), f"{s} × {cr} reps"),
                    ex("superman-hold", mins(s, 20), f"{s} × 20 s hold"),
                ]),
            workout(
                "Core + Cardio", "Core • Cardio",
                f"Week {week}: keep rest under 30 s to hold your heart rate up.",
                [
                    ex("jumping-jacks", mins(s, cardio), f"{s} × {cardio} s"),
                    ex("mountain-climbers", mins(s, mc), f"{s} × {mc} s"),
                    ex("crunches", mins(s, cr * 3), f"{s} × {cr} reps"),
                    ex("plank", mins(max(2, s - 1), hold), f"{max(2, s - 1)} × {hold} s hold"),
                ]),
            rest("Rest day",
                 "Recovery is when the core actually rebuilds. An easy walk is fine."),
            workout(
                "Lower Abs", "Lower core",
                f"Week {week}: press your lower back into the floor on every leg raise.",
                [
                    ex("leg-raises", mins(s, lr * 4), f"{s} × {lr} reps"),
                    ex("glute-bridge", mins(s, cr * 3), f"{s} × {cr} reps"),
                    ex("plank", mins(s, hold), f"{s} × {hold} s hold"),
                    ex("wall-sit", mins(max(2, s - 1), hold), f"{max(2, s - 1)} × {hold} s hold"),
                ]),
            workout(
                "Obliques & Burn", "Obliques • Conditioning",
                f"Week {week}: rotate through as a circuit, {s} rounds total.",
                [
                    ex("mountain-climbers", mins(s, mc + 10), f"{s} × {mc + 10} s"),
                    ex("bear-crawl", mins(s, 30), f"{s} × 30 s"),
                    ex("crunches", mins(s, cr * 3), f"{s} × {cr} reps"),
                    ex("high-knees", mins(s, cardio), f"{s} × {cardio} s"),
                ]),
            rest("Rest day",
                 "Sleep and food do the building. Keep logging meals — that is what uncovers the work."),
            workout(
                "Core Finisher", "Core • Cardio",
                f"Week {week}: last core session of the week — go for quality holds, then walk it off.",
                [
                    ex("plank", mins(s, hold + 10), f"{s} × {hold + 10} s hold"),
                    ex("leg-raises", mins(s, lr * 4), f"{s} × {lr} reps"),
                    ex("crunches", mins(s, cr * 3), f"{s} × {cr} reps"),
                    ex("brisk-walking", 15, "15 min easy cooldown walk"),
                ]),
        ]
        days.extend(wk if week < 5 else wk[:2])
    return days


SIXPACK_PROGRAM = {
    "id": "six-pack-30",
    "name": "Six-Pack in 30 Days",
    "icon": "🔥",
    "goal": (
        "30 days of focused core training — planks, crunch and leg-raise "
        "progressions, plus short cardio finishers. Straight talk: you cannot "
        "spot-reduce fat, and 30 days of core work alone will not reveal abs. "
        "This builds the muscle and burns real calories; the deficit from your "
        "food log is what uncovers it."
    ),
    "level": "beginner",
    "focus": "core",
    "equipment": "none",
    "duration_days": 30,
    "days_per_week": 5,
    "hero_image": "assets/illustrations/core_hero.png",
    "sort_index": 1,
    "weeks": weeks_from(sixpack_days()),
}

# ------------------------------------------------------------ full-body-30
# sets, push reps, pull reps, leg reps, hold s, circuit s
FULLBODY = {
    1: (3, 8, 5, 12, 30, 40),
    2: (3, 10, 6, 14, 40, 45),
    3: (4, 12, 7, 16, 45, 50),
    4: (4, 14, 8, 18, 50, 55),
    5: (4, 15, 9, 20, 60, 60),
}


def fullbody_days():
    days = []
    for week in range(1, 6):
        s, push, pull, leg, hold, circ = FULLBODY[week]
        wk = [
            workout(
                "Push Day", "Chest • Shoulders • Triceps",
                f"Week {week}: full range beats extra reps. Drop to knees on push-ups if form slips.",
                [
                    ex("pushup-vigorous", mins(s, push * 3), f"{s} × {push} reps"),
                    ex("dips", mins(s, push * 3), f"{s} × {max(5, push - 2)} reps"),
                    ex("plank", mins(s, hold), f"{s} × {hold} s hold"),
                    ex("shadow-boxing", mins(s, circ), f"{s} × {circ} s"),
                ]),
            workout(
                "Pull Day", "Back • Biceps",
                f"Week {week}: no bar? Swap pull-ups for the resistance band row in the notes.",
                [
                    ex("pullup", mins(s, pull * 4), f"{s} × {pull} reps (or band rows)"),
                    ex("chinup", mins(s, pull * 4), f"{s} × {max(3, pull - 1)} reps"),
                    ex("superman-hold", mins(s, 20), f"{s} × 20 s hold"),
                    ex("resistance-band-circuit", mins(s, circ), f"{s} × {circ} s"),
                ]),
            rest("Rest day", "Muscle grows on rest days. Walk, stretch, sleep."),
            workout(
                "Leg Day", "Quads • Glutes • Hamstrings",
                f"Week {week}: control the descent — 2 s down, drive up.",
                [
                    ex("walking-lunges", mins(s, leg * 4), f"{s} × {leg} reps per leg"),
                    ex("step-ups", mins(s, leg * 3), f"{s} × {leg} reps per leg"),
                    ex("wall-sit", mins(s, hold), f"{s} × {hold} s hold"),
                    ex("glute-bridge", mins(s, leg * 3), f"{s} × {leg} reps"),
                ]),
            workout(
                "Core & Conditioning", "Core • Cardio",
                f"Week {week}: circuit style, {s} rounds, 30 s rest between rounds.",
                [
                    ex("mountain-climbers", mins(s, circ), f"{s} × {circ} s"),
                    ex("leg-raises", mins(s, leg * 3), f"{s} × {max(10, leg - 2)} reps"),
                    ex("crunches", mins(s, leg * 3), f"{s} × {leg} reps"),
                    ex("jumping-jacks", mins(s, circ), f"{s} × {circ} s"),
                ]),
            rest("Rest day", "Second rest day — take it. Log your meals."),
            workout(
                "Full Body Circuit", "Full body",
                f"Week {week}: one round is all four moves back to back. {s} rounds.",
                [
                    ex("burpees", mins(s, circ), f"{s} × {circ} s"),
                    ex("squat-jumps", mins(s, circ - 10), f"{s} × {circ - 10} s"),
                    ex("pushup-vigorous", mins(s, push * 3), f"{s} × {push} reps"),
                    ex("bear-crawl", mins(s, 30), f"{s} × 30 s"),
                ]),
        ]
        days.extend(wk if week < 5 else wk[:2])
    return days


FULLBODY_PROGRAM = {
    "id": "full-body-30",
    "name": "30-Day Full Body",
    "icon": "💪",
    "goal": (
        "A 30-day push / pull / legs / core rotation built from calisthenics "
        "and bodyweight basics. Five training days and two rest days a week, "
        "with reps climbing each week. A pull-up bar or resistance band helps "
        "on pull days — every other session needs nothing."
    ),
    "level": "beginner",
    "focus": "full_body",
    "equipment": "minimal",
    "duration_days": 30,
    "days_per_week": 5,
    "hero_image": "assets/illustrations/athletic_hero.png",
    "sort_index": 2,
    "weeks": weeks_from(fullbody_days()),
}

# --------------------------------------------------- strength-conditioning-28
# sets, main reps, accessory reps, conditioning min
STRENGTH = {
    1: (3, 8, 12, 12),
    2: (4, 8, 12, 15),
    3: (4, 6, 10, 18),
    4: (5, 5, 10, 20),
}


def strength_days():
    days = []
    for week in range(1, 5):
        s, main, acc, cond = STRENGTH[week]
        days.extend([
            workout(
                "Lower Strength", "Quads • Glutes • Posterior chain",
                f"Week {week}: {s} working sets of {main}. Add weight only when all sets are clean.",
                [
                    ex("barbell-squat", mins(s, main * 5, 90), f"{s} × {main} reps"),
                    ex("leg-press", mins(s, acc * 4, 60), f"{s} × {acc} reps"),
                    ex("dumbbell-walking-lunges", mins(s, acc * 4, 60), f"{s} × {acc} reps per leg"),
                    ex("farmers-carry", mins(s, 45, 60), f"{s} × 45 s carry"),
                ]),
            workout(
                "Conditioning", "Cardio • Engine",
                f"Week {week}: steady effort — you should be able to speak in short sentences.",
                [
                    ex("rowing-vigorous", cond, f"{cond} min steady"),
                    ex("jump-rope-moderate", max(5, cond - 5), f"{max(5, cond - 5)} min, break as needed"),
                    ex("mountain-climbers", mins(s, 40), f"{s} × 40 s"),
                ]),
            rest("Rest day", "Heavy weeks need real rest. Walk and hydrate."),
            workout(
                "Upper Strength", "Chest • Back • Shoulders",
                f"Week {week}: {s} working sets of {main}. Keep 1–2 reps in reserve.",
                [
                    ex("bench-press", mins(s, main * 5, 90), f"{s} × {main} reps"),
                    ex("barbell-row", mins(s, main * 5, 75), f"{s} × {main} reps"),
                    ex("overhead-press", mins(s, acc * 4, 75), f"{s} × {max(6, main)} reps"),
                    ex("lat-pulldown", mins(s, acc * 4, 60), f"{s} × {acc} reps"),
                ]),
            workout(
                "HIIT Conditioning", "Full body • Power",
                f"Week {week}: {s} hard rounds, full recovery between them.",
                [
                    ex("kettlebell-swings", mins(s, 40, 45), f"{s} × 40 s"),
                    ex("dumbbell-hiit", mins(s, 45, 45), f"{s} × 45 s circuit"),
                    ex("stationary-bike-vigorous", max(8, cond - 4), f"{max(8, cond - 4)} min intervals"),
                ]),
            rest("Rest day", "Second rest day. Eat enough — strength needs fuel."),
            workout(
                "Full Body Power", "Posterior chain • Power",
                f"Week {week}: technique first on every rep. Stop the set when speed drops.",
                [
                    ex("deadlift", mins(s, main * 6, 120), f"{s} × {main} reps"),
                    ex("clean-and-press", mins(s, main * 5, 90), f"{s} × {max(4, main - 2)} reps"),
                    ex("farmers-carry", mins(s, 45, 60), f"{s} × 45 s carry"),
                    ex("stair-climber", max(8, cond - 6), f"{max(8, cond - 6)} min finisher"),
                ]),
        ])
    return days


STRENGTH_PROGRAM = {
    "id": "strength-conditioning-28",
    "name": "Strength & Conditioning",
    "icon": "🏋️",
    "goal": (
        "Four weeks alternating heavy compound lifts with conditioning work. "
        "Squat, bench, deadlift and press carry the strength days; rowing, "
        "kettlebells and bike intervals build the engine. Needs gym access."
    ),
    "level": "intermediate",
    "focus": "strength",
    "equipment": "gym",
    "duration_days": 28,
    "days_per_week": 5,
    "hero_image": "assets/illustrations/powerlifting_hero.png",
    "sort_index": 3,
    "weeks": weeks_from(strength_days()),
}


# -------------------------------------------------------------- lower-body-28
# sets, lunge reps, step reps, hold s, hop s
LOWER = {
    1: (3, 10, 10, 30, 30),
    2: (3, 12, 12, 40, 35),
    3: (4, 14, 14, 45, 40),
    4: (4, 16, 16, 60, 45),
}

GYM_SWAP = "Gym option: swap for leg-press at the same reps."
SQUAT_SWAP = "Gym option: swap for barbell-squat, 4 × 8."


def lower_days():
    days = []
    for week in range(1, 5):
        s, lunge, step, hold, hop = LOWER[week]
        # Pistol squats only appear once the base weeks are done.
        advanced = week >= 3
        days.extend([
            workout(
                "Quads & Glutes", "Quads • Glutes",
                f"Week {week}: 2 s down, drive up. {SQUAT_SWAP}",
                [
                    ex("walking-lunges", mins(s, lunge * 4), f"{s} × {lunge} reps per leg"),
                    ex("wall-sit", mins(s, hold), f"{s} × {hold} s hold"),
                    ex("glute-bridge", mins(s, step * 3), f"{s} × {step} reps"),
                    ex("step-ups", mins(s, step * 3), f"{s} × {step} reps per leg"),
                ]),
            workout(
                "Power & Balance", "Glutes • Hamstrings • Balance",
                f"Week {week}: land soft on every hop — knees track over toes."
                + (" Pistol progression starts today: hold a doorframe and go only as low as you control."
                   if advanced else ""),
                [
                    ex("skater-hops", mins(s, hop), f"{s} × {hop} s"),
                    *([ex("pistol-squat", mins(s, 30, 45), f"{s} × 3–5 assisted reps per leg")]
                      if advanced else
                      [ex("step-ups", mins(s, step * 3), f"{s} × {step} reps per leg")]),
                    ex("glute-bridge", mins(s, step * 3), f"{s} × {step + 2} reps"),
                    ex("wall-sit", mins(max(2, s - 1), hold), f"{max(2, s - 1)} × {hold} s hold"),
                ]),
            rest("Rest day", "Legs rebuild on rest days. Keep walking, skip the stairs sprint."),
            workout(
                "Strength Ladder", "Quads • Glutes",
                f"Week {week}: descending ladder — {lunge}, {lunge - 2}, {lunge - 4} reps. {GYM_SWAP}",
                [
                    ex("step-ups", mins(s, step * 4), f"{s} × {step} reps per leg"),
                    ex("walking-lunges", mins(s, lunge * 4), f"{s} × {lunge} reps per leg"),
                    ex("wall-sit", mins(s, hold + 10), f"{s} × {hold + 10} s hold"),
                    ex("superman-hold", mins(s, 20), f"{s} × 20 s hold"),
                ]),
            workout(
                "Conditioning Legs", "Legs • Cardio",
                f"Week {week}: circuit, {s} rounds, 45 s rest between rounds.",
                [
                    ex("skater-hops", mins(s, hop), f"{s} × {hop} s"),
                    ex("squat-jumps", mins(s, hop - 10), f"{s} × {hop - 10} s"),
                    ex("walking-lunges", mins(s, lunge * 3), f"{s} × {lunge - 2} reps per leg"),
                    ex("incline-walking", 12, "12 min uphill finisher"),
                ]),
            rest("Rest day", "Second rest day. Sore is fine, sharp pain is not."),
            workout(
                "Glute Focus", "Glutes • Hamstrings",
                f"Week {week}: squeeze at the top of every bridge for a full second. {GYM_SWAP}",
                [
                    ex("glute-bridge", mins(s, step * 4), f"{s} × {step + 4} reps"),
                    ex("step-ups", mins(s, step * 4), f"{s} × {step + 2} reps per leg"),
                    ex("wall-sit", mins(s, hold), f"{s} × {hold} s hold"),
                    ex("brisk-walking", 15, "15 min easy cooldown walk"),
                ]),
        ])
    return days


LOWER_PROGRAM = {
    "id": "lower-body-28",
    "name": "28-Day Lower Body Challenge",
    "icon": "🦵",
    "goal": (
        "Four weeks of lunges, step-ups, wall sits, bridges and skater hops to "
        "build stronger legs and glutes at home. Weeks 3 and 4 add assisted "
        "pistol-squat progressions. Session notes list gym swaps (leg press, "
        "barbell squat) if you train in a gym."
    ),
    "level": "beginner",
    "focus": "lower_body",
    "equipment": "none",
    "duration_days": 28,
    "days_per_week": 5,
    "hero_image": "assets/illustrations/lower_body_hero.png",
    "sort_index": 4,
    "weeks": weeks_from(lower_days()),
}

# -------------------------------------------------------------- belly-burn-14
BELLY = {1: (3, 30, 30, 15), 2: (4, 40, 40, 20)}


def belly_days():
    days = []
    for week in range(1, 3):
        s, hiit, hold, reps = BELLY[week]
        days.extend([
            workout(
                "HIIT + Core", "Full body • Core",
                f"Week {week}: {s} rounds. Go hard on the intervals, then hold the core work strict.",
                [
                    ex("burpees", mins(s, hiit), f"{s} × {hiit} s"),
                    ex("mountain-climbers", mins(s, hiit), f"{s} × {hiit} s"),
                    ex("plank", mins(s, hold), f"{s} × {hold} s hold"),
                    ex("crunches", mins(s, reps * 3), f"{s} × {reps} reps"),
                ]),
            workout(
                "Rope & Abs", "Cardio • Core",
                f"Week {week}: break the rope work into {s} blocks if you need to.",
                [
                    ex("jump-rope-fast", mins(s, 60, 45), f"{s} × 60 s"),
                    ex("high-knees", mins(s, hiit), f"{s} × {hiit} s"),
                    ex("leg-raises", mins(s, reps * 4), f"{s} × {reps} reps"),
                    ex("plank", mins(s, hold), f"{s} × {hold} s hold"),
                ]),
            rest("Rest day", "Hard intervals need recovery. Walk, hydrate, log your meals."),
            workout(
                "Stairs & Core", "Cardio • Core",
                f"Week {week}: stairs at a hard but repeatable pace, {s} rounds.",
                [
                    ex("home-stair-climbing", mins(s, 60, 45), f"{s} × 60 s"),
                    ex("squat-jumps", mins(s, hiit - 10), f"{s} × {hiit - 10} s"),
                    ex("crunches", mins(s, reps * 3), f"{s} × {reps + 3} reps"),
                    ex("superman-hold", mins(s, 20), f"{s} × 20 s hold"),
                ]),
            workout(
                "Sprint Intervals", "Cardio • Legs",
                f"Week {week}: {s} hard efforts with full recovery. No open ground? Use stairs.",
                [
                    ex("sprint-intervals", mins(s, 30, 90), f"{s} × 30 s sprint, 90 s walk"),
                    ex("mountain-climbers", mins(s, hiit), f"{s} × {hiit} s"),
                    ex("leg-raises", mins(s, reps * 4), f"{s} × {reps} reps"),
                ]),
            rest("Rest day", "Second rest day. The food log does the deficit work today."),
            workout(
                "Full Burn Finisher", "Full body • Core",
                f"Week {week}: last push of the week — {s} rounds, then walk it off.",
                [
                    ex("burpees", mins(s, hiit + 10), f"{s} × {hiit + 10} s"),
                    ex("jump-rope-fast", mins(s, 60, 45), f"{s} × 60 s"),
                    ex("plank", mins(s, hold + 10), f"{s} × {hold + 10} s hold"),
                    ex("brisk-walking", 15, "15 min cooldown walk"),
                ]),
        ])
    return days


BELLY_PROGRAM = {
    "id": "belly-burn-14",
    "name": "14-Day Belly Burn",
    "icon": "⚡",
    "goal": (
        "Two weeks of high-intensity intervals paired with core strength work. "
        "Be clear on the science: you cannot spot-reduce belly fat, and no "
        "exercise burns fat from one specific place. What this does is stack "
        "big calorie burns against a stronger core — the deficit from your food "
        "log is what actually shifts the fat."
    ),
    "level": "intermediate",
    "focus": "weight_loss",
    "equipment": "minimal",
    "duration_days": 14,
    "days_per_week": 5,
    "hero_image": "assets/illustrations/hiit_hero.png",
    "sort_index": 5,
    "weeks": weeks_from(belly_days()),
}

# ------------------------------------------------------------ lose-weight-30
def loseweight_days():
    days = []
    # week -> (base walk min, long session min, hard session min)
    plan = {1: (30, 40, 20), 2: (35, 45, 25), 3: (40, 45, 28),
            4: (45, 50, 30), 5: (45, 50, 30)}
    for week in range(1, 6):
        walk, longer, hard = plan[week]
        if week == 1:
            wk = [
                workout("Base Walk", "Cardio",
                        "Week 1: build the habit first. Conversational pace the whole way.",
                        [ex("brisk-walking", walk, f"{walk} min steady")]),
                workout("Incline Walk", "Cardio • Legs",
                        "Week 1: find a hill, or set the treadmill to a 5–8% incline.",
                        [ex("incline-walking", longer - 10, f"{longer - 10} min uphill")]),
                rest("Rest day", "Rest days matter as much as the walks. Log every meal."),
                workout("Long Walk", "Cardio",
                        "Week 1: your longest walk of the week. Podcast recommended.",
                        [ex("brisk-walking", longer, f"{longer} min steady")]),
                workout("Walk + Strength", "Cardio • Full body",
                        "Week 1: walk first, then two easy rounds of bodyweight work.",
                        [
                            ex("brisk-walking", walk, f"{walk} min steady"),
                            ex("glute-bridge", 4, "2 × 12 reps"),
                            ex("wall-sit", 3, "2 × 30 s hold"),
                        ]),
                rest("Rest day", "Second rest day. Weigh in tomorrow if you track weight."),
                workout("Weekend Walk", "Cardio",
                        "Week 1: same route, try to beat last time by a couple of minutes.",
                        [ex("brisk-walking", longer, f"{longer} min steady")]),
            ]
        elif week in (2, 3):
            wk = [
                workout("Jog Intervals", "Cardio",
                        f"Week {week}: alternate 2 min jog / 2 min walk for the whole session.",
                        [ex("jogging-12min", hard, f"{hard} min jog-walk intervals")]),
                workout("Cycle Steady", "Cardio • Legs",
                        f"Week {week}: steady spin. No bike? Do the incline walk instead.",
                        [ex("cycling-moderate", longer - 5, f"{longer - 5} min steady")]),
                rest("Rest day",
                     "Recovery day. Your deficit comes from the food log — keep it honest."),
                workout("Incline Walk", "Cardio • Legs",
                        f"Week {week}: uphill work builds the engine without the joint load.",
                        [ex("incline-walking", longer - 5, f"{longer - 5} min uphill")]),
                workout("Jog + Core", "Cardio • Core",
                        f"Week {week}: finish the jog, then three rounds of core.",
                        [
                            ex("jogging-12min", hard, f"{hard} min steady jog"),
                            ex("plank", 4, "3 × 40 s hold"),
                            ex("crunches", 4, "3 × 20 reps"),
                        ]),
                rest("Rest day", "Second rest day. Sleep is a weight-loss tool too."),
                workout("Long Walk", "Cardio",
                        f"Week {week}: long and easy. This is your highest-burn session.",
                        [ex("brisk-walking", walk + 15, f"{walk + 15} min steady")]),
            ]
        else:
            wk = [
                workout("Run", "Cardio",
                        f"Week {week}: continuous run at a pace you can just about hold.",
                        [ex("running-6mph", hard - 5, f"{hard - 5} min continuous")]),
                workout("Rope Intervals", "Cardio • Full body",
                        f"Week {week}: five rounds of 60 s rope, 60 s rest.",
                        [ex("jump-rope-moderate", 15, "5 × 60 s, 60 s rest")]),
                rest("Rest day",
                     "Rest. Four weeks in — judge the weight trend, not one weigh-in."),
                workout("Cycle Hard", "Cardio • Legs",
                        f"Week {week}: pick the pace up for the middle third.",
                        [ex("cycling-moderate", longer - 10,
                            f"{longer - 10} min, hard middle third")]),
                workout("Run + Core", "Cardio • Core",
                        f"Week {week}: run, then core work to finish.",
                        [
                            ex("running-6mph", hard - 10, f"{hard - 10} min run"),
                            ex("plank", 5, "3 × 60 s hold"),
                            ex("leg-raises", 4, "3 × 15 reps"),
                        ]),
                rest("Rest day", "Second rest day."),
                workout("Long Walk", "Cardio",
                        f"Week {week}: finish the week with a long easy walk.",
                        [ex("brisk-walking", walk + 15, f"{walk + 15} min steady")]),
            ]
        days.extend(wk if week < 5 else wk[:2])
    return days


LOSEWEIGHT_PROGRAM = {
    "id": "lose-weight-30",
    "name": "Lose Weight in 30 Days",
    "icon": "🏃",
    "goal": (
        "A 30-day progressive cardio build: brisk and incline walking in week "
        "1, jogging and cycling through weeks 2–3, running and rope intervals "
        "by week 4, with two rest days every week. The program creates the "
        "burn — your daily food log creates the deficit, so log every meal."
    ),
    "level": "beginner",
    "focus": "weight_loss",
    "equipment": "none",
    "duration_days": 30,
    "days_per_week": 5,
    "hero_image": "assets/illustrations/goal_lose_fat.png",
    "sort_index": 6,
    "weeks": weeks_from(loseweight_days()),
}

# ------------------------------------------------------------- kegel-core-14
# sets, hold s, reps, plank s, bridge reps
KEGEL = {1: (3, 5, 10, 20, 12), 2: (4, 8, 12, 30, 15)}


def kegel_days():
    days = []
    for week in range(1, 3):
        s, hold_s, reps, plank_s, bridge = KEGEL[week]
        days.extend([
            workout(
                "Pelvic Floor Basics", "Pelvic floor • Core",
                f"Week {week}: {s} sets of {reps} Kegels, {hold_s} s each. Breathe "
                "normally — never bear down, and keep glutes and thighs relaxed.",
                [
                    ex("kegel-hold", mins(s, reps * hold_s, 30),
                       f"{s} × {reps} reps, {hold_s} s hold"),
                    ex("glute-bridge", mins(s, bridge * 3), f"{s} × {bridge} reps"),
                    ex("plank", mins(s, plank_s), f"{s} × {plank_s} s hold"),
                ]),
            workout(
                "Deep Core", "Pelvic floor • Lower core",
                f"Week {week}: pair each squeeze with a slow exhale. Rest as long as you hold.",
                [
                    ex("kegel-hold", mins(s, reps * hold_s, 30),
                       f"{s} × {reps} reps, {hold_s} s hold"),
                    ex("leg-raises", mins(s, bridge * 4), f"{s} × {bridge - 2} slow reps"),
                    ex("glute-bridge", mins(s, bridge * 3), f"{s} × {bridge} reps"),
                ]),
            rest("Rest day",
                 "The pelvic floor is a muscle and needs recovery. Full rest today."),
            workout(
                "Control & Stability", "Pelvic floor • Core",
                f"Week {week}: quality over count — end the set when the squeeze weakens.",
                [
                    ex("kegel-hold", mins(s, reps * hold_s, 30),
                       f"{s} × {reps} reps, {hold_s} s hold"),
                    ex("plank", mins(s, plank_s), f"{s} × {plank_s} s hold"),
                    ex("superman-hold", mins(s, 20), f"{s} × 20 s hold"),
                ]),
            workout(
                "Endurance Holds", "Pelvic floor • Core",
                f"Week {week}: longer holds today — {hold_s + 2} s each, drop reps if needed.",
                [
                    ex("kegel-hold", mins(s, reps * (hold_s + 2), 30),
                       f"{s} × {reps - 2} reps, {hold_s + 2} s hold"),
                    ex("glute-bridge", mins(s, bridge * 3), f"{s} × {bridge + 2} reps"),
                    ex("leg-raises", mins(s, bridge * 4), f"{s} × {bridge - 2} reps"),
                ]),
            rest("Rest day", "Second rest day. Consistency beats intensity with this one."),
            workout(
                "Full Core Integration", "Pelvic floor • Core",
                f"Week {week}: hold a gentle Kegel through the plank — that is the whole point.",
                [
                    ex("kegel-hold", mins(s, reps * hold_s, 30),
                       f"{s} × {reps} reps, {hold_s} s hold"),
                    ex("plank", mins(s, plank_s + 10), f"{s} × {plank_s + 10} s hold"),
                    ex("glute-bridge", mins(s, bridge * 3), f"{s} × {bridge + 2} reps"),
                    ex("crunches", mins(s, bridge * 3), f"{s} × {bridge} reps"),
                ]),
        ])
    return days


KEGEL_PROGRAM = {
    "id": "kegel-core-14",
    "name": "14-Day Kegel & Core Power",
    "icon": "🧘",
    "goal": (
        "Two weeks of pelvic-floor training paired with deep core work — Kegel "
        "holds, bridges, planks and leg raises. This one is about control, "
        "continence and core stability, not calories: the kcal per session are "
        "deliberately tiny and that is exactly right. If you have pelvic pain "
        "or recent surgery, check with a clinician first."
    ),
    "level": "beginner",
    "focus": "core",
    "equipment": "none",
    "duration_days": 14,
    "days_per_week": 5,
    "hero_image": "assets/illustrations/recovery_hero.png",
    "sort_index": 7,
    "weeks": weeks_from(kegel_days()),
}

# ----------------------------------------------------------- pushup-power-21
# sets, pushup reps, dip reps, plank s, crawl s
PUSHUP = {1: (4, 8, 6, 30, 30), 2: (5, 11, 8, 45, 40), 3: (5, 15, 10, 60, 45)}


def pushup_days():
    days = []
    for week in range(1, 4):
        s, push, dip, hold, crawl = PUSHUP[week]
        days.extend([
            workout(
                "Push Volume", "Chest • Triceps",
                f"Week {week}: {s} sets of {push}. Knees down is a valid regression — "
                "full range always beats a sloppy rep.",
                [
                    ex("shadow-boxing", 4, "4 min warm-up"),
                    ex("pushup-vigorous", mins(s, push * 3), f"{s} × {push} reps"),
                    ex("dips", mins(s, dip * 4), f"{s} × {dip} reps"),
                    ex("plank", mins(s, hold), f"{s} × {hold} s hold"),
                ]),
            workout(
                "Tempo Push", "Chest • Shoulders",
                f"Week {week}: 3 s down, 1 s up. Fewer reps at this tempo is expected.",
                [
                    ex("shadow-boxing", 4, "4 min warm-up"),
                    ex("pushup-vigorous", mins(s, push * 4), f"{s} × {max(4, push - 3)} slow reps"),
                    ex("bear-crawl", mins(s, crawl), f"{s} × {crawl} s"),
                    ex("superman-hold", mins(s, 20), f"{s} × 20 s hold"),
                ]),
            rest("Rest day", "Pushing muscles want 48 h. Rest properly."),
            workout(
                "Push Ladder", "Chest • Triceps",
                f"Week {week}: ladder down {push}, {push - 2}, {push - 4}, {push - 6} reps "
                "with 60 s between rungs.",
                [
                    ex("pushup-vigorous", mins(s, push * 3), f"Ladder down from {push} reps"),
                    ex("dips", mins(s, dip * 4), f"{s} × {dip} reps"),
                    ex("plank", mins(s, hold), f"{s} × {hold} s hold"),
                ]),
            workout(
                "Conditioning Push", "Full body",
                f"Week {week}: circuit, {s} rounds, minimal rest.",
                [
                    ex("bear-crawl", mins(s, crawl), f"{s} × {crawl} s"),
                    ex("pushup-vigorous", mins(s, push * 3), f"{s} × {max(5, push - 2)} reps"),
                    ex("mountain-climbers", mins(s, 40), f"{s} × 40 s"),
                    ex("shadow-boxing", mins(s, 45), f"{s} × 45 s"),
                ]),
            rest("Rest day", "Second rest day. Protein and sleep do the rebuilding."),
            workout(
                "Max Test", "Chest • Triceps",
                f"Week {week}: one all-out set to failure, then {s - 1} back-off sets. "
                "Write the number down — it should climb every week.",
                [
                    ex("shadow-boxing", 4, "4 min warm-up"),
                    ex("pushup-vigorous", mins(s, push * 4), "1 max set + back-off sets"),
                    ex("dips", mins(s, dip * 4), f"{s - 1} × {dip} reps"),
                    ex("plank", mins(s, hold + 15), f"{s} × {hold + 15} s hold"),
                ]),
        ])
    return days


PUSHUP_PROGRAM = {
    "id": "pushup-power-21",
    "name": "21-Day Push-Up Power",
    "icon": "🙌",
    "goal": (
        "Three weeks of push-up progressions — volume, tempo, ladders and a "
        "weekly max test — backed by dips, bear crawls, planks and shadow-"
        "boxing warm-ups. Track your max set each week; that number is the "
        "whole scoreboard. No equipment needed."
    ),
    "level": "intermediate",
    "focus": "strength",
    "equipment": "none",
    "duration_days": 21,
    "days_per_week": 5,
    "hero_image": "assets/illustrations/upper_body_hero.png",
    "sort_index": 8,
    "weeks": weeks_from(pushup_days()),
}

patch_legacy(programs)
apply_meta(programs)

NEW = [SIXPACK_PROGRAM, FULLBODY_PROGRAM, STRENGTH_PROGRAM, LOWER_PROGRAM,
       BELLY_PROGRAM, LOSEWEIGHT_PROGRAM, KEGEL_PROGRAM, PUSHUP_PROGRAM]
by_id = {p["id"]: p for p in programs}
for p in NEW:
    if p["id"] in by_id:
        programs[programs.index(by_id[p["id"]])] = p
    else:
        programs.append(p)

programs.sort(key=lambda p: (p.get("sort_index", 100), p["name"]))

# -------------------------------------------------------------------- verify
errors = []
for p in programs:
    ids, days = [], 0
    for w in p["weeks"]:
        for s in w["sessions"]:
            days += 1
            if s.get("kind") == "rest":
                if s.get("exercises"):
                    errors.append(f"{p['id']}: rest day carries exercises")
                continue
            items = s.get("exercises") or [{"exercise_id": s.get("exercise_id")}]
            for it in items:
                ids.append(it["exercise_id"])
    missing = sorted({i for i in ids if i not in VALID})
    if missing:
        errors.append(f"{p['id']}: unknown exercise ids {missing}")
    declared = p.get("duration_days")
    if declared is not None and declared != days:
        errors.append(f"{p['id']}: duration_days={declared} but {days} sessions")
    if p.get("focus") in (None, "", "unknown"):
        errors.append(f"{p['id']}: missing focus")

if errors:
    print("FAILED:")
    for e in errors:
        print("  -", e)
    sys.exit(1)

(SEED / "programs.json").write_text(
    json.dumps(programs, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

print(f"OK — {len(programs)} programs")
for p in programs:
    n = sum(len(w["sessions"]) for w in p["weeks"])
    r = sum(1 for w in p["weeks"] for s in w["sessions"] if s.get("kind") == "rest")
    print(f"  {p['id']:28s} {p['focus']:12s} {n:3d} days ({n - r} workouts, {r} rest)")
