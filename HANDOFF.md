# HANDOFF — CDP Share Project features on the MUToday Chatwoot fork

Source of truth for the requirement: `CDP Share Project - Dev Spec.pdf` (v1.4) and the
mockup `CDP Share Project.html`. Three features were asked for:

1. **Live chats รวมทุก project** — one inbox across every project, with a per-project sub-menu
2. **ระบบ assign auto** — automatic assignment of incoming chats to agents
3. **ระบบนับถอยหลัง** — a countdown on chats the customer has been waiting on too long, configurable

Delivery shape agreed with the requester: **one PR per feature**.

---

## 2026-09-22 — SECURITY AUDIT of production: keep running, 3 urgent items · Fable 5.1

**Verdict.** `support.mutoday.com` (4.17.0, `develop` head `c01c61da1`) is safe to keep using. The
public surface is properly guarded and the fork's own code has no exploitable defect. The weak spots
are an out-of-date Chatwoot and user/permission hygiene — none need new code, all need a decision.
Report for non-technical readers (Thai, with a flow diagram): https://claude.ai/artifact/2NPwCXF4cPua1uqm41Csow
(private link — share from the page's Share menu).

**How it was checked.** Read-only: the 143-file fork diff vs `upstream/develop`; `bundle-audit`
(db 2026-09-16), Brakeman (35 warnings, all upstream code, all FP/mitigated on inspection),
`pnpm audit --prod`; every commit between `v4.17.0` and `v4.18.0` that touches auth/sanitising/
webhooks; public probes of the live site (headers, `/api`, `/super_admin`, `/sidekiq`, `/.env`,
login-page `signupEnabled`). Then a 9-dimension Workflow — one sonnet finder + one fresh-context
opus verifier per dimension, 18 agents, 0 errors — and the high/medium items re-verified by hand
with `git merge-base --is-ancestor`. **No server access from the Mac used** (no SSH key; the
`mu-support` folder is not on that machine or in the GitHub org), so everything server-side is
listed under "not verifiable" below rather than guessed. The procedure is saved as the local skill
`security-audit-fork` for the next round.

### Urgent (within two weeks)

1. **Upgrade to v4.18.0 (released 2026-09-18).** Three upstream security fixes are confirmed
   absent from `develop` (`git merge-base --is-ancestor <sha> develop` → no; all three are in
   v4.18.0 only, not v4.17.1):
   - `7d581dc8c` — sign-in with `email`/`password` sent as **HTTP headers** skips
     `find_user_for_authentication` in `app/controllers/devise_overrides/sessions_controller.rb`,
     so MFA and the MAX_USER_SESSIONS check are bypassed; devise_token_auth then authenticates from
     the headers. Anyone holding a valid password logs in without the second factor. **High.**
   - `aad2791b4` — `MacrosExecutionJob` runs a macro against any `display_id` in the account with no
     `ConversationPolicy#show?` check; macro actions include `send_message` and `send_webhook_event`
     to an author-supplied URL. Medium today (one inbox, everyone is a member), high the moment a
     second inbox or narrower membership exists.
   - `4218dc679` — markdown renderer emitted `javascript:`/`data:`/`vbscript:` hrefs and img srcs
     unfiltered; reachable via the conversation-reply/transcript mailer templates. Medium.
   Upgrade preconditions checked: 4 additive migrations (`20260811000000`, `20260811000001`,
   `20260813000000`, `20260831000000`), upstream `NOTIFICATION_TYPES` still stops at 8 so the
   fork's `all_conversations_new_message: 9` does not collide, `.ruby-version`/`.nvmrc` unchanged,
   only new env is `SLACK_SIGNING_SECRET` (unused here). Path: `git merge v4.18.0` into `develop`
   (real merge, fork carries 77 commits) → `./upgrade.sh v4.18.0-mutoday` (migrations → needs the
   backup step).
2. **Account hygiene.** All 14 users are LINE inbox members and in the auto-assign pool, including
   the vendor/developer accounts (7solutions, 7ideasgroup, seedwebs, 7dayssuccess). Remove non-CS
   accounts from the inbox or deactivate them; rotate passwords on any vendor account that stays;
   confirm none holds `administrator`.
3. **Turn on 2FA for every administrator and the super admin — after item 1.** There is no
   account-wide enforcement in the codebase (`otp_required_for_login` is only set by the user's own
   opt-in in `app/services/mfa/management_service.rb`), so it is per-person plus periodic drift
   checks. Before item 1 lands, 2FA is bypassable per `7d581dc8c`.

### Should do (this month)

- Restrict `/super_admin` at Caddy to office/VPN IPs. It is reachable from anywhere; the only gates
  are the password and Rack::Attack (5/5 min per IP, 5/15 min per email).
- Off-site, encrypted backups. `upgrade.sh` dumps to `backups/` on the same VPS as Postgres, Redis
  and the attachment volume.
- Confirm `ACTIVE_RECORD_ENCRYPTION_*` is set in prod `.env`. If not, `Channel::Line`
  `line_channel_secret`/`line_channel_token` and every `integrations_hooks.settings` secret (Lark
  `secret`, faq `api_token`) are plaintext in Postgres. Enabling only encrypts on next save — re-save
  existing rows afterwards.
- If a Lark hook is enabled, add Lark as a sub-processor in the PDPA notice: the service sends
  `contact.name` and up to 1,000 chars of message text to the Lark webhook.
- `.bundler-audit.yml`: nine ignores are for CVEs already patched at the pinned `rails 7.2.3.1`
  (their own comments say "remove once on 7.2.3.1+"), and `CVE-2026-66066` (Active Storage/libvips,
  CVSS 9.5, patched in 7.2.3.2) is ignored under the same stale condition, so CI cannot surface it.
  Currently mitigated by `VIPS_BLOCK_UNTRUSTED` in `docker/Dockerfile:134`; drop the nine, bump to
  7.2.3.2, and re-word the remaining ignore with the real compensating control.
- `Webhooks::LineController` enqueues a Sidekiq job for every request and only verifies the HMAC
  inside the job (upstream behaviour). Add a dedicated Rack::Attack throttle for `/webhooks/line`.
- Long term: Rails 7.2 left security support on 2026-08-09 and upstream 4.18.0 is still on 7.2.3.1,
  so track upstream releases closely and watch for the move to Rails 8.

### Verified clean (no action)

HTTPS everywhere with 2-year HSTS · LINE webhook HMAC check is fail-closed
(`Webhooks::LineEventsJob#valid_post_body?`) · Rack::Attack on by default in production · password
policy 6–128 + upper/lower/digit/special · signup disabled · `/sidekiq`, `/rails/info/*`, `/.env`,
`/.git/HEAD` all 404 · the fork's Projects / LiveChatRules / extend_reply_deadline /
agent_daily_matrix endpoints are correctly scoped (admin-only writes, `assigned_inboxes` filter,
`ReportPolicy#view?`); the only gap is that `project_id` on Inbox/LiveChatRule is not validated
against `Current.account` — a cross-tenant FK nuisance that cannot leak data and is unreachable on a
single-account install · no XSS sinks in the 66 changed frontend files; the attachment preview
modal renders only the agent's own outgoing upload · `MutodayFaqReplyJob` is still the T3 stub
(logs a line, calls no LLM, sends nothing) · the `ruby_llm` ReDoS advisory (CVE-2026-67991) does
not apply: the vulnerable `Utils.underscore` does not exist in the installed 1.15.0.

### Not verifiable from here — run on the server, read-only, values masked

```sh
cd /opt/mu-support
awk -F= '/^(FORCE_SSL|ENABLE_RACK_ATTACK|ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY)=/{print $1 "=" ($2=="" ? "<empty>" : "set")}' .env
docker compose config | grep -A2 'ports:'      # postgres/redis should bind 127.0.0.1 only
ufw status                                     # expect 22, 80, 443 only
ls -la backups/ | tail -5
docker compose exec -T postgres psql -U postgres -d chatwoot_production \
  -c "SELECT count(*) FILTER (WHERE otp_required_for_login) AS mfa_on, count(*) AS users FROM users;" < /dev/null
docker compose exec -T postgres psql -U postgres -d chatwoot_production \
  -c "SELECT app_id, status, created_at FROM integrations_hooks;" < /dev/null
```
The live `Set-Cookie` already carries `secure; httponly; samesite=lax`, so `FORCE_SSL` is very
likely `true` — confirm rather than assume.

**Next:** merge v4.18.0 (new session, Opus) → `upgrade.sh` → re-check the three fixes are in the
running image (`git merge-base --is-ancestor 7d581dc8c HEAD` in `/opt/mu-support/src`) → then the
account clean-up and 2FA roll-out. Re-audit when the Facebook inbox goes live and when the faq
ReplyService (T9) ships.

---

---

## 2026-09-22 — Facebook (Messenger) connected to production · Fable 5.1

**Result.** Inbox #2 "MUToday" (`Channel::FacebookPage`, page_id `1155390994323924`, page "MUToday - มูทูเดย์")
created 08:47 UTC through the normal Add-inbox → Facebook flow. Page is subscribed to the app with all six
fields Chatwoot asks for (`messages message_deliveries message_echoes message_reads standby messaging_handovers`
— verified read-only via Graph `/<page>/subscribed_apps` with the stored page token). Placed under project
**MUToday**, membership mirrored from the LINE inbox (14 agents), auto-assign on. Both inboxes are now named
"MUToday" (Line / Messenger) — consider renaming the Messenger one.

**Meta app.** "MUToday Support", App ID `1100184342479006`, use case Messenger, business portfolio
**Motoday ACC** (chosen because it carries the MU logo — unverified assumption; switchable in App settings →
Basic). Mode: Development → only people with a role on the app (admin/developer/tester) can message the page
until `pages_messaging` gets Advanced Access (Business Verification + App Review). Webhook:
`https://support.mutoday.com/bot`, verified by Meta from `173.252.78.23` at 08:21 UTC.

**Server config.** `FB_APP_ID`, `FB_APP_SECRET` (32 chars), `FB_VERIFY_TOKEN` (48 hex, generated on the
server), `FACEBOOK_API_VERSION=v21.0` (was `v18.0`, expired 2026-01-26 per Meta's changelog). Values live in
`/opt/mu-support/.env` **and** `installation_configs`. Two gotchas found on the way:
- `GlobalConfigService.load` only falls back to ENV when no `installation_configs` row exists — but
  `ConfigLoader` seeds an **empty row for every key**, and `first_or_create` then returns that empty value. So
  `.env` alone does nothing for these keys on this install. Write the row (what Super Admin does), e.g. from
  inside the container: `InstallationConfig.find_or_initialize_by(name: k).tap { |c| c.value = ENV[k]; c.save! }`
  then `GlobalConfig.clear_cache`. `/opt/mu-support/set-fb-secret.sh` does exactly this for the secret (prompts
  with `read -s`; nothing passes through chat or argv).
- The Facebook card in Add-inbox is enabled by `channel_facebook` **and** a non-empty `FB_APP_ID`
  (`ChannelItem.vue:39`); the login page's `fbAppId: '…'` is the quick check.

**Login error 1349048 ("domain not in App Domains") even with App Domains set.** An app created through the
Messenger use case has no **Facebook Login** product, so the JS-SDK login is refused regardless of App Domains.
Fix: add the Facebook Login product (dashboard "ตั้งค่า" link, `product_route=fb-login`; the async URL typed
directly returns a blank page and adds nothing — click the real link), then in its Settings: **Login with the
JavaScript SDK = Yes** (click the visible switch, not the hidden checkbox), **Allowed Domains for the JavaScript
SDK** `https://support.mutoday.com`, **Valid OAuth Redirect URIs** `https://support.mutoday.com/`. Verified by
loading the same `dialog/oauth` URL the button uses: consent screen instead of the error. Also: a popup opened
by a scripted click is blocked by Chrome — the requester has to click "Continue with Facebook" themselves.

**Not done / next.** (1) Live test: a message from an app-role account to the page → conversation in inbox #2
(watcher was armed; result below when known). (2) `public_profile` and `pages_messaging` Advanced Access:
Business Verification for Motoday ACC + App Review with a screencast — the requester's task; until then real
customers cannot reach the page through Chatwoot. (3) Optional: rename inbox #2.

---

## 2026-09-22 — DEPLOYED: PRs #22 #23 #24 #25 in one build · Fable 5.1

**Merged, in order:** #22 (unread badge on the contact's picture) → #23 (contact panel opens from the
picture; floating `SidepanelSwitch` removed) → #24 (LINE: skip an event whose `message.id` is already a
`source_id`) → #25 (existing user gets their Google picture on sign-in). `develop` head
`545731177e52e2a90aafa1b4d6dad575bb77e8d5`. 15 files, 0 migrations, no dependency change.

