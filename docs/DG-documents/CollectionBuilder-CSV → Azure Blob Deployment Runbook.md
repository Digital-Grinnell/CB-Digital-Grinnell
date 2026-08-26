# Deploying CollectionBuilder-CSV to Azure Blob Storage — Runbook

A step-by-step runbook for deploying **CollectionBuilder-CSV** (Jekyll) sites to **Azure Blob Storage static website hosting** via **GitHub Actions**, using repository secrets `STORAGE_ACCOUNT_NAME` and `SAS_TOKEN`.

---

## 1. Scope and assumptions

- CollectionBuilder-CSV is a "stand alone" Jekyll template that builds a metadata-driven digital collection site from a CSV in the project's `_data/` folder; the built site is output to `_site` ([CollectionBuilder README](https://github.com/CollectionBuilder/collectionbuilder-csv)).
- Because CollectionBuilder-CSV relies on Jekyll **plugins**, it will not build with default GitHub Pages — it must be built with GitHub Actions or a full local Jekyll build ([CollectionBuilder Docs — Deploy](https://collectionbuilder.github.io/cb-docs/docs/deploy/)).
- The local build command is `rake deploy`, a shortcut for `JEKYLL_ENV=production bundle exec jekyll build` ([CollectionBuilder Docs — Jekyll Build](https://collectionbuilder.github.io/cb-docs/docs/deploy/build/)).
- The deployment target is **Azure Blob Storage static website hosting** (the `$web` container), not Azure Static Web Apps.
- Authentication uses a **SAS token** (no `azure/login`, no service principal) because the required repository secrets are `STORAGE_ACCOUNT_NAME` and `SAS_TOKEN`.
- A static website in Azure Storage is served from the **primary endpoint** (e.g. `https://<account>.z##.web.core.windows.net/`), which is distinct from the normal blob endpoint ([Microsoft Learn — Static website hosting](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website)).

---

## 2. Prerequisites

- A working local Ruby + Bundler + Jekyll environment that can run `bundle exec jekyll build`. CollectionBuilder-CSV templates ship with a `Gemfile`; commit `Gemfile.lock` for reproducible CI builds ([CollectionBuilder Docs — Jekyll Build](https://collectionbuilder.github.io/cb-docs/docs/deploy/build/)).
- An Azure **general-purpose v2** storage account (GPv2 is required for static website hosting).
- Your metadata CSV placed in the project's `_data/` folder and referenced from `_config.yml` ([CollectionBuilder Docs — Add Your Metadata](https://collectionbuilder.github.io/cb-docs/docs/metadata/uploading/)).
- Decide the production URL and set `url` and `baseurl` in `_config.yml` accordingly (see Section 3).
- The GitHub Actions runner is `ubuntu-latest` (Linux). Note that macOS (case-insensitive) and Linux (case-sensitive) differ in filename handling — relevant to metadata-driven sites (see Troubleshooting).

---

## 3. Configure `_config.yml` for Azure hosting

CollectionBuilder uses `url` and `baseurl` to generate internal links. For a site served from the Azure static-website root, set:

```yaml
# _config.yml
url: "https://<account>.z##.web.core.windows.net"
baseurl: ""
```

If you later front the site with a custom domain or CDN, update `url` to that final public hostname and rebuild. Leaving a leftover GitHub Pages `baseurl: /repo-name` is the most common cause of broken asset paths after moving off GitHub Pages.

> Note: if your CollectionBuilder template generates a `404.html`, record that name for the Azure error-document setting in Section 4. If your site does not generate one, create a simple `404.html` or omit the `--404-document` flag.

---

## 4. Set up Azure Blob Storage static website hosting

### 4.1 Enable static website hosting

Enable the feature and set the index and error documents. This also creates the reserved `$web` container automatically if it does not exist ([Microsoft Learn — Host a static website](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website-how-to)):

```bash
az storage blob service-properties update \
  --account-name <storage-account-name> \
  --static-website \
  --index-document index.html \
  --404-document 404.html
```

Parameters:
- `--account-name` — storage account name.
- `--index-document` — commonly `index.html`.
- `--404-document` — error document shown when a requested page does not exist (use `404.html` for CollectionBuilder).

### 4.2 Retrieve the primary endpoint

```bash
az storage account show \
  -n <storage-account-name> \
  -g <resource-group-name> \
  --query "primaryEndpoints.web" \
  --output tsv
```

This returns the `https://<account>.z##.web.core.windows.net/` URL — the public site address ([Microsoft Learn — Host a static website](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website-how-to)).

### 4.3 Confirm the `$web` container

`$web` is the reserved container name for static website hosting. One storage account hosts one static website, and `$web` is the only container used for it ([Microsoft Learn — Static website hosting](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website)). Verify it exists and is empty before the first deploy:

```bash
az storage blob list --account-name <storage-account-name> --container-name '$web' --output table
```

---

## 5. Generate the SAS token

The workflow authenticates with a SAS token, so the secret must grant enough permissions for whatever deploy mode you choose.

### 5.1 Choose the SAS scope and permissions

Prefer a **container-scoped** SAS over `$web` (not an account-wide SAS) to limit blast radius. The signed permissions (`sp`) field controls what the token can do ([Microsoft Learn — Create a service SAS](https://learn.microsoft.com/en-us/rest/api/storageservices/create-service-sas)). Container permission order is `racwdl` (read, add, create, write, delete, list) — always emit the letters in this canonical order:

| Permission | Meaning | Needed for |
|---|---|---|
| `r` | Read | Verify/list blobs |
| `a` | Add | Put new blobs (Put Blob / Put Block) |
| `c` | Create | Create new blobs |
| `w` | Write | Overwrite existing blobs |
| `d` | Delete | Sync mode that removes stale blobs |
| `l` | List | Enumerate container contents (required for `sync`) |

Recommended minimums by deploy mode:

- **Upload-only (overwrite)**: `sp=racwl` (read, add, create, write, list).
- **Sync with delete** (mirrors `_site` exactly, removing deleted/renamed item pages): `sp=racwdl` (add delete).

### 5.2 Generate the SAS (Azure CLI, container-scoped)

```bash
# Set an expiry well ahead of your rotation cadence, HTTPS only.
az storage container generate-sas \
  --account-name <storage-account-name> \
  --name '$web' \
  --permissions racwdl \
  --expiry 2026-12-31T23:59:00Z \
  --protocols https \
  --output tsv
```

### 5.3 SAS token storage convention (important)

Store `SAS_TOKEN` **without** the leading `?`. The action used below (Section 7) expects the bare token; Azure CLI/azcopy commands that build a URL will prepend the `?` themselves. Mixing "with `?`" and "without `?`" conventions is a top cause of `AuthenticationFailed` errors (see Troubleshooting).

Never echo the SAS token in workflow logs. Avoid `set -x` around the deploy step, and do not print `${{ secrets.SAS_TOKEN }}`.

### 5.4 Rotation

SAS tokens are long-lived secrets. Put a calendar reminder to rotate before expiry, and prefer short expiry + automated regeneration over very long-lived tokens.

---

## 6. Add repository secrets in GitHub

1. In the repository, go to **Settings → Secrets and variables → Actions**.
2. Add two **repository secrets**:
   - `STORAGE_ACCOUNT_NAME` — the storage account name.
   - `SAS_TOKEN` — the bare SAS token (no leading `?`), from Section 5.2.
3. Keep `Allow all actions` or the minimum workflow permission set enabled under **Settings → Actions → General** ([CollectionBuilder Docs — CSV Walkthrough](https://collectionbuilder.github.io/cb-docs/docs/walkthroughs/csv-walkthrough/)).

> Secrets are not injected into workflows triggered by pull requests from untrusted forks by default. The `push` to `main` trigger is the standard production path.

---

## 7. Define the GitHub Actions workflow YML

Create `.github/workflows/deploy-azure.yml`. This workflow:

1. Checks out the repo.
2. Sets up Ruby with Bundler caching.
3. Builds the Jekyll site to `_site` with `JEKYLL_ENV=production`.
4. Validates that `_site/index.html` exists.
5. Deploys `_site` to the `$web` container using the `bacongobbler/azure-blob-storage-upload` action, which supports `sas_token` + `account_name` and a `sync` flag that switches from `az storage blob upload-batch` to `az storage blob sync` ([bacongobbler/azure-blob-storage-upload](https://github.com/bacongobbler/azure-blob-storage-upload)).

```yaml
name: Build and deploy CollectionBuilder-CSV to Azure Blob

on:
  push:
    branches: [ main ]
  workflow_dispatch: {}   # manual run for first test

# Let the action write deploy results; restrict in production if desired.
permissions:
  contents: read

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'        # pin to a version that builds locally
          bundler-cache: true        # auto-caches gems based on Gemfile.lock

      - name: Build site
        env:
          JEKYLL_ENV: production
        run: |
          bundle exec jekyll build --trace

      - name: Verify build output
        run: |
          test -f _site/index.html || { echo "ERROR: _site/index.html not found"; exit 1; }

      - name: Deploy to Azure Blob ($web container)
        uses: bacongobbler/azure-blob-storage-upload@main
        with:
          source_dir: _site
          container_name: '$web'      # quote $web — see Troubleshooting
          account_name: ${{ secrets.STORAGE_ACCOUNT_NAME }}
          sas_token: ${{ secrets.SAS_TOKEN }}
          overwrite: 'true'
          sync: 'true'                # use az storage blob sync (removes stale blobs)
```

### 7.1 Choosing upload vs. sync (critical for metadata-driven sites)

CollectionBuilder generates one HTML page per object from the CSV. When you **remove or rename** an object in `_data/`, the old generated page is no longer in `_site`. The deploy mode determines whether the stale page stays live:

- **`sync: 'false'` (upload-batch, default)** — `az storage blob upload-batch --overwrite` only adds/overwrites. Removed item pages **stay live** on the site. Safer (no deletes), but stale content persists.
- **`sync: 'true'`** — uses `az storage blob sync`, which mirrors `_site` to `$web` and **deletes blobs that no longer exist in the source**. The SAS must include the `d` (delete) and `l` (list) permissions ([bacongobbler/azure-blob-storage-upload](https://github.com/bacongobbler/azure-blob-storage-upload)).

For a metadata-driven collection where removed items should disappear from the live site, use `sync: 'true'`. Test on a throwaway storage account first — sync with delete is irreversible (enable blob **soft delete** on the storage account as a safety net, per [Microsoft Learn — azcopy sync](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-blobs-synchronize)).

> Security note: this workflow references `bacongobbler/azure-blob-storage-upload@main` to match the action's published README. For institutional or security-conscious repositories, pin the action to a specific commit SHA after you validate it, rather than tracking `@main`.

---

## 8. Deploy and verify

1. Commit the workflow file and push to `main` (or run via **Actions → Run workflow** for `workflow_dispatch`).
2. Watch the **Actions** tab. The build step can take noticeably longer than `jekyll serve` because it generates all item pages in production mode ([CollectionBuilder Docs — Jekyll Build](https://collectionbuilder.github.io/cb-docs/docs/deploy/build/)).
3. On success, open the **primary endpoint** URL from Section 4.2. The homepage should load and `index.html` should render (not download) as HTML.
4. Spot-check a generated item page and the `404.html` (request a non-existent path) to confirm the error document works.

---

## 9. Troubleshooting

### 9.1 Jekyll / CollectionBuilder build errors

| Symptom | Cause | Fix |
|---|---|---|
| `bundle exec jekyll build` fails locally but worked before | Ruby version mismatch between local and CI | Pin `ruby-version` in the workflow to match your local Ruby (e.g. `3.2`). CollectionBuilder templates target a specific Ruby/Jekyll combo ([CollectionBuilder Docs — Jekyll Build](https://collectionbuilder.github.io/cb-docs/docs/deploy/build/)). |
| `Bundler::GemNotFound` / lockfile drift in CI | `Gemfile.lock` not committed, or out of sync with `Gemfile` | Commit `Gemfile.lock`; run `bundle install` locally and commit the updated lock. |
| `cannot load such file -- webrick` | Older Jekyll on Ruby 3.0+ where `webrick` is no longer a default gem | Run `bundle add webrick` (adds it to the `Gemfile` and updates the lock), then commit. |
| `Invalid YAML` / unexpected token in `_config.yml` | YAML errors: unquoted colons, bad indentation, tabs | Quote values containing colons (e.g. `title: "My: Collection"`), use spaces not tabs, and validate indentation. CollectionBuilder metadata docs recommend Google Sheets over Excel to avoid encoding issues ([CollectionBuilder Docs — Metadata](https://collectionbuilder.github.io/cb-docs/docs/metadata/)). |
| Build succeeds but item pages are missing or broken | CSV metadata problems: malformed quotes, BOM/encoding, duplicate `objectid`, missing required fields, bad header names | Open the CSV in a plain-text editor; ensure UTF-8 without BOM; verify every row has a unique `objectid` and required fields per the CB-CSV template ([CollectionBuilder Docs — Add Your Metadata](https://collectionbuilder.github.io/cb-docs/docs/metadata/uploading/)). |
| Links/asset paths 404 on the live site | Wrong `url`/`baseurl` in `_config.yml` (e.g. leftover `baseurl: /repo-name` from GitHub Pages) | Set `url` to the Azure primary endpoint (or custom domain) and `baseurl: ""`, then rebuild ([CollectionBuilder Docs — Deploy](https://collectionbuilder.github.io/cb-docs/docs/deploy/)). |
| Build succeeds locally but fails on the GitHub runner (or vice versa) | **Case-sensitivity**: macOS is case-insensitive; the Ubuntu runner and Azure blob names are case-sensitive | Use consistent, exact-case filenames for objects, thumbnails, and CSV-referenced paths. A path that works on macOS can 404 on Azure. |
| CSV-referenced object URLs return 404 | Objects referenced by remote URL in the CSV are unreachable or case-mismatched | Verify each object/thumbnail URL in the CSV resolves; use the exact case and full HTTPS URL per the metadata object-path recipes ([CollectionBuilder Docs — Object Locations](https://collectionbuilder.github.io/cb-docs/docs/metadata/object-paths/)). |

### 9.2 Azure static website hosting pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| Site returns the Azure "StaticWebsiteNotEnabled" / container missing page | Static website hosting not enabled, so `$web`/endpoint do not exist | Run the `az storage blob service-properties update --static-website ...` command from Section 4.1 ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website-how-to)). |
| Browsing the **blob endpoint** (`...blob.core.windows.net/$web/...`) downloads files instead of rendering a site | You are hitting the blob endpoint, not the static-website primary endpoint | Use the `primaryEndpoints.web` URL (Section 4.2), which serves `$web` as a website ([Microsoft Learn — Static website hosting](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website)). |
| `container not found` / empty container name in CI | `$web` was **unquoted**, so the shell expanded `$web` as an environment variable (often empty) | Always quote it: `container_name: '$web'` and `-d '$web'` ([Microsoft Learn — Host a static website](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website-how-to); [Stack Overflow](https://stackoverflow.com/questions/77344887/unable-to-upload-to-web-from-github-actions)). |
| `AuthenticationFailed` / `AuthorizationFailure` in deploy step | SAS expired, wrong scope, missing permissions, or `?`-prefix inconsistency | Regenerate a container-scoped SAS with `sp=racwdl`; store without the leading `?`; confirm expiry is in the future ([Microsoft Learn — Create a service SAS](https://learn.microsoft.com/en-us/rest/api/storageservices/create-service-sas)). |
| Sync step fails to delete stale blobs | SAS missing `d` (delete) and `l` (list) permissions | Regenerate the SAS with `sp=racwdl` (sync needs list + delete) ([bacongobbler/azure-blob-storage-upload](https://github.com/bacongobbler/azure-blob-storage-upload)). |
| Removed CSV items still appear on the live site | Deploy used `upload-batch` (overwrite only), which never deletes | Set `sync: 'true'` so `az storage blob sync` removes blobs absent from `_site`; ensure SAS includes `d` and `l` (use `sp=racwdl`) ([bacongobbler/azure-blob-storage-upload](https://github.com/bacongobbler/azure-blob-storage-upload)). |
| Unexpected deletion of blobs | `az storage blob sync` lists `--delete-destination` default as **`true`** in current Azure CLI docs (note: this differs from `azcopy sync`, whose default is `false`) | This is intended for mirroring, but **test first** on a non-production container and enable blob soft delete as a safety net ([Microsoft Learn — az storage blob](https://learn.microsoft.com/en-us/cli/azure/storage/blob); [Microsoft Learn — azcopy sync](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-blobs-synchronize)). |
| `index.html` downloads instead of rendering | Content-Type not set to `text/html` | `upload-batch` infers content types from extensions; if a file lacks an `.html` extension, set `--content-type 'text/html; charset=utf-8'` ([Microsoft Learn — Host a static website](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website-how-to)). |
| JSON/JS/CSS/CSV downloads or shows stale content | Wrong or overly aggressive `Cache-Control` on those types | Set appropriate content types and modest cache durations; for JSON data downloads (e.g. `geodata.json`), lower cache time so metadata updates propagate ([CollectionBuilder Docs — data.md](https://github.com/CollectionBuilder/collectionbuilder-csv/blob/main/docs/data.md)). |
| Site unreachable over the public endpoint | Storage account **firewall / public network access** is restricted | Under **Networking**, allow public access from the networks/locations needed, or front with a CDN that has a service-tag/origin allow-list. |
| Custom domain shows old content after redeploy | CDN cache in front of the blob endpoint is stale | Purge the CDN endpoint after deploy, e.g. `az cdn endpoint purge --content-paths "/*" ...` ([Microsoft Learn — GitHub Actions deploy](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-static-site-github-actions)). |
| Old/new site mixed after switching from GitHub Pages | Stale blobs from a prior deploy remain alongside new ones | Run a one-time clean: list `$web`, delete all blobs, then run the sync deploy so the container mirrors `_site` exactly. |

---

## 10. Quick reference

```bash
# Enable static website hosting (creates $web)
az storage blob service-properties update \
  --account-name <acct> --static-website \
  --index-document index.html --404-document 404.html

# Get the public URL
az storage account show -n <acct> -g <rg> --query "primaryEndpoints.web" -o tsv

# Generate container-scoped SAS (store WITHOUT leading ?)
az storage container generate-sas --account-name <acct> --name '$web' \
  --permissions racwdl --expiry 2026-12-31T23:59:00Z --protocols https -o tsv

# Manual one-off deploy (upload only) — assumes `az login` already ran,
# OR pass --sas-token "$SAS_TOKEN" (without leading ?) instead of key auth.
az storage blob upload-batch --account-name <acct> -d '$web' -s _site --overwrite

# Manual mirror deploy (removes stale blobs) — same auth note applies.
az storage blob sync --account-name <acct> --container '$web' \
  --source _site --delete-destination true
```

**Key commands and facts:**

- Local build: `rake deploy` = `JEKYLL_ENV=production bundle exec jekyll build` → output in `_site` ([CollectionBuilder Docs](https://collectionbuilder.github.io/cb-docs/docs/deploy/build/)).
- Static website served from `$web` via the **primary endpoint** (`...web.core.windows.net`), not the blob endpoint ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website)).
- Quote `$web` everywhere; default `--delete-destination` is `true` for `az storage blob sync` but `false` for `azcopy sync` ([Microsoft Learn — az storage blob](https://learn.microsoft.com/en-us/cli/azure/storage/blob); [Microsoft Learn — azcopy sync](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-blobs-synchronize)).
- Container SAS permission order is `racwdl`; sync-with-delete needs `racwdl` ([Microsoft Learn — Create a service SAS](https://learn.microsoft.com/en-us/rest/api/storageservices/create-service-sas)).

---

## 11. Sources

- [CollectionBuilder-CSV README (GitHub)](https://github.com/CollectionBuilder/collectionbuilder-csv)
- [CollectionBuilder Docs — Deploy overview](https://collectionbuilder.github.io/cb-docs/docs/deploy/)
- [CollectionBuilder Docs — Jekyll Build (`rake deploy`)](https://collectionbuilder.github.io/cb-docs/docs/deploy/build/)
- [CollectionBuilder Docs — GitHub Actions](https://collectionbuilder.github.io/cb-docs/docs/deploy/actions/)
- [CollectionBuilder Docs — CSV Walkthrough](https://collectionbuilder.github.io/cb-docs/docs/walkthroughs/csv-walkthrough/)
- [CollectionBuilder Docs — Add Your Metadata](https://collectionbuilder.github.io/cb-docs/docs/metadata/uploading/)
- [CollectionBuilder Docs — Metadata](https://collectionbuilder.github.io/cb-docs/docs/metadata/)
- [CollectionBuilder Docs — CSV Object Locations](https://collectionbuilder.github.io/cb-docs/docs/metadata/object-paths/)
- [CollectionBuilder Docs — data.md (`geodata.json`)](https://github.com/CollectionBuilder/collectionbuilder-csv/blob/main/docs/data.md)
- [Microsoft Learn — Static website hosting in Azure Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website)
- [Microsoft Learn — Host a static website in Azure Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website-how-to)
- [Microsoft Learn — Use GitHub Actions to deploy a static site to Azure Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-static-site-github-actions)
- [Microsoft Learn — az storage blob (CLI reference)](https://learn.microsoft.com/en-us/cli/azure/storage/blob)
- [Microsoft Learn — Synchronize with Azure Blob storage by using AzCopy](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-blobs-synchronize)
- [Microsoft Learn — Create a service SAS (signed permissions)](https://learn.microsoft.com/en-us/rest/api/storageservices/create-service-sas)
- [bacongobbler/azure-blob-storage-upload (GitHub Action)](https://github.com/bacongobbler/azure-blob-storage-upload)
