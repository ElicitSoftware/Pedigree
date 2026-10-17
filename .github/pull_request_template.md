<!--
  One pull request per issue, from a branch named <type>/<issue>-<slug> off main.
  Title: what the change does, in the imperative, without the issue number.
  Tick every line that applies; strike one through (~~like this~~) with a reason when it does not.
  An unticked, unstruck line is a question the reviewer will ask.
-->

## Issue

Closes #

## What changed and why

<!-- Two to five sentences. Behavior first, implementation second. -->

## Checks

- [ ] `README.md` updated when the API, the input format or the build changed
- [ ] `ped1.txt` still renders (the CI smoke test posts it to `/svg`)
- [ ] A change to the `/svg` contract was checked against FHHS, its only caller
- [ ] A `Dockerfile` change still builds for `linux/amd64` and `linux/arm64` (the release workflow pushes both)
- [ ] Cross-module change: the tracking issue in `ElicitSoftware/Elicit` and the sibling PRs are linked above
- [ ] No AI co-author trailer in any commit message
