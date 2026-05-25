## Summary

<!-- 1–3 sentences describing what this PR does and why. Focus on the *why* — the diff shows the *what*. -->

## Linked Jira

<!-- e.g. BD-42 -->

## Changes

-

## Testing

- [ ] Build passes locally (`xcodebuild build -scheme Bide ...`)
- [ ] Unit tests pass (`xcodebuild test -scheme Bide ...`)
- [ ] Manually tested on Simulator
- [ ] If touches PhotoKit: tested with **limited library access AND full access**
- [ ] If touches deletion: verified Recently Deleted recovery works end-to-end
- [ ] If touches scan logic: tested on a library with 1k+ items

## Bide product principles checklist

- [ ] No "Delete forever" language — use "Move to Recently Deleted"
- [ ] No scare or urgency tactics in copy
- [ ] Conservative defaults preserved (favorites, hidden, <30d, edited, Live Photos, faces, album-tagged)
- [ ] All recommendations explainable in plain language ("Suggested because…")
- [ ] VoiceOver labels added to new interactive elements
- [ ] Dynamic Type tested (XL, XXL accessibility sizes)
- [ ] No third-party SDKs added that touch user data

## Documentation

- [ ] Updated `PLAN.md` / `CLAUDE.md` if architecture or commands changed
- [ ] Updated relevant Confluence page (BD space)
- [ ] Updated `docs/decisions.md` if this resolves a previously-open decision

## Reviewer notes

<!-- Anything reviewers should focus on, or any rough edges you're aware of. -->