**CI gate:** all four green except the known `security-scan` (`ruby_llm` advisory, see 09-21 entry);
none of the four touches `Gemfile.lock`. Merged only after every check on all four had finished — one build
for four PRs means one rollback point for four changes.

**Deploy:** `./build.sh v4.17.0-mutoday` → `docker compose up -d` at 07:00 UTC. Image checked before the
flip and the flip gated on it: `.git_sha` = develop head · `already_received?` present in the LINE
service · `fetch_avatar_from_provider` present in the omniauth controller · new bundle
`dashboard-Dbws_ZuN.js` carrying the badge's `ring-n-background`. After: rails/sidekiq Up · `/api`
ok/ok · new bundle 200, old `dashboard-CvVLNlmy.js` 404 · both private methods present in the **running**
app · the single "error" in the logs was my own 404 probe of the old bundle.

**Rollback:** `chatwoot/chatwoot:v4.17.0-mutoday-pre-4prs` (`.git_sha c01c61da1`).

**What the requester does next, in this order:** (1) LINE Developers Console → channel 2008480970 →
Messaging API → **Webhook redelivery** ON — safe now that #24 is live; (2) each agent clicks **Sign in with
Google** once → picture within ~1 min (`AvatarFromUrlJob`, `purgable` queue); 7ideasgroup.com (Lark) agents
upload or use gravatar.com; (3) each agent grants browser notification permission (12/14 still have none).

**Gotchas (new).** `pgrep -f "docker build …"` wrapped in `bash -c "…"` matches the wrapping shell and never
exits — run pgrep directly under `sudo -n`, or check `build เสร็จ` as the log's last line. A
`git checkout develop && git pull` chain stops silently on a dirty tree and anything chained after with `;`
runs on the wrong branch. **Two sessions were sharing this checkout:** a security-audit session had an
uncommitted HANDOFF entry here; it is preserved on local branch `keep/security-audit-handoff` and left in the
working tree uncommitted for that session to commit itself — do not `reset --hard` this tree without checking
`git status` first.

