# AnotherHUD

WoW **Forever** (retail engine, Interface 16001) addon in Lua 5.1: replaces the action bars and unit frames (Player, Target, Target of Target, Focus, Pet, Party, Boss, Action Bars 1-8, Stance, Pet Bar, Cast Bar, class resource bar, totem bar, XP / Reputation) and plugs them into Blizzard's **Edit Mode**. Part of the player's own UI suite with **AnotherLedger** (`D:\GitRepos\LootLedger`) and a minimap addon (not built yet). The addon folder is `AnotherHUD/` inside the repo.

**Status:** Plans 1-4 built (foundation, mockups, unit frames: Player with cast bar, Target, Target of Target, Focus, Pet, Party, Boss); Plan 4 checked in the client; Bars (Plan 5) next. See `docs/superpowers/specs/` and `docs/superpowers/plans/`.

Docs:
- `README.md`: player guide (keep it free of texture paths, API names and pixel sizes).
- `docs/DEVELOPMENT.md`: code layout, module registry, Edit Mode glue, secret values, taint rules, saved state, packaging.
- `docs/CHECKLIST.md`: what still has to be confirmed in the client, and release steps.
- `docs/BACKLOG.md`: ideas not built yet (raid frames, shared suite core, ...).
- `docs/superpowers/`: design specs and plans per feature (history, not kept in sync).

## Working with the player

- **Artwork: mockups first.** Any new or changed art (portrait ring, bar textures, borders, button skins, icons, colors of a new skin) is shown as a mockup and built only after the player approves it. Wait for the answer; don't build "in the meantime".
- **Ask questions.** When a request leaves something open that changes what gets built, ask (one question at a time, with your recommendation) instead of guessing.
- **FlareUI is a reference, not a source.** It is installed at `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\FlareUI` and shows how Edit Mode integration and secret-value-safe unit frames work on Forever. Read it to learn which client APIs work; never copy its code or art.
- **AnotherLedger is a source.** Its tooling, `Theme.lua`, fonts, skins, widgets, test harness and conventions may be copied and adapted (same author).
- Never put tokens or passwords in files, commits or chat.

## Commands

- Tests: `lua tests/run.lua` from the repo root (plain Lua, no client; exit 1 on failure). Run after every change; all must pass. Local `lua` is 5.4; GitLab CI also runs 5.1, so write 5.1 code (no `goto`, `//`, `table.unpack`, integer-only APIs).
- Lint: `luacheck AnotherHUD` (`.luacheckrc`; CI fails on any warning). A WoW API the code starts to read goes in its `read_globals`.
- No build step: the client loads files in `.toc` order. Without `Libs/` (packager-fetched, git-ignored) everything but the Edit Mode part works.
- Remote: GitLab `origin` (https://gitlab.com/mhhenjes/anotherhud), branch `main`. Commits are `feat:` / `fix:` / `refactor:` / `docs:` style, one-line summary plus a short body.

## Architecture (planned; details in `docs/DEVELOPMENT.md`)

- **Modules.** Every replaced frame is one `ns.Modules.define{...}` in its own file (`Units/` or `Bars/`). Its `settings` list feeds both the Edit Mode panel and the Settings window. UI and Edit Mode code never name a module. New frame = new file + `.toc` line.
- **Unit frames are ours** (`SecureUnitButtonTemplate`; Party and Boss as fixed member frames in a holder (`Units/Group.lua`)); Blizzard's are hidden. **Action bars are Blizzard's, re-skinned**; Blizzard keeps clicks, paging, cooldowns, procs, keybinds.
- **Edit Mode** goes through LibEditMode (unmodified, packager external) plus `EditMode/` glue: settings panels, snapping, checklist toggles. Positions per Edit Mode layout; look settings per profile.
- **Pure vs client code** as in AnotherLedger: files in `Core/` are plain Lua and tested with `h.load`; client calls only inside functions, never at file load.
- **Look** lives in `Core/Theme.lua` (colors, fonts, sizes, textures); change it there, not in UI files.

## Conventions and gotchas

- **Secret values**: never do arithmetic, comparisons or `tostring` math on health, power or cast values from the client; pass them to widgets (`SetValue`, `SetText`, curve / color APIs). Tests use fakes that throw on arithmetic to catch this.
- **Combat lockdown**: nothing that touches a secure frame (create, show / hide, anchor, size, attributes) runs in combat; queue it with `ns.Combat.after(fn)` until `PLAYER_REGEN_ENABLED`.
- **Taint**: never write to Blizzard tables or call Blizzard functions that aren't safe from addon code; use `hooksecurefunc` and own frames. Hide Blizzard frames by reparenting to a hidden frame out of combat.
- **Options**: a default in the module's `defaults`, a short `label` (24 characters at most) and a `tooltip`. Read with `Options.get`.
- **Texts** go through `ns.L` (English text as key); add the German text to `Locales/deDE.lua`.
- An unconfirmed client API gets an `UNVERIFIED (check in client)` comment and a line in `docs/CHECKLIST.md`; say in your report it was not run in the client.
- New `.lua` file: add it to the `.toc` and the layout table in `docs/DEVELOPMENT.md`.
- Update the docs in the same change: player-visible behavior in `README.md`, internals in `docs/DEVELOPMENT.md`, client checks in `docs/CHECKLIST.md`. Changelog entries are short (one bullet per player-visible change).
- **Editing on Windows:** edit Lua with the Write / Edit tools; heredocs and `sed` strip backslashes (`Interface\\AddOns\\...`). For scripted multi-file edits write a Python file and run it.
