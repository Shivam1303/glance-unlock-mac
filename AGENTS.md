# Agent instructions

## Git commit identity

- Always create commits with Shivam's GitHub identity for both author and committer:
  - Name: `Shivam1303`
  - Email: `87218769+Shivam1303@users.noreply.github.com`
- Preserve this identity in the repository's Git settings. Never substitute Codex, OpenAI, an agent, or a bot as the author or committer.
- Do not add agent or bot co-author trailers unless Shivam explicitly requests them.
- Check `git var GIT_AUTHOR_IDENT` and `git var GIT_COMMITTER_IDENT` before committing, and verify the resulting commit's author and committer afterward.
- This identity rule does not authorize a commit or push by itself; follow Shivam's request for when to commit and push.