---

## 2026-09-22 — DEPLOYED: project unread badge (PR #21) · unread counts switched on · LINE/push findings · Opus 5 → Fable 5.1

**Merged:** PR #21 → `develop` head `c01c61da19f675d5dac5d81f29a19d8efd814373`.

**What shipped.** A project's rolled-up unread count now sits on the project row itself while its
channels are folded (`SidebarGroupSeparator` renders `SidebarUnreadBadge`; `SidebarSubGroup` only hands
it over while folded so a number is never on screen twice), and on the project row in the icon-rail
popover, where groups start folded and previously showed no counts at all. All-conversations, per-project
"All channels" and per-channel badges were already wired — they just needed the feature flag.

**Account feature enabled on production:** `conversation_unread_counts` (account 1). It is **not** in
`enterprise/config/premium_features.yml`, so the nightly `ReconcilePlanConfigService` leaves it alone, and
`enable_default_features` is a `before_create` that only ever enables. `unread_count_for_filters` left off —
it only feeds folders/mentions/participating/unattended, which this sidebar hides.

**Deploy:** `./build.sh v4.17.0-mutoday` then `docker compose up -d` at 05:52 UTC. No migrations.
Rollback image `chatwoot/chatwoot:v4.17.0-mutoday-pre-project-badge` (`.git_sha cdf87a5e1`).
Verified: rails/sidekiq Up · container `.git_sha` = develop head · `/api` ok/ok · served bundle
`dashboard-CvVLNlmy.js` (old `dashboard-Cxa3Nv5j.js` 404s) · no errors in logs.

**Build-watch gotcha:** the build log always contains
`ERROR -- : Failed to configure AI Agents SDK: connection to server ... port 5432 failed` during
`assets:precompile` (no DB at build time). Grepping the log for `ERROR` exits early. Watch the process
instead: `until ! pgrep -f "docker build -f src/docker"; do sleep 30; done`.

### Why LINE messages "don't notify" — two independent causes, neither a code bug

1. **LINE webhooks reach the server only ~70% of the time.** No incoming message in the DB after
   2026-09-21 08:12 UTC although the requester sent four tests. Zero `POST /webhooks/line` in 24h of
   Rails logs, while a probe from Thailand is logged and rejected by the signature check (so logging
   works). LINE's own `POST /v2/bot/channel/webhook/test`: 8 of 27 attempts `COULD_NOT_CONNECT` /
   `REQUEST_TIMEOUT`, in bursts. LINE-side config is correct (`endpoint` right, `active: true`,
   `chatMode: bot`; `markAsReadMode: auto` is why the customer sees "อ่านแล้ว" — nobody read it).
   Server is idle (load 0.19, 4.5 GB free), ufw opens 80/443 to all, no fail2ban, no AAAA record,
   30/30 probes from Thailand succeed. tcpdump shows LINE's SYNs (147.92.149.0/24 and others — the
   source IPs rotate) sometimes arrive and still fail, sometimes never arrive. Hetzner `ap-southeast`.
   **Fix the requester must do:** LINE Developers Console → Messaging API → enable **Webhook redelivery**
   (docs: disabled by default; redelivers when no 2xx was received). Lost messages cannot be recovered —
   LINE has no fetch API. Robust fix if it persists: Cloudflare in front, or a Hetzner ticket.
2. **Almost nobody can receive a push.** All 14 users have `push_all_conversations_new_message` on (set
   2026-09-21 13:57 UTC for 13 of them — which is why message #376, earlier that day, only notified
   Chon). But only 2 users have any `NotificationSubscription`: Chon (`browser_push`, test push
   `SENT OK`) and Menn (`fcm` — undeliverable, `FCM_SERVER_KEY`/`FCM_PROJECT_ID` unset). VAPID keys are
   set. `push_assigned_conversation_new_message` is off for 13 of 14. Each agent has to grant browser
   notification permission themselves; nothing server-side can do it for them.

The reopen path is fine: `Message#reopen_conversation` flips a resolved conversation back to `open` on
any incoming message, so "closed cases don't re-notify" reduces to the two causes above.

### Profile pictures "from email" — already on, nothing to pull

`DISABLE_GRAVATAR` is unset, `Avatarable#fetch_avatar_from_gravatar` runs after save. Checking
`gravatar.com/avatar/<md5>?d=404` for all 14 users: **1 has a picture (Menn — that is his avatar), 13
return 404.** Corporate addresses with no gravatar.com account yield nothing. Options: register at
gravatar.com per person (picked up automatically), upload in profile settings, or a Google Workspace /
M365 directory-photo integration (admin credentials + real work).

### In flight: `feat/unread-badge-on-avatar` → PR #22

### In flight: `feat/google-avatar-for-existing-users` → PR #25

