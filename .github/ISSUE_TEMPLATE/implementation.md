---
name: Implementation task
about: Dispatch an implementation task to Claude Code
title: ""
labels: ["automation"]
assignees: ""
---

## What to implement

<!-- Describe the change in plain English. Be specific about which files, 
     which behavior, and what the end state looks like. -->


## Acceptance criteria

<!-- Checklist of what "done" looks like. Claude Code uses this to verify. -->

- [ ] 

## Constraints

<!-- Anything Claude Code should NOT do, or boundaries to stay within. -->

- All three scripts must stay in sync for shared changes
- Every step must remain idempotent
- Do not modify unrelated code

## Auto-merge

When implementation is complete:
1. Run `shellcheck --severity=warning --shell=bash` on all modified scripts
2. Create a PR with a clear title and description referencing this issue
3. Enable auto-merge: `gh pr merge --auto --squash`

@claude implement this
