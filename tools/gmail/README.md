# Gmail for the project account

`gmail_mcp.py` is a small local MCP server that gives Claude Code the
project's own Gmail: **search**, **read**, **labels**, **label**, **draft**
and **send**. It is registered for one project only, so no other Claude
session sees it, and it uses the same Google sign-in as YouTube uploads in
`tools/post/`. Standard library only, talking to Gmail's REST API directly.

## Guards

- **One account.** Set `"gmail": {"account": "you@example.com"}` in the
  config and every call checks the signed-in address against it. A token for
  any other account is refused, and `post.py auth google` won't save one.
- **No sending** until `"gmail": {"send": true}`. Until then `send` refuses
  and drafts wait in Gmail's Drafts for a person to send. Claude Code also asks
  before each MCP tool call unless it has been allowed.
- **Secrets stay out of the repo.** The OAuth client JSON and `tokens.json`
  live beside the posting config (`%USERPROFILE%\critter-post\`), and
  `.gitignore` refuses them anyway.

## Setup (once)

One Google Cloud project serves both Gmail and YouTube:

1. Signed in as the project's Google account, create a Cloud project.
2. Enable the **Gmail API** and the **YouTube Data API v3**.
3. Google Auth Platform: app name, support email, audience **External**,
   then add the project address as a **test user**.
4. Create an OAuth client of type **Desktop app** and download its JSON to
   the path named in the config as `"google": {"client_file": ...}`.
5. `python tools\post\post.py auth google`. Sign in as the project account
   and allow both (upload to YouTube, read and send Gmail).
6. Register the server in this project only:

   ```powershell
   claude mcp add --scope local gmail-critter -- python C:\path\to\tools\gmail\gmail_mcp.py
   ```

While the Cloud project's audience is in **Testing**, Google expires the
sign-in after 7 days, and step 5 has to be run again. Publishing the app
(Audience › Publish app) ends that. Google then shows an "unverified app"
warning at sign-in, which is fine for your own account.

## Tests

`python -m unittest tools/gmail/test_gmail.py` runs every tool against a fake
Gmail, plus a real stdio handshake. It never touches the network.
