# System Design Practice Feature Plan

## Context

Users want to practice system design skills inside the app. They pick a problem (e.g. "Design Twitter") and work through it level by level — each level introduces new constraints (more traffic, celebrity fan-out, content moderation, etc.) that require evolving the architecture. The app validates the user's drawn graph against each level's solution requirements using a hybrid algorithmic + Gemini AI approach. Problems are stored in Firebase Firestore and authored via a repo-based admin script. This feature lands as a new "Practice" bottom tab.

---

## Problem Model: Multi-Level Constraint Progression

Each problem is a journey. Levels introduce progressively harder real-world constraints on the same system — not just "add more components" but "your naive approach breaks at this scale, redesign it."

**Twitter example:**
| Level | Title | Key Constraint |
|-------|-------|----------------|
| 1 | Basic Twitter | 10K DAU, simple post + follow + feed |
| 2 | High Read Volume | 10M DAU, read:write = 100:1, cache needed |
| 3 | Fan-out Problem | Celebrities with 10M followers, naive fan-out fails |
| 4 | Hybrid Fan-out | Mix push (regular users) + pull (celebrities) |
| 5 | Content Moderation | Filter harmful content before delivery |

Users see level titles and constraints. The problem-level `difficulty` tag (easy/medium/hard) is hidden — it only controls ordering in the problem list.

---

## Options Considered

| Decision | Chosen | Why |
|----------|--------|-----|
| Canvas UI | Custom SwiftUI | SplashView already draws Canvas connections; no new deps; native feel |
| Storage | Firestore | Adding problems without app releases; Firebase SDK already included |
| Validation | Hybrid (algorithmic + Gemini) | Gemini for auth users with quota, algorithmic fallback for guests/exhausted |
| Connections | Directional arrows | Accurate for data-flow semantics in system design |
| Level progression | Sequential unlock | Must complete level N before seeing level N+1 |

---

## Architecture Overview

```
PracticeTabView (problem list with per-problem progress)
  └── ProblemDetailView (level strip + current level prompt)
       └── DesignCanvasView (canvas + toolbar)
            ├── EdgeCanvasLayer (Canvas, draws arrows)
            ├── BlockNodeView × N (DragGesture nodes)
            ├── CanvasToolbarView (palette, connect, delete, submit)
            └── ValidationResultView (sheet, post-submit feedback + unlock)

SDProblemStore (@MainActor ObservableObject)
  └── SDProblemService (actor) ← Firestore

SDProgressStore (@MainActor ObservableObject)  ← per-user level progress
SDCanvasStore (@MainActor ObservableObject)     ← canvas state for current level

SDValidationService (actor)
  ├── scoreAlgorithmically(user:level:) → Float
  └── GeminiService.shared (reused, existing)
```

---

## Firestore Schema

