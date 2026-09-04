# Agent History

## Project Context

- This is a CollectionBuilder-CSV Jekyll site.
- Production output is generated in `_site`.
- Azure Blob static website deployments target the `$web` container.
- Do not record secrets, access keys, SAS tokens, or personally sensitive information here.

## Working Agreement

- Read relevant nearby files before making changes.
- Keep changes focused and validate them with the narrowest applicable command.
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
