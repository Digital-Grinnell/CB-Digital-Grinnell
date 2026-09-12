# Agent History

## Project Context

- This is a CollectionBuilder-CSV Jekyll site.
- Production output is generated in `_site`.
- Azure Blob static website deployments target the `$web` container.
- Do not record secrets, access keys, SAS tokens, or personally sensitive information here.

## Working Agreement

- Read relevant nearby files before making changes.
- Keep changes focused and validate them with the narrowest applicable command.
- Never deploy `collection-template`; it is a source template for building other collection branches.
- Add a dated entry below after meaningful changes, deployment work, or important findings.
- Record the command or validation performed, but never its sensitive output.

## History

### 2026-09-02

- Confirmed Azure storage account `digitalgrinnell` is in resource group `Digital.Grinnell`.
- Enabled static website hosting with `index.html` and `404.html` as the configured documents.
- Assigned the current user the `Storage Blob Data Contributor` role at the storage-account scope for Azure CLI Blob operations.
- Local Azure CLI commands use `AZURE_STORAGE_AUTH_MODE=login` and `AZURE_STORAGE_ACCOUNT=digitalgrinnell` from an untracked `.env` file; no storage key or SAS is stored locally.

### 2026-09-04

- Updated Sass files for Dart Sass module compatibility; verified with `bundle exec jekyll build --destination /tmp/cb-digital-grinnell-sass-fix-build`.
- Restored the collection-management runbook after the TDPS revert; verified with `git diff --check -- "docs/DG-documents/Creating and Managing a Digital Content Collection.md"`.
- Documented the verified `main` branch Azure root-site deployment procedure in the collection-management runbook.

### 2026-09-10

- Updated `featured-image` and `featured-image-alt` in `_data/theme.yml` across all branches (`main`, `collection-template`, `georgia-dentel`, `tdps`, and `sass-fix`) to use Digital Grinnell's early Burling Library image (`/assets/img/early-burling-library.jpg`).
- Updated `.site-title` styling in `_sass/_custom.scss` across all branches to use `grinnell_red` (`#DA291C`).
- Pushed updated branches to `origin`. Verified with `git show <branch>:_sass/_custom.scss`.

### 2026-09-12

- Recorded that `collection-template` is never a deployment target; it is used only as a source template for other collection branches.