### Collection: `sd_problems`
```
Document ID: "design-twitter"
{
  title:       "Design Twitter",
  overview:    "Build Twitter's backend from scratch, evolving the design as scale grows.",
  difficulty:  "medium",       // hidden — controls list ordering only
  tags:        ["social","feed","scale"],
  levelCount:  5,
  levels: [
    {
      levelNumber:  1,
      title:        "Basic Twitter",
      constraints:  "Design for 10K DAU. Users post tweets, follow others, and have a home feed.",
      requiredComponents:  ["Input", "Server", "RDBMS"],
      requiredConnections: [["Input","Server"], ["Server","RDBMS"]],
      feedbackHint: "Solid foundation! At 1M+ users, feed reads will become a bottleneck.",
      aiContextHint: "Level 1 is a simple monolithic design. Accept anything with a server + database."
    },
    {
      levelNumber:  2,
      title:        "High Read Volume",
      constraints:  "10M DAU. Read:write ratio is 100:1. Home feed queries are timing out.",
      requiredComponents:  ["Input", "API Gateway", "Server", "Cache", "RDBMS"],
      requiredConnections: [["Input","API Gateway"],["API Gateway","Server"],
                            ["Server","Cache"],["Server","RDBMS"]],
      feedbackHint: "Great use of caching! Next challenge: what happens with celebrity accounts?",
      aiContextHint: "Level 2 requires caching (Redis/Memcached) to handle heavy read traffic."
    },
    {
      levelNumber:  3,
      title:        "Fan-out Problem",
      constraints:  "A celebrity with 10M followers posts. Naive fan-out writes 10M DB rows — too slow.",
      requiredComponents:  ["Input","API Gateway","Server","Cache","RDBMS","NoSQL"],
      requiredConnections: [["Input","API Gateway"],["API Gateway","Server"],
                            ["Server","Cache"],["Server","RDBMS"],["Server","NoSQL"]],
      feedbackHint: "Good thinking on separating storage! Can push fan-out be improved further?",
      aiContextHint: "Level 3 needs a separate fast write path (NoSQL/queue) for fan-out."
    },
    {
      levelNumber:  4,
      title:        "Hybrid Fan-out",
      constraints:  "Regular users: push on write. Celebrities: pull on read. Design the hybrid.",
      requiredComponents:  ["Input","CDN","API Gateway","Server","Cache","RDBMS","NoSQL"],
      requiredConnections: [["Input","CDN"],["CDN","API Gateway"],["API Gateway","Server"],
                            ["Server","Cache"],["Server","RDBMS"],["Server","NoSQL"]],
      feedbackHint: "Excellent hybrid approach! One more challenge: harmful content in feeds.",
      aiContextHint: "Level 4 adds CDN for static media + hybrid fan-out strategy."
    },
    {
      levelNumber:  5,
      title:        "Content Moderation",
      constraints:  "Filter harmful/restricted content before it reaches followers. Must be async.",
      requiredComponents:  ["Input","CDN","API Gateway","Server","Cache","RDBMS","NoSQL","Reverse Proxy"],
      requiredConnections: [...],
      feedbackHint: "You've designed a production-grade Twitter. Try a harder problem!",
      aiContextHint: "Level 5 requires an async moderation pipeline before fan-out."
    }
  ]
}
```

### Collection: `sd_progress` (per user)
```
Document ID: {userId}_{problemId}   e.g. "abc123_design-twitter"
{
  userId:           "firebase-uid",
  problemId:        "design-twitter",
  completedLevels:  [1, 2, 3],
  currentLevel:     4,
  lastAttemptAt:    Timestamp,
  levelFeedback: {
    "1": "Your level 1 design was clean and straightforward...",
    "2": "Good use of Redis. Consider also...",
    "3": "..."
  }
}
```

Security: read/write only if `request.auth.uid == resource.data.userId`.

---

## Files to Create

All under `SDTool/SDTool/Practice/`

| File | Purpose |
|------|---------|
| `Models/SDProblem.swift` | `Codable`: `SDProblem` (id, title, overview, difficulty, tags, levelCount, levels), `SDLevel` (levelNumber, title, constraints, requiredComponents, requiredConnections, feedbackHint, aiContextHint) |
| `Models/SDProgress.swift` | `Codable`: `SDProgress` (userId, problemId, completedLevels, currentLevel, levelFeedback dict) |
| `Models/DesignGraph.swift` | `BlockType` enum (8 types), `CanvasNode` (id, type, position, scalingMode), `CanvasEdge` (id, from, to), `ScalingMode` (.none/.horizontal/.vertical), `DesignGraph` (serialized snapshot) |
| `Models/ValidationResult.swift` | `ValidationResult` (passed: Bool, score: Float, aiFeedback: String?, fallbackHint: String) |
| `Services/SDProblemService.swift` | `actor`. Fetches `sd_problems` from Firestore. Disk-caches as JSON. |
| `Services/SDProgressService.swift` | `actor`. Reads/writes `sd_progress` documents. Creates doc on first attempt. |
| `Services/SDValidationService.swift` | `actor`. `scoreAlgorithmically(user:level:) -> Float`. `validate(graph:problem:level:) async -> ValidationResult` — runs algorithmic check, then calls Gemini if auth + quota available. |
| `Stores/SDProblemStore.swift` | `@MainActor ObservableObject`. `@Published var problems: [SDProblem]`, `isLoading`. |
| `Stores/SDProgressStore.swift` | `@MainActor ObservableObject`. `@Published var progressMap: [String: SDProgress]`. Key = problemId. Exposes `currentLevel(for:)`, `isLevelUnlocked(_:for:)`, `markLevelComplete(_:for:feedback:)`. |
| `Stores/SDCanvasStore.swift` | `@MainActor ObservableObject`. `@Published var nodes: [CanvasNode]`, `edges: [CanvasEdge]`, `selectedNodeId`, `connectMode: Bool`. Methods: `addNode`, `moveNode(id:to:)`, `addEdge(from:to:)`, `deleteSelected`, `setScaling(id:mode:)`, `exportGraph() -> DesignGraph`, `reset()`. |
| `Views/PracticeTabView.swift` | Root view. `List` of `ProblemRowView` sorted by difficulty (hidden). NavigationStack → `ProblemDetailView`. |
| `Views/ProblemRowView.swift` | Shows title, tags (chips), progress bar (e.g. "3 / 5 levels"). No difficulty shown. |
| `Views/ProblemDetailView.swift` | Shows problem overview + horizontal level strip. Each level chip: ✓ (completed), → (current, unlocked), 🔒 (locked). Tap current level → `DesignCanvasView`. |
| `Views/DesignCanvasView.swift` | Main canvas. Nav title = level title. Level constraints shown in collapsible banner at top. ZStack: `EdgeCanvasLayer` + `ForEach(nodes) { BlockNodeView }`. `CanvasToolbarView` at bottom. |
| `Views/BlockNodeView.swift` | Block icon + label. `DragGesture` moves node. Long-press context menu: Horizontal Scaling (3 offset copies rendered), Vertical Scaling (↑ badge), Delete. Highlighted when selected in connect mode. |
| `Views/EdgeCanvasLayer.swift` | SwiftUI `Canvas` drawing directed edges as lines + arrowheads. Reuses pattern from `SplashView.swift:154`. |
| `Views/CanvasToolbarView.swift` | "Add Block" (→ `BlockPaletteSheet`), "Connect" toggle, "Delete", "Submit". |
| `Views/BlockPaletteSheet.swift` | Bottom sheet grid of 8 block types with icons and names. Tap = add to canvas center. |
| `Views/ValidationResultView.swift` | Post-submit sheet. Shows pass/fail badge, score %, AI feedback (or hint). On pass: "Next Level →" button that calls `SDProgressStore.markLevelComplete`. On final level pass: "Try a Harder Problem" CTA. |

