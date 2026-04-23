# Contributing to SDTool

Thank you for helping make SDTool better! There are three ways to contribute:

1. **Submit an article** — add a system design article to the `articles/` folder
2. **Request a blog company** — add an engineering blog RSS feed
3. **Add flash card decks** — create study decks in `flashcards/`
4. **Report bugs / suggest features** — open a GitHub issue

---

## Before You Start

- Check [existing articles](../articles/index.md) and [blogs](../blogs/index.md) to avoid duplicates
- Read the [Content Guide](CONTENT.md) for file formats
- All content must focus on **software engineering** — system design, distributed systems, databases, architecture, networking, or security

---

## Submitting an Article

Articles are written in **HTML** and rendered in the app's built-in browser with beautiful PreTeXt-inspired typography. Legacy `.md` articles also work but new articles should be `.html`.

### Step 1 — Fork and Clone

```bash
# Fork on GitHub first, then:
git clone https://github.com/YOUR_USERNAME/SD-Tool-ios.git
cd SD-Tool-ios
git checkout -b article/your-topic-name
```

### Step 2 — Create the Article

```bash
cp article-template.html articles/your-topic-name.html
```

Use lowercase with hyphens: `database-sharding.html`, `rate-limiting.html`.

**Article template** (`article-template.html`):

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Your Article Title</title>
</head>
<body>

<h1>Your Article Title</h1>
<p class="article-meta">Category · Estimated read time</p>

<h2>Introduction</h2>
<p>Your content here...</p>

<!-- Architecture diagram -->
<pre class="mermaid">
graph LR
  A[Client] --> B[API Gateway]
  B --> C[Server]
</pre>

<!-- Callout boxes -->
<div class="note">A helpful note.</div>
<div class="warning">Important warning.</div>
<div class="tip">A pro tip.</div>

</body>
</html>
```

The app automatically injects the CSS — you don't need to link it in the file.

### Step 3 — Writing Guidelines

| Rule | Detail |
|---|---|
| Minimum length | 800 words |
| Diagrams | Use `<pre class="mermaid">` blocks (renders natively) |
| Images | Use `<img src="https://raw.githubusercontent.com/...">` with absolute URLs |
| Code | Use `<pre><code>` for code blocks |
| Tone | Technical but accessible — written for senior engineers |
| No promotion | No affiliate links, sponsored content, or advertisements |
| Language | English only |

### Step 4 — Register in index.md

Add one line to `articles/index.md` using `=` as delimiter:

```
your-topic-name.html=Your Topic Name|Category
```

Use an existing category (`Basics`, `System Design`, `AI-ML`). If you need a new category, mention it in the PR.

### Step 5 — Open a Pull Request

```bash
git add articles/your-topic-name.html articles/index.md
git commit -m "article: Add Your Topic Name"
git push origin article/your-topic-name
```

Open a PR with:
- **Title:** `[Article] Your Topic Name`
- **Description:** What the article covers, target audience, any new categories

---

## Requesting a Blog Company

### Step 1 — Verify the RSS Feed

The company must have a working public RSS/Atom feed. Test it:
1. Paste the URL in a browser — you should see XML
2. Paste into [feedvalidator.org](https://feedvalidator.org) — should pass

Common RSS URL patterns:
```
https://engineering.company.com/feed
https://blog.company.com/rss
https://medium.com/feed/company-blog
https://company.com/blog/rss.xml
```

### Step 2 — Add to blogs/index.md

```markdown
| Company Name | https://company.com | https://company.com/feed |
```

### Step 3 — Open a Pull Request

```bash
git checkout -b blog/add-company-name
git add blogs/index.md
git commit -m "blog: Add Company Name"
git push origin blog/add-company-name
```

PR title: `[Blog] Add Company Name`

Include:
- Why it's valuable for system design / engineering learners
- Verified RSS URL

---

## Adding Flash Card Decks

### Step 1 — Create the Deck File

```bash
# Create a new deck file
touch flashcards/your-topic.md
```

### Step 2 — Write the Cards

```markdown
# Your Topic Name

## Card: What is X?
X is ...

## Card: What is the difference between X and Y?
X does ... while Y does ...
```

See [Content Guide — Flash Cards](CONTENT.md#flash-cards) for full format.

### Step 3 — Open a Pull Request

```bash
git checkout -b cards/your-topic
git add flashcards/your-topic.md
git commit -m "cards: Add Your Topic deck"
git push origin cards/your-topic
```

---

## Reporting Bugs

Open an issue at [github.com/saurabhsharma92/SD-Tool-ios/issues](https://github.com/saurabhsharma92/SD-Tool-ios/issues)

Include:
- iOS version
- Steps to reproduce
- Expected vs actual behavior
- Screenshot if applicable

---

## Feature Requests

Open an issue with the `enhancement` label. Describe:
- What problem you're trying to solve
- How you'd expect it to work
- Any alternatives you considered

---

## Code Contributions

For iOS code changes:

1. Fork → branch → make changes → PR against `main`
2. Follow existing code style (Swift, SwiftUI)
3. No third-party dependencies without discussion
4. All debug code must be inside `#if DEBUG` blocks
5. No `print()` statements outside `#if DEBUG`
6. Never commit `GoogleService-Info.plist` or any credentials

---

## Review Process

PRs are reviewed by the maintainer. You may receive feedback requesting changes. Once approved and merged, content appears in the app on the user's next sync.

**Response time:** Best effort, typically within a few days.

---

## Questions?

Open an issue with the `question` label.
