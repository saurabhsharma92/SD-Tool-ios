# How to Contribute to SDTool

SDTool is community-driven. This guide explains how to submit a new article or request a blog company be added to the app.

---

## Submitting an Article

Articles live in the `articles/` folder of the repository and follow a standard markdown template.

### Step 1 — Fork the Repository

Go to [github.com/saurabhsharma92/SD-Tool-ios](https://github.com/saurabhsharma92/SD-Tool-ios) and click **Fork** to create your own copy.

### Step 2 — Copy the Article Template

In your fork, copy `article-template.md` from the repo root into the `articles/` folder and rename it using lowercase-with-hyphens:

```
articles/your-topic-name.md
```

### Step 3 — Fill in the Template

Open your new file and fill in each section. The template includes:

- **Title** — clear and descriptive
- **Introduction** — what problem this article solves
- **Core Concepts** — key ideas with explanations
- **Deep Dive** — detailed breakdown with examples
- **Diagrams** — use Mermaid syntax for architecture diagrams (supported natively in SDTool)
- **Trade-offs** — pros and cons
- **Real World Usage** — examples from production systems
- **Summary** — key takeaways

### Step 4 — Add to articles/index.md

Open `articles/index.md` and add your article in the correct category section:

```
| your-topic-name.md | Your Topic Name | Category Name |
```

Categories currently in use: `System Design`, `Databases`, `Networking`, `Distributed Systems`, `Security`, `Architecture`.

### Step 5 — Open a Pull Request

Push your branch and open a PR against `main`. In the PR description include:
- What the article covers
- Which category it belongs to
- Any diagrams or special formatting used

---

## Requesting a Blog Company

Blog companies are listed in `blogs/index.md`. Each entry needs a company name, RSS feed URL, and website URL.

### Step 1 — Check if it Already Exists

Open `blogs/index.md` and search for the company name before submitting.

### Step 2 — Verify the RSS Feed

The company must have a working RSS feed. Common patterns:
```
https://engineering.company.com/feed
https://blog.company.com/rss
https://medium.com/feed/@companyname
https://company.com/blog/rss.xml
```

Test it by pasting the URL in a browser — you should see XML content.

### Step 3 — Add to blogs/index.md

Add a new row to the table:

```
| Company Name | https://company.com | https://company.com/blog/rss.xml |
```

### Step 4 — Open a Pull Request

Open a PR with title `[Blog] Add CompanyName` and include:
- Company name and website
- RSS feed URL (verified working)
- Brief note on why it's valuable for system design learners

---

## Guidelines

- Articles should focus on **system design**, **distributed systems**, **databases**, or **architecture**
- Minimum length: 800 words
- Diagrams are encouraged — use Mermaid syntax
- No promotional content or affiliate links
- English only

## Questions?

Open a GitHub Issue with the label `question` and the maintainer will respond.