---

## Files to Modify

| File | Change |
|------|--------|
| `DocList/ContentView.swift` | Add Practice tab at tag 5: `Label("Practice", systemImage: "pencil.and.diagram")`. Order: `[Home(0)][FlashCards(3)][Practice(5)][Settings(4)]`. |
| `SDToolApp.swift` | Add `let _ = Firestore.firestore()` after Firebase init to warm Firestore connection. |
| `.gitignore` | Add `scripts/serviceAccountKey.json` entry. |

## Additional Files to Create (repo-level, not iOS)

| File | Purpose |
|------|---------|
| `.github/workflows/sync-sd-problems.yml` | GitHub Actions workflow — auto-syncs `systemdesign/problems/**` to Firestore on push to `main`. |
| `scripts/sync-sd-problems.js` | Node.js admin script — upserts all problem JSON files to Firestore `sd_problems` collection. |
| `scripts/package.json` | `{ "dependencies": { "firebase-admin": "^12.0.0" } }` |
| `systemdesign/problems/design-url-shortener.json` | Starter problem (easy, 3 levels) |
| `systemdesign/problems/design-twitter.json` | Starter problem (medium, 5 levels) |
| `systemdesign/problems/design-youtube.json` | Starter problem (medium, 4 levels) |
| `systemdesign/problems/design-rate-limiter.json` | Starter problem (medium, 3 levels) |
| `systemdesign/problems/design-whatsapp.json` | Starter problem (hard, 5 levels) |

---

## Key Implementation Details

### Adding FirebaseFirestore (no new SPM package)
Firebase SDK v12.10.0+ already in project. In Xcode:
`Target → Frameworks → + → FirebaseFirestore`

### Level Unlock Logic
```swift
// SDProgressStore
func isLevelUnlocked(_ level: Int, for problemId: String) -> Bool {
    if level == 1 { return true }
    let progress = progressMap[problemId]
    return progress?.completedLevels.contains(level - 1) ?? false
}
```

### Canvas Connect Mode
```swift
// SDCanvasStore
func handleNodeTap(_ nodeId: UUID) {
    guard connectMode else { return }
    if let source = selectedNodeId {
        if source != nodeId {
            edges.append(CanvasEdge(from: source, to: nodeId))
        }
        selectedNodeId = nil
    } else {
        selectedNodeId = nodeId
    }
}
```

