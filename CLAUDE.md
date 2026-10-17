# Elicit Pedigree — Claude Context

R/Kinship2 pedigree-drawing service exposed over HTTP by `plumber`
(`plumber.R`). FHHS calls it to render pedigree images; the umbrella compose
stack publishes it on port `8083`. There is no Java, Quarkus, Vaadin, or
Maven in this module; the image is built with `buildDockerImage.sh`.

## MCP Servers and Skills

- **IntelliJ IDEA (`idea` MCP server)** — when the workspace is open in the
  IDE, use `search_text`, `search_regex`, `read_file`, `get_file_problems`,
  and `execute_terminal_command` for navigation and checks. There is no
  `.run/` configuration for this module.
- **Quarkus (`quarkus-agent`) and Vaadin (`vaadin-skills`)** do not apply
  here; do not start dev mode or load those skills for this module.

## Git Commits

- `main` changes only through a pull request whose CI check (image build plus a smoke test
  of `/healthz` and `/svg`) passed; a ruleset enforces it on GitHub and
  `.claude/hooks/branch-guard.py` (a `PreToolUse` hook in `.claude/settings.json`) refuses
  `git commit` and `git push` on `main` locally. Branch as `<type>/<issue>-<slug>`; never set
  the hook's `ELICIT_ALLOW_PROTECTED` override yourself.
- Never append a `Co-Authored-By: Claude` (or similar AI co-author) trailer to
  commit messages.
