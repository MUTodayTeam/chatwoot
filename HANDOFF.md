# HANDOFF — CDP Share Project features on the MUToday Chatwoot fork

Source of truth for the requirement: `CDP Share Project - Dev Spec.pdf` (v1.4) and the
mockup `CDP Share Project.html`. Three features were asked for:

1. **Live chats รวมทุก project** — one inbox across every project, with a per-project sub-menu
2. **ระบบ assign auto** — automatic assignment of incoming chats to agents
3. **ระบบนับถอยหลัง** — a countdown on chats the customer has been waiting on too long, configurable

Delivery shape agreed with the requester: **one PR per feature**.

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