### Arrowhead Drawing (reuses SplashView.swift:154 pattern)
```swift
func drawArrow(ctx: GraphicsContext, from: CGPoint, to: CGPoint) {
    var path = Path()
    path.move(to: from); path.addLine(to: to)
    let angle = atan2(to.y - from.y, to.x - from.x)
    let len: CGFloat = 10; let a: CGFloat = .pi / 6
    path.move(to: to)
    path.addLine(to: CGPoint(x: to.x - len*cos(angle-a), y: to.y - len*sin(angle-a)))
    path.move(to: to)
    path.addLine(to: CGPoint(x: to.x - len*cos(angle+a), y: to.y - len*sin(angle+a)))
    ctx.stroke(path, with: .color(.primary), style: StrokeStyle(lineWidth: 1.5))
}
```

### Validation Logic (per level)
```swift
// SDValidationService
func scoreAlgorithmically(user: DesignGraph, level: SDLevel) -> Float {
    let reqComps = Set(level.requiredComponents)
    let userComps = Set(user.components)
    let compScore = Float(reqComps.intersection(userComps).count) / Float(reqComps.count)

    let reqConns = Set(level.requiredConnections.map { $0.joined(separator: "→") })
    let userConns = Set(user.connections.map { $0.joined(separator: "→") })
    let connScore = Float(reqConns.intersection(userConns).count) / Float(reqConns.count)

    return (compScore + connScore) / 2.0
}
// Pass threshold: score >= 0.8
```

### AI Prompt (via GeminiService.shared)
```swift
let prompt = """
You are a system design mentor. Problem: "\(problem.title)" — Level \(level.levelNumber): "\(level.title)"

Constraints given to student: \(level.constraints)
Context: \(level.aiContextHint)

Student's design:
- Components: \(user.components.joined(separator: ", "))
- Connections: \(user.connections.map{$0.joined(separator:"→")}.joined(separator: ", "))

Algorithmic score: \(Int(score * 100))% match to expected solution.

Provide:
1. What they got right (2 points)
2. What's missing or incorrect (2 points, specific)
3. One insight about this constraint they should remember
Be concise, max 150 words.
"""
```

### Fallback (Guest / Quota Exhausted)
- Use `level.feedbackHint` from Firestore.
- Banner: "Sign in for AI-powered feedback" (guest) or "Daily AI quota reached" (exhausted).
- Algorithmic score still shown.

### Grouping (v1 simplified)
- Multi-select: long press canvas background → rubber-band
- Toolbar shows "Group" when 2+ selected
- `CanvasGroup` (id, name, nodeIds) rendered as labeled rounded-rect behind members
- Drag group = move all member nodes

---

## Content Management: How the App Owner Populates Problems

### Approach: JSON files in repo → Node.js admin script syncs to Firestore

```
systemdesign/
  problems/
    design-twitter.json
    design-url-shortener.json
    ...
scripts/
  sync-sd-problems.js        ← admin script
  serviceAccountKey.json     ← gitignored (local runs only)
```

### Problem JSON Format

```json
{
  "id": "design-twitter",
  "title": "Design Twitter",
  "overview": "Build Twitter's backend from scratch, evolving as scale grows.",
  "difficulty": "medium",
  "tags": ["social", "feed", "scale"],
  "levels": [
    {
      "levelNumber": 1,
      "title": "Basic Twitter",
      "constraints": "Design for 10K DAU. Users post tweets, follow others, simple home feed.",
      "requiredComponents": ["Input", "Server", "RDBMS"],
      "requiredConnections": [["Input","Server"], ["Server","RDBMS"]],
      "feedbackHint": "Solid start! At 1M users, feed reads will bottleneck.",
      "aiContextHint": "Basic monolithic design. Accept server + database minimum."
    }
  ]
}
```

### Admin Sync Script (`scripts/sync-sd-problems.js`)

```js
const admin = require('firebase-admin');
const fs = require('fs'), path = require('path');

// Local: reads serviceAccountKey.json. CI: reads from env var.
const credential = process.env.FIREBASE_SERVICE_ACCOUNT
  ? admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT))
  : admin.credential.cert(require('./serviceAccountKey.json'));

admin.initializeApp({ credential });
const db = admin.firestore();
const dir = path.join(__dirname, '../systemdesign/problems');

async function sync() {
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.json'));
  for (const file of files) {
    const problem = JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'));
    await db.collection('sd_problems').doc(problem.id).set(problem);
    console.log(`✓ ${problem.id} (${problem.levels.length} levels)`);
  }
  console.log(`Done. ${files.length} problems synced.`);
}
sync().catch(console.error);
```

