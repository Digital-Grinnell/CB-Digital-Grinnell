# VSCode: Editing in a Collection Branch

> Consider this extremely `IMPORTANT` advice!  

Since you ran `git switch -c tdps`, your working directory is now checked out to the `tdps` branch — this is a workspace-wide state, not a per-file setting. Here's what that means in practice:

**How it works**
- Every file in `CB-Digital-Grinnell` on disk right now reflects the `tdps` branch's content.
- Any edit you make in VS Code (to `_config.yml`, `_data/tdps.csv`, pages, templates, etc.) modifies files in that same working directory — so it's automatically "on" `tdps`, because there's only one working directory and it's currently pointed at `tdps`.
- These edits do **not** exist on `main` until you switch back to `main` and either merge/cherry-pick them or make separate edits there. `main`'s last commit is untouched by anything you do while `tdps` is checked out.

**What would break this isolation**
- Switching branches (`git switch main`) while you have uncommitted changes — Git will either carry them into `main` as uncommitted changes (if not conflicting) or block the switch. So don't run `git switch main` while mid-edit on `tdps` work.
- Committing on `tdps`, then later merging `tdps` into `main` — but you control when that happens.

**How to verify/stay safe**
1. Check your current branch anytime with:
```sh
git branch --show-current
```
2. Commit your `tdps` work before switching branches, so nothing is "in limbo":
```sh
git status
git add <files>
git commit -m "..."
```
3. Before switching to `main`, confirm a clean state:
```sh
git status   # should say "nothing to commit, working tree clean"
git switch main
```

As long as you commit your `tdps` changes before switching away, and never merge `tdps` into `main`, your collection-specific edits stay fully isolated to the `tdps` branch. VS Code's source control panel also shows the active branch name in the bottom-left status bar — worth glancing at before saving/committing to confirm you're where you think you are.