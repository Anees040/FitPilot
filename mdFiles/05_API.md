# FitPilot — API Specification (Node/Express AI proxy)

> Version 1.0 — July 2026 · Base URL: `https://fitpilot-api.onrender.com/v1` · All endpoints require `Authorization: Bearer <supabase JWT>`

## 1. Why this server exists
Only two jobs: (a) keep the Gemini key off the device, (b) enforce quota/rate-limit/cache so the free tier survives. ALL other data access is Flutter → Supabase directly.

## 2. Endpoints
### POST /v1/ai/photo-estimate
Request: `multipart/form-data` — `image` (jpeg ≤ 2MB, client compresses), optional `hint` (string).
Response 200:
```json
{
  "items": [{"name": "Chicken biryani", "portion": "1 plate (~350g)"}],
  "kcal_min": 520, "kcal_max": 680,
  "confidence": "medium",
  "follow_up_question": "Raita ya salan ke saath?",
  "cached": false
}
```
Errors: `401` invalid JWT · `429 {"error":"quota_exceeded","resets_at":...}` (4th call of day) · `503 {"error":"ai_unavailable"}` (Gemini down/quota — client falls back gracefully).
Flow: verify JWT → check `ai_usage` quota → sha256 image hash → cache lookup → Gemini w/ JSON-schema prompt → validate with zod → increment quota → cache 30 days → respond. **Image processed in memory only; never written to disk.**

### POST /v1/ai/text-parse
Request: `{"text": "aik plate biryani aur 2 roti"}`
Response 200: `{"items":[{"food_name":"Biryani","quantity":1,"kcal_min":520,"kcal_max":680},{"food_name":"Roti","quantity":2,"kcal_min":200,"kcal_max":240}],"confidence":"high"}`
Note: client calls this ONLY after local DB match fails. Server also tries exact match against `foods` before calling Gemini. Cache key = normalized text, 30 days.

### GET /v1/health
`{"status":"ok"}` — no auth; used by cron keep-alive.

## 3. Middleware stack (order matters)
`helmet` → CORS (allow app origin only) → JSON body limit 100kb / multer memoryStorage 2MB → JWT verify (jose, Supabase JWT secret) → express-rate-limit keyed by user id (20 req/min) → route → zod response validation → error handler (typed JSON errors, no stack traces in prod).

## 4. Gemini prompt contract (photo-estimate)
System prompt requires STRICT JSON matching the response schema; rules: desi food awareness; portion in local terms (plate/roti/cup); ranges not points; confidence honest; at most one follow_up_question, in Roman Urdu if input was. Reject non-food images with `{"error":"not_food"}`.
Evaluation: `server/test/golden/` holds 30 labeled desi meal photos + expected ranges; `npm run eval` scores overlap. Improve the prompt, not vibes.

## 5. Environment variables (Render dashboard only — never in repo)
```
GEMINI_API_KEY=...        # aistudio.google.com → Get API key
SUPABASE_URL=...
SUPABASE_JWT_SECRET=...   # Supabase → Settings → API → JWT Secret
SUPABASE_SERVICE_ROLE=... # server-only writes to ai_usage
NODE_ENV=production
```
Local dev: `.env` file, `.gitignore`d; commit `.env.example` with empty values.

## 6. Deploy (Render)
1. render.com → New → Web Service → connect GitHub repo, root dir `server/`.
2. Build: `npm ci && npm run build` · Start: `node dist/index.js` · Instance: Free.
3. Add env vars → Deploy → verify `GET /v1/health`.
4. Keep-alive: GitHub Action cron `*/10 * * * *` curls /v1/health (mitigates cold starts).