`DeviseOverrides::OmniauthCallbacksController#sign_in_user` (and the SAML `sign_in_user_on_mobile`, which
the enterprise override calls) now enqueue `Avatar::AvatarFromUrlJob` with `auth_hash.info.image` when
`@resource.avatar` is not attached — sign-up already did this for new users only. Uploaded picture always
wins (the requester's rule). Two request specs added; 11/11 green locally, rubocop clean.
Spec gotcha found on the way: on Rails 7.2, `user.avatar.attach(io:)` on a persisted record does **not**
write the attachment row until the record is saved again (same instance says `attached? == true`, a fresh
`find_by` says false, 0 rows). Give the avatar at `create(:user, avatar: Rack::Test::UploadedFile…)` instead,
or `save!` after `attach`. Both verified with a rolled-back probe in the test DB.
Recommended order for the requester: deploy → each agent clicks "Sign in with Google" once → picture appears
within a minute (`AvatarFromUrlJob` on the `purgable` queue). 7ideasgroup.com is on Lark, not Google: those
two agents upload a picture or register at gravatar.com.

### In flight: `fix/line-dedupe-redelivered-events` → PR #24 (prerequisite for LINE Webhook redelivery)

`Line::IncomingMessageService` built a message for every event; `message.id` went into `source_id` but was
never checked, and `index_messages_on_source_id` is not unique. LINE's docs: with redelivery on "the same
webhook event may be sent to your bot server more than once" and order is not guaranteed. The service now
skips an event whose id is already a `source_id` in the inbox (same pattern as the IMAP fetcher). Spec added,
11/11 green locally (rspec now runs on this Mac: Ruby 3.4.4 via rbenv, `RAILS_ENV=test rails db:prepare`).
Prod baseline: 0 duplicate `source_id`s across 205 incoming LINE messages. **Merge and deploy this before
the requester flips Webhook redelivery on**, otherwise every resent event becomes a second message.

Also verified: Google OAuth is already configured on prod (3 env vars set, login page shows the button) and
6 of the 7 team mail domains are Google Workspace (MX aspmx.l.google.com; 7ideasgroup.com is Lark). But
`omniauth_callbacks_controller` only fetches the Google picture in `create_account_for_user` — an existing
user signing in with Google gets nothing. Candidate fork change: enqueue `Avatar::AvatarFromUrlJob` with
`auth_hash['info']['image']` for an existing resource whose avatar is not attached (uploaded picture wins,
which is the priority the requester asked for).

### In flight: `feat/avatar-opens-contact-panel` → PR #23

The floating round `SidepanelSwitch` (person icon over the messages, top-right) is gone from both the
conversations screen and My Inbox; the component file is deleted, and `ConversationBox`'s default slot —
which only ever held it — with it. The contact's picture in `ConversationHeader` is now a `<button>`
(tooltip/aria-label `CONVERSATION.SIDEBAR.CONTACT`, `aria-pressed` mirrors the panel) that toggles
`is_contact_sidebar_open` and closes the copilot panel, exactly what the switch did. **`Alt+O` moved
with it** (it is listed in the shortcuts help modal, `widgets/modal/constants.js`). Side effect, on
purpose: the Copilot button lived in that switch behind the CAPTAIN flag, which this install hides, so
nothing user-visible changed there. Both screens share `ConversationBox → ConversationHeader`, so one
edit covers both. Verified on dev in the browser: 0 floating icons, click opens the panel, Alt+O closes
it. Branch cut from `develop`, so it carries no HANDOFF change; this note lives here to avoid a conflict.


Unread badge moved from the right-hand column to the avatar's top-left corner in **both** live cards
(`widgets/conversation/ConversationCard.vue` condensed; `CardAvatar.vue` for the expanded card,
`CardContent.vue` no longer renders it; dead `alignBottom` prop removed; badge gets `ring-2
ring-n-background`). The count already accumulates live: verified on dev with no reload —
read → 0, incoming message → 1, another → 2 (`ADD_MESSAGE` takes `conversation.unread_count` from
`Message#conversation_push_event_data`; cap is 10, display `9+`). Card specs 103/103, eslint clean.

---

## 2026-09-21 — DEPLOYED: sidebar trim + assigned-only My Inbox (PR #19) · Opus 5

**Merged:** PR #19 → `develop` head `cdf87a5e17d40e60746e4aa347ebda271488c4d5`.

**What shipped.**
- `Sidebar.vue`: `HIDDEN_SIDEBAR_ITEMS = {Captain, Calls, Mentions, Participating, Unattended}`,
  filtered out of both top-level items and their children by `withoutHiddenItems`. Contacts and
  Campaigns were already gone in the earlier sidebar restructure.
- `NotificationFinder#filter_by_assigned_conversations`: My Inbox is now a hard filter — it lists
  only notifications whose `primary_actor` is a conversation assigned to the reader. Applied in the
  finder rather than the controller so the list, the unread badge and the count agree.
- `spec/factories/notifications.rb` now assigns the fixture conversation to the notification's own
  user; without that every existing notification spec would build invisible rows.

**CI gate.** rspec (16 shards), rubocop, frontend tests and the docker test-build green. Only
`security-scan` red — the same pre-existing `ruby_llm 1.15.0` CVE-2026-67991 described in the entry
below, untouched by this work. The two new specs were proven to actually run: they landed in
**shard 11** (not shard 1 as the round-robin calculation predicted — the prediction was wrong and
was checked by downloading all 16 shard artifacts). 6488 examples, 0 failures across the suite.

**Deploy:** `./build.sh v4.17.0-mutoday` then `docker compose up -d` at 14:36 UTC. **No migrations
this round**, so `build.sh` + `compose up`, not `upgrade.sh` — no backup/migrate step was needed.

**Rollback asset:** `chatwoot/chatwoot:v4.17.0-mutoday-pre-sidebar` (image ID `e9501c96e588`,
`.git_sha c61d45f03`). Roll back with
`docker tag chatwoot/chatwoot:v4.17.0-mutoday-pre-sidebar chatwoot/chatwoot:v4.17.0-mutoday && docker compose up -d rails sidekiq`.
Frontend-and-finder only, no schema change, so the rollback is clean in both directions.

**Verified on production after the flip:**
- `docker compose ps` — rails and sidekiq both Up on the new image
- `cat /app/.git_sha` inside the running container = `cdf87a5e17d40e60746e4aa347ebda271488c4d5`
- `curl https://support.mutoday.com/api` → `queue_services: ok`, `data_services: ok`
- `NotificationFinder.private_instance_methods` in the **running** app includes
  `filter_by_assigned_conversations` (`.source` returns nil here — `method_source` isn't in the
  production bundle — so the method list is the check that works in prod)
- the live asset `https://support.mutoday.com/vite/assets/dashboard-Cxa3Nv5j.js` contains
  `new Set(["Captain","Calls","Mentions","Participating","Unattended"])`; the pre-deploy bundle
  `dashboard-BYLqcPWp.js` now 404s
- `docker compose logs --since 2m rails sidekiq` — no errors

**Gotcha for the next person:** `/app/login` only references `v3app-*.js`. `dashboard-*.js` is a lazy
chunk pulled in after login, so grepping the login HTML for the dashboard bundle finds nothing. Get
the filename from `ls /app/public/vite/assets` inside the container, then fetch that path over HTTPS.

---

## 2026-09-21 — DEPLOYED to production (support.mutoday.com) · Fable 5.1

**Merged:** PR #14 → `f0667a9ab` · PR #15 → `c61d45f03` (= `develop` head = image `.git_sha`).

**CI gate before merge.** rspec (16 shards), rubocop, frontend lint/test and the docker test-build were
green on both PRs. The one red check, `security-scan`, is `bundle-audit`: `ruby_llm 1.15.0` has
CVE-2026-67991 (ReDoS, High; advisory published 2026-09-16). The gem was pinned by upstream on
2026-05-08 (`aa10d4223`), `Gemfile.lock` is untouched by this work, the team's last green run was
2026-09-04, and the failure reproduces locally on a clean checkout. Brakeman (same job) passed.
`develop` has no branch protection, so nothing was overridden. **Team follow-up:** bump `ruby_llm`
(fix is `>= 2.0.0.rc1`, a major that touches Captain) or add an audit ignore with a written reason —
until then every PR in this fork will show this check red.

Post-merge CI on `develop`: "Run Chatwoot CE spec" red only on `security-scan`; "Publish Chatwoot
CE/EE docker images" is red on **every** develop push since at least 2026-09-04 (the fork has no
registry secrets) — pre-existing, not from this work.

**Deploy:** `./upgrade.sh v4.17.0-mutoday` (same tag; needed because there are migrations), detached,
12:54 → 13:09 UTC. ~15 min, a full-source build (layer cache missed at `bundle install`).
Backups: upgrade.sh's own `backups/chatwoot-20260921-125425.sql.gz` plus an explicit
`/opt/mu-support-db-pre-cdp-2026-09-21-1234.sql` (583K, 100 tables) taken beforehand.

**Rollback assets:** `chatwoot/chatwoot:v4.17.0-mutoday-pre-cdp` (image ID `841d5638c23b`, the
previous prod image, `.git_sha c1cace51`). To roll back:
`docker tag chatwoot/chatwoot:v4.17.0-mutoday-pre-cdp chatwoot/chatwoot:v4.17.0-mutoday && docker compose up -d rails sidekiq`.
The two migrations are additive (two new tables, one nullable indexed column), so the old image runs
fine against the migrated database — no down-migration is needed to roll back.

**Verified on prod after restart**
- rails + sidekiq Up on the new image; `docker run … cat /app/.git_sha` = `c61d45f03dda344103925cac2a28dfd61d220186`
- `GET /api` → `4.17.0`, `queue_services: ok`, `data_services: ok`
- `schema_migrations` max = `20260921000001`; tables `projects`, `live_chat_rules` present;
  `conversations.reply_due_at` present; `pg_index WHERE NOT indisvalid` = 0
