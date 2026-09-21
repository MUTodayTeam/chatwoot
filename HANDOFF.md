# HANDOFF — CDP Share Project features on the MUToday Chatwoot fork

Source of truth for the requirement: `CDP Share Project - Dev Spec.pdf` (v1.4) and the
mockup `CDP Share Project.html`. Three features were asked for:

1. **Live chats รวมทุก project** — one inbox across every project, with a per-project sub-menu
2. **ระบบ assign auto** — automatic assignment of incoming chats to agents
3. **ระบบนับถอยหลัง** — a countdown on chats the customer has been waiting on too long, configurable

Delivery shape agreed with the requester: **one PR per feature**.

---

## Decisions already taken (confirmed by the requester)

| Question | Answer |
|---|---|
| What is a "project"? | Several **inboxes inside one Chatwoot account**. Matches spec §18 (`inbox → project+channel`). Not separate accounts. |
| How to build the countdown | **Write it fresh in the fork.** Do not build on Chatwoot's enterprise SLA module — see the licence trap below. |
| "Chats limit 10" | Use Chatwoot's own `advanced_assignment` (per-inbox agent capacity), not a new global limiter. |

---

## Findings that shape the work (all verified against this checkout)

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

### Still to do on PR 1
- Settings UI to create/edit projects and attach inboxes (API exists; no admin screen yet)
- Visual check of the sidebar group in a browser
- The spec's project badge in the conversation header ("จุดสี + ชื่อ + n เปิดอยู่")

---

## PR 2 — reply countdown (not started)

Planned shape: per-account (and per-project override) rules record; `reply_due_at` derived from
`waiting_since + chats_expired`; `+60` extension stored per conversation; a per-minute job to mark
expired; a ticking chip in the list row and conversation header following the mockup's colour ramp.

## PR 3 — auto-assign (not started)

Mostly configuration of what already exists (`assignment_v2` + `advanced_assignment` + `AssignmentPolicy`).
The genuine gap is **"Chats expired (Assign)"** — reclaiming a chat whose assigned agent never picked it up.
Chatwoot has no equivalent today; it needs a new job plus a rule value.

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
