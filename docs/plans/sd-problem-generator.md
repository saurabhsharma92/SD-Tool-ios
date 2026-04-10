# SD Problem Generator — Pipeline Plan

## Context

The SD-Tool iOS app already has the Practice feature fully built and shipped. Problems are defined as JSON files in `systemdesign/problems/` and synced to Firestore via GitHub Actions.

The current bottleneck: authoring a new problem JSON by hand is tedious and error-prone, especially extracting `requiredComponents` and `requiredConnections` accurately. The goal is a **standalone CLI pipeline** (separate git repo) that accepts:
- A problem title + statement (you write, AI enriches)
- Per-level title + one-line description (you write, AI enriches)
- A **screenshot per level** showing the expected solution diagram

And outputs a ready-to-use JSON file that can be dropped straight into `systemdesign/problems/` in the iOS repo, triggering the existing GitHub Action to sync to Firestore.

This pipeline is **not part of the iOS project** — it is a separate repo with no iOS dependencies.

---

## New Repo: `sd-problem-generator`

### Repo Structure

```
sd-problem-generator/
  generate.py          # main CLI entrypoint
  extractor.py         # Claude Vision → components + connections
  enricher.py          # Claude text → constraints, feedbackHint, aiContextHint
  schema.py            # dataclasses mirroring the iOS JSON schema
  requirements.txt     # anthropic, pyyaml, pillow
  README.md
  examples/
    netflix/
      input.yaml       # problem spec
      level1.png       # solution screenshot for level 1
      level2.png
      level3.png
    output/
      design-netflix.json  # generated output
```

---

## Input Format

User creates an `input.yaml` alongside the screenshots:

```yaml
id: design-netflix
title: Design Netflix
statement: "Build a video streaming platform serving billions of users."
difficulty: hard
tags: [streaming, cdn, video, scale]
levels:
  - number: 1
    title: Basic Streaming
    description: "Single server, small scale, direct upload and playback"
    screenshot: level1.png
  - number: 2
    title: Global Delivery
    description: "Global users, CDN needed, buffering is the problem"
    screenshot: level2.png
  - number: 3
    title: Async Transcoding
    description: "Multiple resolutions, transcoding blocks upload response"
    screenshot: level3.png
```

---

## Pipeline Steps

### Step 1 — Screenshot Extraction (per level)

Feed each screenshot to **Claude Vision** (claude-sonnet-4-6) with a strict prompt:

```
Analyze this system design diagram screenshot.

Available component types — use EXACT names only:
Input, Server, RDBMS, NoSQL, Cache, API Gateway, CDN, Reverse Proxy,
Read Replicas, Write Replicas, File Storage

Extract:
1. All block components visible in the diagram
2. All directed arrows/connections between components (source → destination)

Respond ONLY with valid JSON:
{
  "components": ["Input", "Server", "RDBMS"],
  "connections": [["Input", "Server"], ["Server", "RDBMS"]]
}
```

The extraction is deterministic from the screenshot — no inference, just read what's drawn.

### Step 2 — Text Enrichment (per level)

A second Claude call generates the three text fields:

```
Problem: "{title}"
Level {number}: "{level_title}"
User's description: "{description}"
Solution components: {components}
Solution connections: {connections_as_arrows}

Generate these 3 fields for the JSON:
1. constraints: 1-2 sentence constraint shown to the student (use numbers/metrics)
2. feedbackHint: Encouraging feedback when student passes this level (1-2 sentences, hints at next challenge)
3. aiContextHint: Internal hint for AI grader — what this level tests and what to accept

Respond ONLY with valid JSON:
{"constraints": "...", "feedbackHint": "...", "aiContextHint": "..."}
```

### Step 3 — Assemble + Write JSON

Combine user input + extracted solution + enriched text into the final JSON matching the iOS schema and write to `output/{id}.json`.

---

## CLI Usage

```bash
# Install
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...

# Run
python generate.py examples/netflix/input.yaml

# Output
# ✓ Level 1: extracted 3 components, 2 connections
# ✓ Level 2: extracted 5 components, 4 connections
# ✓ Written to output/design-netflix.json
```

---

## End-to-End Workflow

```
1. Draw solution per level (whiteboard, paper, any tool) → screenshot
2. Fill input.yaml (title, per-level description + screenshot paths)
3. python generate.py input.yaml
4. Review output JSON (spot-check connections)
5. Copy → SD-Tool-ios/systemdesign/problems/design-netflix.json
6. git commit + push → GitHub Action syncs to Firestore → live in app
```

---

## Key Details

- **Known component names only**: If Vision returns an unknown name, script warns and asks user to confirm/map it
- **Connection format**: `[["A","B"],...]` — matches existing problem JSON; sync script already flattens to `"A→B"` for Firestore
- **Overview**: Generated from `statement` + all level descriptions in one Claude call
- **No Firebase**: This tool only generates JSON, never writes to Firestore
- **Retry on bad JSON**: If Vision returns invalid JSON → retry once, then print raw for manual fix

---

## Files to Create (new repo)

| File | Purpose |
|------|---------|
| `generate.py` | CLI entrypoint: parse YAML, orchestrate steps, write output JSON |
| `extractor.py` | `extract_solution(screenshot_path) -> {components, connections}` via Claude Vision |
| `enricher.py` | `enrich_level(...)  -> {constraints, feedbackHint, aiContextHint}` via Claude |
| `schema.py` | `SDLevel`, `SDProblem` dataclasses + `to_dict()` for JSON serialization |
| `requirements.txt` | `anthropic>=0.40.0`, `pyyaml>=6.0`, `pillow>=10.0` |
| `README.md` | Usage + example workflow |
| `examples/netflix/input.yaml` | Example input file |

---

## Verification

1. Run with a screenshot of a simple known design (Input→Server→RDBMS)
2. Verify `components` = `["Input","Server","RDBMS"]`, `connections` = `[["Input","Server"],["Server","RDBMS"]]`
3. Drop output JSON into iOS repo → `node scripts/sync-sd-problems.js` → confirm problem appears in app
4. Submit the exact correct solution → verify score = 100%