### Triggering the Sync: GitHub Actions (automatic on push)

```yaml
# .github/workflows/sync-sd-problems.yml
name: Sync SD Problems to Firestore
on:
  push:
    branches: [main]
    paths: ['systemdesign/problems/**']

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: cd scripts && npm install firebase-admin
      - run: node scripts/sync-sd-problems.js
        env:
          FIREBASE_SERVICE_ACCOUNT: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
```

Store the service account JSON as a **GitHub repository secret** named `FIREBASE_SERVICE_ACCOUNT`.

**Full workflow:**
```
Author JSON with Claude → review requiredConnections → git commit + push
  → GitHub Action triggers → syncs to Firestore → problem live in app (~1 min)
```

### Authoring Problems: AI-Assisted via Claude

Use Claude to generate the initial JSON, then review and tune `requiredConnections`:

```
Create a system design practice problem JSON for: "Design YouTube"

Available components: Input, Server, RDBMS, NoSQL, Cache, API Gateway, CDN, Reverse Proxy

Make 4 levels:
1. Basic video upload + playback (low traffic)
2. High traffic — caching and CDN needed
3. Async video transcoding pipeline
4. Global scale — geo-distributed CDN, regional DBs

Output valid JSON matching this schema:
{ id, title, overview, difficulty, tags, levels: [
  { levelNumber, title, constraints, requiredComponents,
    requiredConnections, feedbackHint, aiContextHint }
]}
```

---

## Starter Problem Set (5 problems)

1. `design-url-shortener.json` — easy, 3 levels
2. `design-twitter.json` — medium, 5 levels
3. `design-youtube.json` — medium, 4 levels
4. `design-rate-limiter.json` — medium, 3 levels
5. `design-whatsapp.json` — hard, 5 levels

---

## Reusable Components

| Existing | Location | How reused |
|----------|----------|-----------|
| `Canvas` + connection drawing | `SplashView.swift:154` | `EdgeCanvasLayer` arrow rendering |
| `DragGesture` | `StudyView.swift:76` | Block node repositioning |
| `GeminiService.shared` | `AI/GeminiService.swift` | AI feedback |
| `GuestRestrictionView` | `V2/GuestRestrictionView.swift` | Block AI for guests |
| `AIQuotaStore.shared` | `AI/AIQuotaStore.swift` | Check/charge quota before AI call |
| `NavigationStack` + `.navigationDestination` | `FlashCardsHomeView.swift` | Problem list → detail → canvas |
| Disk JSON persistence pattern | `FlashCardStore.swift` | Problem cache in `SDProblemService` |

---

## Verification / Testing

1. **Build**: `xcodebuild -project SDTool/SDTool.xcodeproj -scheme SDTool -destination 'platform=iOS Simulator,name=iPhone 16' build`
2. **Tab visible**: Practice tab appears in bottom bar.
3. **Problem list**: Problems load from Firestore, show progress bars, no difficulty shown.
4. **Level locking**: Level 2+ show 🔒 until level 1 is passed.
5. **Canvas basics**: Add blocks, drag around, positions update correctly.
6. **Connect mode**: Tap source → highlight → tap destination → arrow drawn.
7. **Long-press scaling**: Horizontal → 3 stacked copies; Vertical → ↑ badge.
8. **Submit + pass**: Correct level 1 design → pass badge + AI feedback → "Level 2 →" unlocks.
9. **Submit + fail**: Incomplete design → score shown + specific gaps in feedback.
10. **Guest flow**: Guest submits → no AI, shows `feedbackHint` + sign-in prompt.
11. **Quota exhausted**: Force exhaust → falls back to `feedbackHint`.
12. **Level 5 complete**: Final level pass → "Try a Harder Problem" CTA.
13. **Admin script**: `node scripts/sync-sd-problems.js` → new problem appears in app.
14. **GitHub Action**: Push a changed JSON → Action runs → Firestore updated.
15. **Firestore security**: Unauthenticated read rejected; auth'd read succeeds.

---

## Out of Scope (v1)

- Undo/redo on canvas
- Edge labels (e.g. "REST", "gRPC", throughput annotations)
- Saving in-progress canvas drafts
- Leaderboard / sharing designs
- Animated data-flow visualization
- Custom block types
- Timer / timed challenge mode
