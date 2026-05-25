---
name: confluence-doc
description: Confluence REST API patterns for the Bide project wiki space. Use when creating or updating wiki pages, fetching existing pages by title, or syncing local docs into Confluence.
---

# confluence-doc

REST API recipes for Bide's Confluence space. Workspace: `grifjef-1773158363073.atlassian.net/wiki`. Space key: `BD`.

## Authentication

Same Atlassian API token as `jira-flow`:

```bash
export ATLASSIAN_EMAIL="grif.jef@gmail.com"
export ATLASSIAN_API_TOKEN="<token from id.atlassian.com>"
export CONFLUENCE_BASE="https://grifjef-1773158363073.atlassian.net/wiki"
```

curl boilerplate:

```bash
AUTH="-u ${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}"
H_JSON="-H Content-Type:application/json -H Accept:application/json"
```

## Find the space ID (one-time)

```bash
curl -sX GET $AUTH "$CONFLUENCE_BASE/api/v2/spaces?keys=BD" | python3 -m json.tool
# Note the "id" field — typically a numeric string. Set it as SPACE_ID:
export CONFLUENCE_SPACE_ID="<id from above>"
```

## Create a page

Confluence v2 API uses "storage" format (XHTML-like) for `body.storage.value`:

```bash
curl -sX POST $AUTH $H_JSON "$CONFLUENCE_BASE/api/v2/pages" -d "{
  \"spaceId\": \"$CONFLUENCE_SPACE_ID\",
  \"status\": \"current\",
  \"title\": \"Architecture\",
  \"body\": {
    \"representation\": \"storage\",
    \"value\": \"<h1>Bide Architecture</h1><p>SwiftUI app, iOS 17+, SwiftData index, MetricKit diagnostics.</p>\"
  }
}"
```

To nest under a parent page, add `"parentId": "<parent page id>"` to the body.

## Update an existing page

Confluence requires the current version to be passed when updating, to prevent lost edits:

```bash
PAGE_ID="<from create response or page URL>"

# 1. Get current version
CURRENT_VERSION=$(curl -sX GET $AUTH "$CONFLUENCE_BASE/api/v2/pages/$PAGE_ID" | python3 -c "import sys,json; print(json.load(sys.stdin)['version']['number'])")

# 2. Update with version+1
curl -sX PUT $AUTH $H_JSON "$CONFLUENCE_BASE/api/v2/pages/$PAGE_ID" -d "{
  \"id\": \"$PAGE_ID\",
  \"status\": \"current\",
  \"title\": \"Architecture\",
  \"version\": {\"number\": $((CURRENT_VERSION + 1))},
  \"body\": {
    \"representation\": \"storage\",
    \"value\": \"<h1>Bide Architecture</h1><p>Updated content here.</p>\"
  }
}"
```

## Find a page by title

```bash
curl -sX GET $AUTH \
  "$CONFLUENCE_BASE/api/v2/spaces/$CONFLUENCE_SPACE_ID/pages?title=Architecture" \
  | python3 -m json.tool
```

## Sync a markdown file to Confluence

Confluence's storage format is XHTML-based, not Markdown. Cleanest path: convert MD → HTML with `pandoc`:

```bash
brew install pandoc

md_to_confluence() {
  local md_path="$1"
  pandoc "$md_path" -f markdown -t html | python3 -c "
import sys, json
html = sys.stdin.read()
# Confluence storage format accepts most HTML; escape for JSON:
print(json.dumps(html))
"
}

# Usage:
BODY=$(md_to_confluence docs/architecture.md)
curl -sX POST $AUTH $H_JSON "$CONFLUENCE_BASE/api/v2/pages" -d "{
  \"spaceId\": \"$CONFLUENCE_SPACE_ID\",
  \"status\": \"current\",
  \"title\": \"Architecture\",
  \"body\": {\"representation\": \"storage\", \"value\": $BODY}
}"
```

## Storage format quick reference

Common Confluence-flavored XHTML tags:

```html
<h1>Heading 1</h1>
<h2>Heading 2</h2>
<p>Paragraph with <strong>bold</strong> and <em>italic</em>.</p>
<ul><li>Bullet</li></ul>
<ol><li>Numbered</li></ol>
<code>inline code</code>
<ac:structured-macro ac:name="code"><ac:parameter ac:name="language">swift</ac:parameter><ac:plain-text-body><![CDATA[
let bide = "calm photo review"
]]></ac:plain-text-body></ac:structured-macro>
<ac:structured-macro ac:name="info"><ac:rich-text-body><p>An info box.</p></ac:rich-text-body></ac:structured-macro>
<table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table>
```

## Seeding the BD space

For Phase 0 setup, create these pages (in order, to set up parent hierarchy):

1. **Bide Wiki** (root) — landing page with links
2. **Architecture** — tech stack, layers, SwiftData schema
3. **PhotoKit Usage** — auth, fetching, deletion, observer
4. **Safety Model** — risk tiers, protected categories
5. **Similar Photo Algorithm** — feature print + clustering
6. **Privacy Policy** — final copy for hosting
7. **App Store Listing** — name, subtitle, description, keywords
8. **Deployment Runbook** — TestFlight + App Store steps
9. **Testing Strategy** — XCTest, XCUITest, manual test matrix
10. **Decisions Log** — mirror of `docs/decisions.md` for non-Git-savvy reviewers

## Common gotchas

| Gotcha | Fix |
|---|---|
| 404 on POST `/api/v2/pages` | `spaceId` is wrong (must be numeric ID, not the "BD" key) |
| 409 Conflict on update | Version number didn't match — re-fetch current and retry |
| HTML renders as plain text | `representation` must be `"storage"`, not `"editor"` or `"view"` |
| Code blocks lose formatting | Use the structured-macro syntax above, not `<pre><code>` |
| `title` collision | Confluence titles are unique within a space — append " (v2)" or pick a new title |
| Pandoc converts `~~strikethrough~~` to something Confluence doesn't render | Use `<s>` or `<del>` directly |
