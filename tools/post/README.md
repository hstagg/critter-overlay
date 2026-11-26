# Posting

`post.py` schedules a finished clip on TikTok, Instagram Reels and YouTube
Shorts. Nobody approves posts by hand. An automated QA gate checks each one,
and the live lock is the kill switch.

1. **Film** a clip with `tools/film/` and cut it with `edit.py`.
2. **Write the post spec**: a JSON file holding the clip's path and, for each
   platform, the words that go with it (the format is at the top of
   `post.py`).
3. **Run the QA gate.** It writes its verdict to `<clip>.qa.json` beside the
   clip. `ship` refuses a post unless that record says `"pass": true` for the
   same post and is newer than the clip, so a recut clip needs the gate again.
4. **Ship** it with one time per platform. TikTok and Instagram are scheduled
   through [Zernio](https://zernio.com) (a TikTok and Meta partner), and post
   on Zernio's side at the time. YouTube is uploaded straight away as private
   with `publishAt`, and YouTube makes it public at that time.

```powershell
python tools\post\post.py ship post.json `
    --tiktok 2026-11-27T18:00 --instagram 2026-11-27T19:00 --youtube 2026-11-27T17:00
python tools\post\post.py status tiktok <zernio post id>   # state, link and numbers
python tools\post\post.py status youtube <video id>
python tools\post\post.py accounts                         # what is connected in Zernio
```

Times are ISO 8601. A time without an offset is this computer's local time,
and every time must be in the future. `ship` prints one JSON line per
platform:

```json
{"post": "2026-11-27-desk-kittens", "platform": "tiktok", "id": "6745...", "scheduled": "2026-11-27T18:00:00+00:00", "status": "scheduled"}
```

The `status` is `scheduled`, `dry_run` (with the `plan`, and `needs` naming
anything a live send would lack), `refused` (the QA gate, the time or the
words) or `failed` (the platform's error). The `id` is the Zernio post id for
TikTok and Instagram, and the video id for YouTube. One platform failing
doesn't stop the others. The exit code is 1 if any platform was refused or
failed.

## Comments and replies

```powershell
python tools\post\post.py comments --since 2026-11-27T12:00Z          # all three platforms
python tools\post\post.py comments --platform tiktok
python tools\post\post.py reply youtube <comment id> --text-file reply.txt --live
python tools\post\post.py reply tiktok <comment id> --post <post id> --text-file reply.txt --live
```

`comments` prints one JSON line for each comment someone else left on our
posts. Each line has:

- `platform`, `post_id`, `comment_id`
- `author` and `text`
- `time`
- `replied`: true if one of our replies shows under the comment, or if
  `replies.jsonl` records one
- `url`, where it's known

A platform it can't read prints `{"platform", "error"}`, and the others still
list. The exit code is then 1.

- **YouTube:** reads `commentThreads` across the channel, up to 500 threads,
  newest first.
- **TikTok and Instagram:** read through Zernio's comment inbox, from the 20
  most recent posts that have comments (`--posts` changes this). The reads are
  spaced a second apart to stay inside Zernio's rate limit. On TikTok it needs
  the account connected through Zernio's Business app. A developer-app
  connection can't read or reply to comments.

`reply` sends one reply. It uses the same live lock as `ship`, so it's a dry
run unless the run has `--live` and the platform is listed in `"live"`.
TikTok and Instagram also need `--post`, the `post_id` from `comments`. Every
reply sent is written to `replies.jsonl` beside the config. `reply` refuses
in these cases:

- a second reply to the same comment
- more than 30 replies in 4 hours (one run's worth, at three runs a day)
- an empty reply
- a reply over the platform's length: 150 characters on TikTok, 2,200 on
  Instagram, 10,000 on YouTube

## The live lock

A platform is really sent only if both of these are true:

- the run was started with `--live`
- the platform is listed in the config's `"live"`

Anything else is a dry run, which prints the plan and touches no network. The
config ships with `"live": []`. Taking a platform out of `"live"` stops it at
once, even for scheduled runs. Posts already scheduled on Zernio or YouTube
still go out unless they are deleted there.

A retry of the same post, platform and time sends the same `Idempotency-Key`,
so within 24 hours Zernio returns the first post instead of making a second.

## Config

Copy `config.example.json` to `%USERPROFILE%\critter-post\config.json`, or
pass `--config`. Tokens are written beside it in `tokens.json`. Keep both out
of this repo. `ship` works without a config, but only as a dry run.

- `live`: the platforms that may really be sent.
- `zernio.api_key`: from Zernio's dashboard (API keys).
- `zernio.accounts`: optional. Each platform's Zernio account id, for when
  more than one is connected. Otherwise `ship` uses the one active account
  for the platform.
- `zernio.profile_id`: optional. Limits `comments` to one Zernio profile.
- `zernio.tiktok`: overrides for TikTok's settings. The defaults are public,
  comments, duets and stitches on, and disclosed as "Your brand", since the
  account promotes its own app. `ship` also confirms TikTok's preview and
  consent step, which the QA gate stands in for.
- `zernio.instagram`: optional `platformSpecificData` for Reels, such as
  `{"shareToFeed": true}` (the default) or `{"thumbOffset": 1500}`.
- `google`: the Google OAuth client's JSON (YouTube and Gmail). `gmail`: the
  one account Gmail may use, and whether it may send.

## Setting up (once, by the account owner)

- **TikTok and Instagram:** make a Zernio account, connect the TikTok account
  and the Instagram Professional (creator or business) account, and create an
  API key. Zernio's free tier covers two connected accounts. Put the key in
  the config, then check with `post.py accounts`.
- **YouTube:** one Google Cloud project shared with Gmail. The steps are in
  `tools/gmail/README.md`. You need:
  - the YouTube Data API v3 and the YouTube Analytics API turned on
  - a "Desktop app" OAuth client, whose JSON is named in the config as
    `"google": {"client_file": ...}`
  - the consent screen set to "In production". While it says "Testing",
    Google expires the sign-in after 7 days.

  Then run `post.py auth google`. This one sign-in covers YouTube and Gmail.
  It also lets the marketing collector read the channel's statistics and
  analytics, and reply to comments.

## Running it on a schedule

The marketing department's runs call `ship` for each post they schedule, and
record the ids it prints. Nothing here runs on a timer by itself.

## Tests

`python -m unittest tools/post/test_post.py` runs everything with the network
replaced, so it never sends. The Tests workflow runs it on every pull request.

## History

Until November 2026 the tool kept a queue of Markdown files, each with an
approve tick box that a person had to tick. TikTok clips went to the app's
drafts, and Instagram went through the Graph API directly. All three were
replaced by the QA gate, the live lock and Zernio, and that code was removed.
The last version with it is in git history.
