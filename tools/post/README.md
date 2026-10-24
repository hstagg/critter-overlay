# Posting queue

`post.py` takes a finished clip (from `tools/film/`) to TikTok, Instagram Reels
and YouTube Shorts through each platform's official API, with a person's
approval in between. The flow:

1. **Film** a clip with `tools/film/scene.ps1` (or cut one with `edit.py`).
2. **Stage** it with a title, caption and hashtags. `--when auto` takes the
   next free slot (`every_days` after the last post, at `slot`).
3. **Review**: open the post's file in the queue folder, edit the caption if
   you like, and tick `- [x] approve` (or `- [x] bin`). That tick is the only
   way a post goes out.
4. **Publish** runs on a schedule. Each approved post whose time has come is
   sent to each platform once; the result is logged at the bottom of its file
   and the ids go in `posted:`.

```powershell
python tools\post\post.py stage "$env:USERPROFILE\Videos\Critter Overlay\clip.mp4" `
    --title "Rare: Sea Otter" --caption "One of us is rarer than the rest." `
    --hashtags "#desktoppet #cozygames" --when auto
python tools\post\post.py list       # the schedule
python tools\post\post.py check      # every clip against the platforms' limits
python tools\post\post.py publish    # dry run: prints and logs what it would send
```

## Two locks

A run is a **dry run** unless both are true: it was started with `--live`, and
the platform is listed in the config's `"live"`. The config ships with
`"live": []`, so nothing is sent until the owner adds a platform. Approval is
needed either way. `--now` (treat approved posts as due) only works in a dry
run.

## Config

Copy `config.example.json` to `%USERPROFILE%\critter-post\config.json` (or pass
`--config`). Tokens are written beside it in `tokens.json`. Keep both out of
this repo.

- `queue`: the folder of post files (a synced folder makes review from a phone
  possible).
- `front`, `summary_key`: extra front-matter keys for the post files, if the
  folder has its own conventions.
- `youtube`, `tiktok`: the API app's client id and secret.

## Signing in (once per platform, by the account owner)

- **YouTube:** a Google Cloud project with the YouTube Data API v3 on, an OAuth
  client of type "Desktop app", the owner added as a test user. Then
  `post.py auth youtube`. Uploads from a project Google has not audited stay
  **private**; the audit form is in the API's quota pages.
- **Instagram:** a Professional (creator or business) account and a Meta app
  with "Instagram API with Instagram login" and the
  `instagram_business_content_publish` permission. Generate a token in the
  app dashboard, then `post.py auth instagram` and paste it.
- **TikTok:** a TikTok for Developers app with Login Kit and the Content
  Posting API (`video.upload` scope), redirect URI `http://127.0.0.1:8765/`.
  Then `post.py auth tiktok`. Clips land in the TikTok app's drafts; finish the
  post there, pasting the caption that `publish` prints and logs.

## Running it on a schedule

Once a platform is live, a Windows scheduled task runs the publisher every
hour:

```powershell
schtasks /Create /TN "Critter post" /SC HOURLY /TR "python \"C:\path\to\tools\post\post.py\" publish --live"
```

## Tests

`python -m unittest tools/post/test_post.py` (needs ffmpeg) runs the queue end
to end with the senders replaced, so it never touches the network.
