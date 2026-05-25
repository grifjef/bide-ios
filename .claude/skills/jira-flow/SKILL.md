---
name: jira-flow
description: Jira REST API patterns for the Bide project. Use when creating issues, transitioning status, adding comments, or querying issues against grifjef.atlassian.net. Project key BD.
---

# jira-flow

REST API recipes for Bide's Jira project. Workspace: `grifjef.atlassian.net`. Project key: `BD`. User: `grif.jef@gmail.com`.

## Authentication

Set up once:

```bash
# Get token from https://id.atlassian.com/manage-profile/security/api-tokens
export ATLASSIAN_EMAIL="grif.jef@gmail.com"
export ATLASSIAN_API_TOKEN="<token from id.atlassian.com>"
export JIRA_BASE="https://grifjef.atlassian.net"
```

Add to `~/.zshrc` for persistence (never commit `.zshrc` with the token!).

For curl:

```bash
AUTH="-u ${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}"
H_JSON="-H Content-Type:application/json -H Accept:application/json"
```

## Create an issue

```bash
curl -sX POST $AUTH $H_JSON "$JIRA_BASE/rest/api/3/issue" -d '{
  "fields": {
    "project": {"key": "BD"},
    "summary": "Implement Large Videos scan + delete flow",
    "description": {
      "type": "doc", "version": 1,
      "content": [{"type": "paragraph", "content": [{"type": "text", "text": "Scan video assets, sort by size, present review cards, batch-select into Review Basket, delete via PHAssetChangeRequest."}]}]
    },
    "issuetype": {"name": "Task"}
  }
}' | python3 -m json.tool
```

To assign an Epic at create time, add to `fields`:

```json
"customfield_10014": "BD-1"
```

(Epic Link is `customfield_10014` on default Jira Cloud; verify in your instance via `/rest/api/3/field`.)

## Create an Epic

```bash
curl -sX POST $AUTH $H_JSON "$JIRA_BASE/rest/api/3/issue" -d '{
  "fields": {
    "project": {"key": "BD"},
    "summary": "Large Videos Module",
    "issuetype": {"name": "Epic"}
  }
}'
```

## Transition status

First, list available transitions for the issue:

```bash
curl -sX GET $AUTH $H_JSON "$JIRA_BASE/rest/api/3/issue/BD-42/transitions"
```

Then transition (use the `id` from the response):

```bash
curl -sX POST $AUTH $H_JSON "$JIRA_BASE/rest/api/3/issue/BD-42/transitions" -d '{
  "transition": {"id": "21"}
}'
```

Typical transition IDs (verify against your workflow):
- `11` — To Do
- `21` — Dev In Progress
- `31` — Test In Progress
- `41` — In Review
- `51` — Done

## Add a comment

```bash
curl -sX POST $AUTH $H_JSON "$JIRA_BASE/rest/api/3/issue/BD-42/comment" -d '{
  "body": {
    "type": "doc", "version": 1,
    "content": [{"type": "paragraph", "content": [{"type": "text", "text": "Implemented in PR #5"}]}]
  }
}'
```

## Search / JQL

```bash
# All open issues assigned to me
curl -sX GET $AUTH "$JIRA_BASE/rest/api/3/search?jql=project=BD%20AND%20assignee=currentUser()%20AND%20statusCategory!=Done"

# All issues in current sprint
curl -sX GET $AUTH "$JIRA_BASE/rest/api/3/search?jql=project=BD%20AND%20sprint%20in%20openSprints()"
```

## Quick-create wrapper script

Drop this in `~/.zshrc` or `scripts/`:

```bash
jira-new() {
  local summary="$1"
  local description="${2:-}"
  curl -sX POST -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
    -H Content-Type:application/json \
    "$JIRA_BASE/rest/api/3/issue" \
    -d "{
      \"fields\": {
        \"project\": {\"key\": \"BD\"},
        \"summary\": \"$summary\",
        \"description\": {\"type\": \"doc\", \"version\": 1, \"content\": [{\"type\": \"paragraph\", \"content\": [{\"type\": \"text\", \"text\": \"$description\"}]}]},
        \"issuetype\": {\"name\": \"Task\"}
      }
    }" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('key', d))"
}

# Usage: jira-new "Fix screenshot grid jitter" "Cells re-render when scrolling fast"
```

## Common gotchas

| Gotcha | Fix |
|---|---|
| 401 Unauthorized | Token expired (180 days) or wrong email — regenerate at id.atlassian.com |
| 400 on issue create with "Field 'customfield_10014' cannot be set" | Epic Link custom field ID differs per workspace — query `/rest/api/3/field` to find yours |
| 400 on description | API v3 requires ADF (Atlassian Document Format) — wrap text in `{type: doc, content: [...]}` |
| Transitions list returns empty | Issue is in a status with no outgoing transitions OR you lack edit permission |
| `status` is read-only | Use `transitions` endpoint, not `PUT` on the issue |
