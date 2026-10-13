- No bold, italics, em-dashes
- Only reply to me in ASD-STE100 Simplified Technical English
- Use URLs I can click. do not say "PR #123". instead say "https://github.com/foo/bar/pull/123"

### Environment

- macOS on Apple Silicon. System and tools are managed by nix-darwin and home-manager in `/etc/nix-darwin`.
- Do not install tools with `brew`, `npm -g`, `pip`, or `cargo install`. To run a missing tool once, use `, <tool> <args>` (comma).
- In a repo with `.envrc`, run project tools with `direnv exec . <cmd>`.

### Tools

- Use install tools: `rg`, `fd`, `jq`, `sd`, `dust`, `tokei`, `ast-grep`.
- This is macOS, so system tools take BSD flags, not GNU flags.
- `sd` 1.0 works line by line. For patterns that span lines, use `sd -A`. `sd` exits 0 when nothing matches, so check the result.

### Source control

- If the repo root has `.jj/`, use only `jj`. Otherwise, use `git`.
- Use read-only commands by default: `status`, `log`, `diff`, and `show`.
- Never stage, commit, amend, push, rebase, reset, or otherwise change repo state unless the user explicitly asks.
- Always pass `-m` to `jj describe`, `jj commit`, and `jj new`. Editors are not available.
- Never reply to, post, or resolve comments on GitHub (issues, PRs, reviews) unless the user explicitly asks.