- backfill: **4 of 4** open-and-waiting conversations got `reply_due_at`
- no error lines in `rails`/`sidekiq` logs after the restart
- the live site serves the new image's assets (`dashboard-Bo-ajksI.js`, `DashboardIcon-CuUd4dBl.js`
  → HTTP 200) and the served chunk contains `PROJECT_ALL_CHANNELS`, `OTHER_CHANNELS`,
  `LIVE_CHAT_RULES`; the login page renders

**Phase 1 applied on prod** (account 1, idempotent script from the "Phase 1 scope" section):
projects **Checkin+** (no inboxes yet) and **MUToday** ← inbox #1 "MUToday" (LINE, 44 conversations).
`live_chat_rules` has 0 rows, so the built-in 60 min / +60 default applies until someone sets rules.
Checkin+ will appear in the sidebar once an inbox is attached to it (Settings → Projects).

**Gotchas met during the deploy**
- `docker compose exec -T …` inside an `ssh … 'bash -s' <<EOF` script swallows the rest of the
  script from stdin — the run silently stops after the first exec. Add `< /dev/null` to each exec.
- The login page loads the `v3app-*` entry, not `dashboard-*`, so grepping the login HTML for the
  dashboard bundle is empty. Prove the served build with a file name taken from the image's
  `/app/public/vite/assets` instead.
- The build logs `ERROR -- : Failed to configure AI Agents SDK: connection … 5432 … refused` during
  `assets:precompile`. Non-fatal and expected — there is no database at build time.

**Still open:** collapsed-sidebar popover not visually checked · project badge in the conversation
header · "Chats expired (Assign)" reclaim job · the multi-inbound anchor question (finding 3).

---

## Decisions already taken (confirmed by the requester)

| Question | Answer |
|---|---|
| What is a "project"? | Several **inboxes inside one Chatwoot account**. Matches spec §18 (`inbox → project+channel`). Not separate accounts. |
| How to build the countdown | **Write it fresh in the fork.** Do not build on Chatwoot's enterprise SLA module — see the licence trap below. |
| "Chats limit 10" | Use Chatwoot's own `advanced_assignment` (per-inbox agent capacity), not a new global limiter. |

---

## 2026-09-21 — production incident: reopened chats notified nobody

**Reported:** a chat that had been resolved did not alert anyone when the customer wrote again.

**Not a code bug, and not from the deploy.** `app/models/message.rb` and
`app/services/messages/new_message_notification_service.rb` are untouched by PR #14/#15, and the
reopen path itself works: the inbox has no bot (`active_bot? == false`), so
`Message#reopen_resolved_conversation` takes `conversation.open!`, not `pending!`. Conversations were
reopening correctly the whole time — only the notification never fired. Two independent
configuration causes, both on account 1:

**1. Nobody was subscribed to the alert.** `NewMessageNotificationService` has three paths:
assignee, participants, then `notify_users_watching_all_conversations`. For a reopened chat that is
unassigned with no participants, only the third can fire, and
`all_conversations_new_message` is in `NotificationBuilder::OPT_IN_NOTIFICATION_TYPES` — so the row
is only created for users who switched it on. 13 of 14 users had it off. Two `agent`-role users were
blocked even earlier, by `NotificationBuilder#user_can_access_conversation?` → `ConversationPolicy#show?`,
because they were not members of the only inbox. Evidence: conv#44 took 12 inbound messages and
produced exactly 1 notification.

**2. Auto-assignment had an empty pool, so chats stayed unassigned.**
`enable_auto_assignment` and `assignment_v2` were both on, but
`Enterprise::Inbox#member_ids_with_assignment_capacity` routes to
`filter_by_capacity(available_agents)`, and `InboxAgentAvailability#available_agents` intersects
**inbox members with users who are currently online**. The inbox had 2 members and neither was
online, so the pool was `[]` and nothing was ever assigned — which fed straight back into cause 1.

**Applied (config only, no deploy, reversible):**
- every account user added as an inbox member — 2 → 14. Gives the two agents conversation access and
  puts real people in the auto-assign pool.
- `push_all_conversations_new_message` turned on for all 14 users. **Email flags deliberately left
  off** (`email_all_conversations_new_message` = 0 across all users) — an email per inbound message
  would be unusable.

**Rollback:** inbox members before were user_ids `[1, 2]`; the only user opted in before was `[3]`.

**Verified** by simulating a real still-failing case (conv#3, resolved + unassigned): reopen resolves
to `open!`; **14 of 14** users would now be notified, none blocked; manual assign list is 14;
auto-assign pool is whoever is online; email flag count stays 0.

**Judgement call left open.** Every user is now in the auto-assign rotation, including the
7solutions / 7ideasgroup / seedwebs / 7dayssuccess accounts that look like developers and vendors
rather than CS staff. If one of them is online when a chat arrives, the chat can be auto-assigned to
someone who will not answer it — worse than staying unassigned. Narrowing the rotation is a matter
of removing those users from the inbox members list; the notification setting is independent and can
stay on for everyone.

---

## Phase 1 scope (set by the requester)

Phase 1 ships with **Checkin+** and **MUToday** only. นกพลัส (Lottery Plus) is deferred to a
later phase — it stays in the spec, it is just not configured yet.

Applying it is idempotent and destroys nothing; a deferred project is deleted, which only
releases its inboxes (`has_many :inboxes, dependent: :nullify`) — conversations, contacts and
messages are untouched. Run with `bundle exec rails runner`:

```ruby
account = Account.first   # pick the right account on a multi-account install
PHASE_1 = [
  { name: 'Checkin+', description: 'Partner โรงแรม',   color: '#201E1D' },
  { name: 'MUToday',  description: 'แฟนคลับ · กิจกรรม', color: '#605D5D' }
]
PHASE_1.each do |attrs|
  project = account.projects.find_or_initialize_by(name: attrs[:name])
  project.assign_attributes(description: attrs[:description], color: attrs[:color])
  project.save!
end
account.projects.where.not(name: PHASE_1.pluck(:name)).destroy_all
```

Colours are the mockup's project dots (`PROJECTS` in `CDP Share Project.html`):
Checkin+ neutral-900, MUToday neutral-600, นกพลัส neutral-400 when it arrives.

Inboxes are attached to a project from **Settings → Projects**, so each project fills up as its
channels are connected. In the local database Checkin+ holds its two inboxes and MUToday has
none yet, which mirrors the real position: its Facebook page is not connected.

---

## Connecting MUToday's Facebook page

**State on production, checked 2026-09-21 after the deploy.** Nothing is configured yet:
`FB_APP_ID`, `FB_APP_SECRET`, `FB_VERIFY_TOKEN` and `IG_VERIFY_TOKEN` are all **empty**,
`Channel::FacebookPage.count` is 0, and the only inbox is #1 "MUToday" (LINE). So the whole
procedure below applies — there is no existing Meta app to reuse.

**The server side is ready — verified, not assumed:**
- `GET https://support.mutoday.com/bot?hub.mode=subscribe&hub.verify_token=…&hub.challenge=…`
  answers `Error; wrong verify token` (HTTP 200). That is the facebook-messenger endpoint replying,
  so the webhook URL is live and publicly reachable; it will complete the handshake once
  `FB_VERIFY_TOKEN` is set and matches. A nonsense path returns 404, so this is real routing.
- Caddy proxies every path to `rails:3000` with no path allow-list, so `/bot` needs no proxy change.
- TLS is a valid Let's Encrypt cert (expires 2026-11-12), which Meta requires.
- `FRONTEND_URL=https://support.mutoday.com`.

**`FACEBOOK_API_VERSION` is `v18.0`, and upstream Chatwoot still ships the same value**
(set by upstream `8d12cf0c6b`, 2025-09-09) — so this is not a stale value in our fork. Meta released
v18.0 in late 2023 and retires versions roughly two years on, so check it against Meta's current
version list when creating the app. It is one field in Super Admin
(`/super_admin/app_config?config=facebook`), changeable without a deploy.

**What cannot be automated from here:** every remaining step authenticates as MUToday on Meta —
creating the app, configuring its webhook, and the `FB.login` popup that picks the page. Those need
whoever holds the MUToday Meta Business account.

**Check this first.** If Checkin+'s Facebook inbox already works on `support.mutoday.com`, the
Meta app and all three credentials are already in place and the only remaining step is the
dashboard one — adding MUToday's page to the same app. Look at
`https://support.mutoday.com/super_admin/app_config?config=facebook`; if `FB_APP_ID`,
`FB_APP_SECRET` and `FB_VERIFY_TOKEN` are filled in, skip to step 3.

**1. Meta app** (developers.facebook.com, under MUToday's Business account)
- Add the **Messenger** product.
- Webhook URL `https://support.mutoday.com/bot` — that is where `config/routes.rb:666` mounts
  `Facebook::Messenger::Server`. Verify token = whatever you put in `FB_VERIFY_TOKEN`.
- Subscribe the page to the fields the app actually listens for
  (`config/initializers/facebook_messenger.rb`): `messages`, `messaging_postbacks`,
  `message_deliveries`, `message_reads`, `message_echoes`.
- Add `support.mutoday.com` to the app domains / allowed JS SDK domains. The connect flow is a
  client-side `FB.login` popup (`useFacebookPageConnect.js`), not a server redirect, so there is
  no OAuth redirect URI to register — but the domain has to be allowed.

**2. Chatwoot** — Super Admin → `/super_admin/app_config?config=facebook`: `FB_APP_ID`,
`FB_APP_SECRET`, `FB_VERIFY_TOKEN`, and `FACEBOOK_API_VERSION`.

**3. Dashboard** — Settings → Inboxes → Add Inbox → Facebook. Sign in as a Meta user who
administers the MUToday page, pick the page, then assign the new inbox to the **MUToday**
project in Settings → Projects.

Permissions requested at login (`app/javascript/dashboard/helper/facebookScopes.js`):
`pages_manage_metadata`, `business_management`, `pages_messaging`, `pages_show_list`,
`pages_read_engagement` — plus `instagram_basic` and `instagram_manage_messages` when the same
flow is used for Instagram.

Two things to plan for:
- **`FACEBOOK_API_VERSION` defaults to `v18.0`** (`config/installation_config.yml:143`). Meta
  retires a Graph API version about two years after release and v18.0 dates from late 2023, so
  check it against Meta's current list and bump it before connecting anything.
- **`pages_messaging` needs App Review and Business Verification** before the app can message
  the public. While the app is in development mode it only works for people with a role on it,
  which is fine for testing but not for go-live. Worth starting early — review is not instant.

---

## Findings that shape the work (all verified against this checkout)

### 0. Proof of the two findings below, run against this checkout

```
pricing_plan = "community"

BEFORE nightly reconcile:        AFTER Internal::ReconcilePlanConfigService:
  sla                  true       sla                  false   <- stripped
  advanced_assignment  true       advanced_assignment  true    <- survives
  assignment_v2        true       assignment_v2        true    <- survives
```

### 1. Chatwoot's SLA feature disables itself nightly on this install — do not build on it

`sla` is listed in `enterprise/config/premium_features.yml:3`. The chain that strips it:

- `config/schedule.yml` → `internal_check_new_versions_job`, daily `0 0 * * *` → `Internal::TriggerDailyScheduledItemsJob`
- that job → `Internal::CheckNewVersionsJob` (production only)
- the enterprise overlay prepends `Enterprise::Internal::CheckNewVersionsJob#perform`
  (`enterprise/app/jobs/enterprise/internal/check_new_versions_job.rb:28`) → `Internal::ReconcilePlanConfigService`
- that service: `return if ChatwootHub.pricing_plan != 'community'` → `reconcile_premium_features`
  → `account.disable_features!(*premium_features)`

`ChatwootHub.pricing_plan` returns `'community'` unless `INSTALLATION_PRICING_PLAN` says otherwise, and that
config is written with `locked: true` from whatever the hub reports. So enabling `sla` in Super Admin works
until the next nightly run, then it is switched off again. **Feature 3 is therefore fork-native.**

### 2. `advanced_assignment` survives — it is NOT in `premium_features.yml`

`config/features.yml:247` marks it `premium: true`, but that only affects how Super Admin groups the toggle.
It is absent from `enterprise/config/premium_features.yml`, so the nightly reconcile leaves it alone.
`assignment_v2` is `enabled: true` and not premium at all. This is why feature 2 leans on Chatwoot's own engine.

Caveat to respect: `Enterprise::Account#sync_assignment_features` turns `advanced_assignment` **off** whenever
`assignment_v2` is off, and it runs on the Super Admin bulk feature form. Keep `assignment_v2` on.

### 3. `waiting_since` is already the clock feature 3 needs

`conversations.waiting_since` (indexed) is:
- set to `created_at` on creation — `Conversation#ensure_waiting_since`, a `before_create`
- set to the message time when a customer writes **and it is currently blank** — `Message#set_waiting_since_on_incoming_message`
- cleared when a human agent replies — `Message#clear_waiting_since_on_outgoing_response`
- **not** cleared by private notes (guarded by `&& !private`), which matches the spec's "note: ไม่กระทบ SLA"
- cleared on resolve

**One deliberate difference from the spec.** The spec says the deadline is `เวลาข้อความล่าสุดของลูกค้า + 60 min`
(latest customer message). `waiting_since` anchors to the *first unanswered* customer message. They only differ
when a customer sends several messages in a row. Chatwoot's semantic was kept, because the spec's reading lets an
impatient customer push their own deadline out indefinitely. **Flagged to the requester; not yet re-confirmed.**

### 4. Rules to implement for feature 3, taken from the mockup

From `CDP Share Project.html` (`rules:[...]`), all configurable:

| Rule | Default | Meaning |
|---|---|---|
| Chats limit | 10 chats | concurrent chats per agent |
| Chats expired | 60 min | agent silence → Expired, back to Bot. **This is the SLA timer base** |
| Chats expired (Assign) | 60 min | assigned agent never picks the chat up |
| Adding time button | 60 min | what the `+60` button adds |
| Auto Solved | 24 h | Pending → Solved |
| Auto Closed | 48 h | Solved → Closed |
| Chat waiting time | 60 min | nobody takes a new chat → Missed |

Colour ramp (`slaMeta` in the mockup): `< 0s` → accent bg / white text, "เกิน SLA" ·
`< 300s` → accent-200 bg / accent-800 text, "ใกล้หมด" · otherwise neutral-200 / neutral-900, "ตอบภายใน".
The mockup ticks **every second**; Chatwoot's own SLA label only refreshes every 60s (`useSlaStatus.js`).

---

## PR 1 — Projects + unified Live chats (branch `feat/projects-unified-inbox`)

Branched off `origin/develop` @ `291d41297` (4.17.0).

### Status: backend verified end to end, frontend verified by lint + unit tests

**Backend**
- `db/migrate/20260921000000_create_projects.rb` — `projects` table (account, name, description, colour) + `inboxes.project_id`
- `app/models/project.rb`, `Inbox belongs_to :project`, `Account has_many :projects`
- `app/controllers/api/v1/accounts/projects_controller.rb` + `app/policies/project_policy.rb`
  (read open to all members, writes admin-only) + jbuilder views
- `config/routes.rb` — `resources :projects`
- `app/finders/conversation_finder.rb` — `project_id` narrows `@inbox_ids` to that project's inboxes
- `project_id` exposed on the inbox payload and permitted on inbox update

**Frontend**
- `api/projects.js`, `store/modules/projects.js`, registered in the store, mutation types
- routes `project_conversations` / `conversations_through_project`
- `projectId` threaded ConversationView → ChatList → `project_id` on the conversations and meta endpoints
- Sidebar "Projects" group under Conversations, badge = **sum of that project's inboxes' unread counts**
  (the existing `/conversations/unread_counts` already returns per-inbox numbers, so no new backend query)

### Evidence

Scenario: Checkin+ = inboxes 2+3 (2+1 conversations), นกพลัส = inbox 4 (3), two conversations outside any project.

```
GET /conversations?status=open                 -> 8
GET /conversations?status=open&project_id=1    -> 3   (inboxes [2,3])
GET /conversations?status=open&project_id=2    -> 3
```

Permission boundary — an agent who is a member of inbox 2 only:

```
admin             all=8  project_id=1 -> 3  inbox_ids seen=[2, 3]
restricted-agent  all=2  project_id=1 -> 2  inbox_ids seen=[2]
```

No leak: project scoping composes with `Conversations::PermissionFilterService`.

- `bundle exec rspec spec/finders/conversation_finder_spec.rb` → 24 examples, 0 failures
- `bundle exec rubocop <9 changed files>` → no offenses
- `pnpm eslint` → 0 errors (424 warnings are pre-existing repo-wide)
- `pnpm vitest run <sidebar + conversation store>` → 237 tests passed

### Settings → Projects

`settings/projects/list`, admin only. Lists each project with the inboxes it covers; the form
creates or edits a project and picks its inboxes in one place, so an admin never has to open each
inbox's own settings. Saving sends `inbox_ids`, and the controller moves inboxes in and out of the
project — an inbox belongs to one project, so adding it to another removes it from the first.
Omitting `inbox_ids` (a partial update) leaves the assignment alone.

**Gotcha worth remembering.** `inbox_ids` is not a `Project` column, and Rails' `ParamsWrapper` only
wraps real model attributes, so it arrived at the top level but never inside `params[:project]` —
the selection was accepted by the UI and silently dropped. The controller now declares
`wrap_parameters :project, include: Project.attribute_names + ['inbox_ids']`. Any future non-column
param on this controller needs adding there too.

Verified in the browser: the list renders inbox names, editing prefills the right inboxes,
unticking one and saving updates the row immediately, and the API agrees. Flat (browser), nested and
`inbox_ids`-omitted payloads were each checked.

### Sidebar: each project is the parent, its channels sit under it

The first cut listed Projects and Channels as two flat groups, so every inbox showed up twice and
nothing said which channel belonged to which project. Now each project is its own collapsible
section directly under Conversations: an **All channels** link (the project-wide view, carrying
the project's unread total) followed by that project's inboxes, drawn with the same `ChannelLeaf`
as before. Channels outside any project sit in a group labelled **No project**; on an account
with no projects that group is the plain **Channels** list, so nothing changes there.

Decisions worth keeping:
- **A project with no channels this user can see is not shown.** It is not a live-chat
  destination until an inbox is attached (an agent who is a member of none of its inboxes has
  nothing to open there). On production MUToday appears once its Facebook inbox is attached.
- `SidebarSubGroup` only nests one level, so projects are sibling sections rather than children
  of a "Projects" heading. The coloured dot marks them.
- The leftover group is labelled "No project", not "Other channels": at the default sidebar
  width the longer label overflowed (`scrollWidth 102 > clientWidth 75`); "No project" fits (70/70)
  and is the more precise description anyway.
- Project membership is resolved from the projects list (`inboxIds`), not the inbox payload —
  same IndexedDB-cache reason as the header countdown.

**Bug found and fixed in the process.** Opening a conversation from a project view produced
`/conversations/:id` instead of `/project/:projectId/conversations/:id`: `conversationUrl` and
`conversationListPageURL` in `URLHelper.js` carried `teamId`/`foldersId` but not `projectId`, so
the list refetched unfiltered and the sidebar jumped to All Conversations. `projectId` is now
threaded ChatList → ConversationList → ConversationItem → the URL builders, mirroring `teamId`.
Verified: from Checkin+, opening a chat gives `/project/1/conversations/19`, the list stays at
`All 2`, and Checkin+ stays highlighted.

**Not verified:** the collapsed-sidebar popover for project sections. It is the same
`SidebarCollapsedPopover` branch the Teams and Channels subgroups already go through, but no
collapse control was found by name to click, so it was not looked at.

`pnpm vitest run app/javascript/dashboard/helper` reports **15 failures in `helper/specs`**
(`CacheHelper/DataManger`, `downloadHelper`, `snoozeHelpers`). They fail identically on a clean
`origin/develop` — environment-related (IndexedDB absent under jsdom, date formatting), not this work.

### Still to do on PR 1
- The spec's project badge in the conversation header ("จุดสี + ชื่อ + n เปิดอยู่")

---

## PR 2 — reply countdown (branch `feat/reply-countdown`, stacked on PR 1)

Stacked on PR 1 because the per-project rule override needs `Project`.

### Status: verified end to end, backend and frontend

- `db/migrate/20260921000001_create_live_chat_rules.rb` — `live_chat_rules`
  (account + optional project, `reply_timeout_minutes`, `extension_minutes`) and
  `conversations.reply_due_at`, indexed. **Backfills open conversations in batches of 10k**,
  otherwise chats already open when this ships would show no countdown until the customer wrote again.
- `app/models/live_chat_rule.rb` — `for_project` resolves project rule → account default → column defaults
- `Conversation` — `sync_reply_due_at` on create and whenever `waiting_since` changes;
  `extend_reply_deadline!`; `handle_resolved_status_change` now clears `reply_due_at` alongside
  `waiting_since` (that path uses `update_columns`, so callbacks never see it)
- `sort_on_reply_due_at` + `reply_due_at_asc`/`_desc` so an agent can work most-overdue first
- `POST /conversations/:id/extend_reply_deadline`, `reply_due_at` on the conversation payload,
  `/live_chat_rules` CRUD (read open to members, writes admin-only)
- `useReplyCountdown.js` + `ReplyCountdown.vue` — ticks **every second**, three states from the mockup:
  grey "ตอบภายใน", amber under 5 min "ใกล้หมด", red counting up once past "เกิน SLA".
  Rendered in both conversation cards the live list actually uses — the condensed
  `widgets/conversation/ConversationCard.vue` and `ConversationCardExpanded.vue`.

  Worth knowing: `components-next/.../CardMessagePreviewWithMeta.vue` looks like the list card but is
  only used by the contact and company history sidebars. Putting the chip there renders nothing in
  the live list.

### Evidence

Lifecycle, with Checkin+ overridden to 15 min / +5 min and the account default at 60/60:

```
new Checkin+ conversation      waiting_since=10:41:49  reply_due_at=10:56:49  (+15 min)
after agent reply              waiting_since=nil       reply_due_at=nil
after customer message         waiting_since=10:41:49  reply_due_at=10:56:49  (+15 min)
private note                   reply_due_at unchanged: true
extend                         10:56:49 -> 11:01:49 (+5 min)
after resolve                  waiting_since=nil       reply_due_at=nil
```

API: per-project extension applied (`Checkin+ +5 min`, `นกพลัส +60 min`), duplicate rule for a
project rejected `422`, agent `GET /live_chat_rules` OK but `POST` `401`.

Browser: all eight chips ticked exactly 3 seconds over a 3-second window
(`29:23→29:20`, `-12:37→-12:40` counting up while overdue), in all three colour states.

- `rspec spec/finders/conversation_finder_spec.rb spec/models/conversation_spec.rb` → 143 examples, 0 failures
- `pnpm vitest run` (conversations + sidebar) → 237 passed · `pnpm eslint` → 0 errors
- `rubocop` on the 11 changed Ruby files → no offenses

### Settings → Live chat rules

`settings/live-chat-rules/index`, admin only. One row for the account default plus one per project
override, each showing "reply within" and "extend adds".

Three decisions worth keeping:
- An account that has saved nothing still sees a row, carrying the column defaults and marked
  "not saved yet", so the page never implies the countdown is unconfigured. Editing it creates the row.
- The account default row has no delete action — it is the fallback every project lands on.
- A saved rule's scope is read-only. Moving it would silently retarget which conversations it
  governs. A new rule only offers scopes that are still free (each scope holds one rule, enforced by
  a unique index), and the first free one is preselected — otherwise Save would submit a duplicate
  and get a 422.

Verified in the browser, end to end rather than just visually: editing Checkin+ to 25 minutes then
creating a new conversation in one of its inboxes gave `waiting_since + 25 min`, while นกพลัส gave
the account default of 60. Creating a นกพลัส override of 45 produced +45; deleting it put นกพลัส
back to +60. "Add project override" greys out once every project has one.

### Conversation header countdown + extend button

The header shows the same countdown as the list row, with the state spelled out
("Reply due in" / "Reply almost overdue" / "Reply overdue", hidden under `lg`), next to a
`+N` button that grants that project's configured extension.

How much the button grants is resolved on the client from the projects list and the live chat
rules, not sent per conversation — putting it on the conversation payload would have cost a
rule lookup per row in the list. The project comes from `projects/getProjects` (which carries
`inboxIds`) rather than from the inbox payload, because **inboxes are served from an IndexedDB
cache** that only refreshes when the server's inbox cache key changes, so a newly added field
can be missing there for a while. That bit the first version: the button showed the account
default `+60` instead of Checkin+'s `+5`.

**The websocket payload needed `reply_due_at`.** `Conversations::EventDataPresenter#push_data`
carried `waiting_since` but not the deadline, and `UPDATE_CONVERSATION` merges the pushed keys
over the cached conversation (`{ ...selected, ...updates }`) — so a key the payload omits keeps
its stale value. The countdown kept ticking after an agent had replied until the page reloaded.
Both fields now sit together in `push_timestamps`. `spec/models/conversation_spec.rb` asserts
that payload exactly and was updated.

Verified in the browser: `+5` on a Checkin+ conversation moved the clock 07:31 → 12:29 and the
server agreed; the overdue state renders red (`bg-n-ruby-9`) and counts up; sending a reply
cleared the header to just "Resolve" with no reload.

**Worth knowing for anyone testing this locally:** the event dispatcher is async
(`EventDispatcherJob.perform_later`), so **Sidekiq must be running** or no websocket update is
broadcast at all. Two apparent "live update is broken" results turned out to be a stopped Sidekiq.

### Still to do on PR 2
- Decide the multi-inbound anchor question in finding 3 above

---

## Feature: auto-assign — already in Chatwoot, verified working here

No new code was needed. Verified on this checkout:

```
assignment_v2 enabled?        true     (default on, not premium)
advanced_assignment enabled?  false    (must be switched on; survives the nightly reconcile)
inbox 2 enable_auto_assignment=true v2=true
online now: {"1"=>"online", "2"=>"online"}
bulk assignment assigned 3 conversation(s)
conversation 10 assignee now = "john@acme.inc"
```

Agent capacity ("Chats limit"), after enabling `advanced_assignment` and setting a limit of 1 on inbox 2:

```
john@acme.inc    open-in-inbox=2  has_capacity=false
agent@acme.inc   open-in-inbox=1  has_capacity=false
```

To switch on in production: enable `advanced_assignment` for the account, create an
`AgentCapacityPolicy` with an `InboxCapacityLimit` per inbox, and assign agents to it.
Keep `assignment_v2` on — `Enterprise::Account#sync_assignment_features` turns
`advanced_assignment` off whenever `assignment_v2` is off.

Two things to know:
- Only agents marked **online** are ever candidates. Away/offline agents are skipped entirely.
- The capacity limit is **per inbox**, not global. An agent covering three inboxes needs a limit on
  each. The requester chose this over building a global limiter.

### The one real gap: "Chats expired (Assign)"

The spec wants a chat reclaimed when the assigned agent never picks it up (60 min default).
Chatwoot has nothing equivalent — assignment is never revisited once made. It needs a rule value plus
a per-minute job that unassigns an open conversation whose `reply_due_at` passed while the assignee
never replied, letting the round robin hand it to someone else. **Not built.**

---

## Local environment (set up during this work, was absent before)

This machine could not run the Rails side at all. Installed: `rbenv` + Ruby 3.4.4, **PostgreSQL 17**
(not 16 — `pgvector` has no pg16 bottle and `db/schema.rb` needs the `vector` extension), Redis, pgvector.
A `postgres` superuser role was created. `bundle install` and `pnpm install` both succeed.

- Rails: `bundle exec rails s -p 3000` · Vite: `bin/vite dev`
- Seed: `bundle exec rails db:seed` (minimal: 2 accounts, 1 user, 1 inbox)

**Watch out:** `rails db:migrate` runs the `annotate` gem, which rewrites model annotations across the repo —
it refreshed 13 unrelated models that had drifted. Those were reverted so they stay out of the PR. The same run
also rewrites `db/schema.rb` with Rails 7.2 formatting (index reordering, `[7.1]` → `[7.2]`); `schema.rb` was
hand-edited to carry only the real change, and re-verified by loading it into a fresh database.

**Pre-existing work parked:** an uncommitted lark webhook URL pattern edit was stashed
(`stash@{0}`). That same change is already on `origin/develop`, so nothing is lost.

**The rubocop pre-commit hook does not run.** Husky starts with the system Ruby 2.6, which cannot
find bundler 2.5.16, so every commit prints a wall of `Gem::GemNotFoundException` and the Ruby lint
is silently skipped — `eslint --fix` via lint-staged does run. Rubocop was run by hand on every
changed file instead. Worth fixing separately by having the hook init rbenv.

**Dev database state:** the seeded account has projects Checkin+ / นกพลัส, live chat rules, an
`AgentCapacityPolicy` with a limit of 1 on inbox 2, and `advanced_assignment` enabled — all created
while verifying. `reply_due_at` values on seeded conversations were hand-set to exercise the chip's
colour states, so they are not meaningful data.
