Azure Blob Storage’s **Static website** feature is a straightforward fit for a Jekyll/CollectionBuilder deployment: Jekyll builds the repository into ordinary static files, then a deployment process uploads that generated directory into the storage account’s special `$web` container. Azure serves those files at the static-site endpoint; it does not run Jekyll itself. [learn.microsoft](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website-host)

## How the pieces fit

For a CollectionBuilder site, the deployment pipeline is typically:

```text
GitHub repo (Jekyll source)
        ↓
bundle exec jekyll build
        ↓
_site/  (HTML, CSS, JS, images, JSON, downloads)
        ↓
az storage blob upload-batch … -d '$web' -s _site
        ↓
Azure Blob Storage static-website endpoint / custom domain
```

The `$web` container is created automatically when **Static website** is enabled on an Azure Storage account. Azure is configured with an index document, conventionally `index.html`, plus an error document such as `404.html`. [learn.microsoft](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website-host)

In your case, the digital-object containers remain normal blob containers, while `$web` contains the derived public website. The resulting Jekyll site can reference object files using public blob URLs, a custom asset domain, or whatever URL conventions Digital Grinnell has established.

## Repository findings

I attempted to retrieve the GitHub repository and its workflow directory directly, but GitHub did not return readable content through this environment, so I can’t honestly identify the repo’s precise current deployment script or credential strategy.

The most useful places to inspect in that repository are:

- `.github/workflows/*.yml` — automated build/deploy workflow, if GitHub Actions is used.
- `Gemfile` and `Gemfile.lock` — Ruby/Jekyll version and plugins required in CI.
- `_config.yml` — notably `url`, `baseurl`, `destination`, collection configuration, and any blob/CDN URL variables.
- `scripts/`, `Rakefile`, `Makefile`, or deployment documentation — a local/manual deploy may be scripted here.
- GitHub **Actions** tab — historical workflow runs sometimes reveal deployment commands even where a workflow was later moved or removed.
- GitHub **Settings → Secrets and variables → Actions** — secret *names* reveal the deployment approach, though not their values.

## A modern GitHub Actions pattern

This is a good baseline workflow for CollectionBuilder/Jekyll. It uses GitHub-to-Azure OpenID Connect authentication rather than storing a long-lived storage key, connection string, or SAS token in GitHub.

```yaml
name: Build and deploy CollectionBuilder site

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Check out source
        uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.3"
          bundler-cache: true

      - name: Build Jekyll site
        run: bundle exec jekyll build --destination _site

      - name: Sign in to Azure
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Synchronize generated site to $web
        run: |
          az storage blob sync \
            --account-name YOUR_STORAGE_ACCOUNT \
            --container '$web' \
            --source _site \
            --auth-mode login \
            --delete-destination true

      - name: Sign out of Azure
        if: always()
        run: az logout
```

Microsoft’s official example uses `az storage blob upload-batch` to deploy files to `$web`; `az storage blob sync` is often preferable for a production static site because `--delete-destination true` removes files that no longer exist in the new Jekyll build. Without that cleanup, old pages and assets can remain publicly reachable after a rename or deletion. [learn.microsoft](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-static-site-github-actions)

## Azure setup required

1. Enable **Static website** on the target storage account.
2. Set:
   - Index document: `index.html`
   - Error document: `404.html`
3. Configure a GitHub Actions identity:
   - Create or use an Entra application/service principal.
   - Grant it a narrowly scoped data-plane role such as **Storage Blob Data Contributor** on the storage account or, preferably, only on the `$web` container where practical.
   - Create a federated credential that trusts the specific GitHub repository, branch, and/or deployment environment.
4. Add these GitHub secrets:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`
5. Configure DNS/custom domain and optionally Azure Front Door or CDN.

Azure’s documentation specifically supports GitHub Actions authentication by OIDC or a service principal and uses the Azure CLI to upload the static-site output to `$web`. [learn.microsoft](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-static-site-github-actions)

## Details specific to Jekyll

The deployment tool must upload **the build output**, usually `_site/`, not the Jekyll project root. The source tree includes Liquid templates, Markdown, Ruby configuration, `_includes`, `_layouts`, and other files Azure cannot process.

For CollectionBuilder, this is especially important because the generated output commonly includes:

- Page HTML for item, browse, timeline, map, subject, and feature pages.
- CSV/JSON search data and Lunr indexes.
- Generated image derivatives or thumbnails, depending on configuration.
- JavaScript, CSS, webfonts, and site assets.
- Item/download URLs that may point to separate Azure blob containers.

Before deploying, test with:

```bash
bundle exec jekyll build
bundle exec jekyll serve
```

Then verify that `_site/index.html`, `_site/404.html`, and expected data/assets actually exist.

## Practical cautions

- **URL configuration:** Set Jekyll’s production `url` to the custom public domain, not the `web.core.windows.net` endpoint, if users access the site through a custom hostname.
- **Absolute vs. relative URLs:** CollectionBuilder templates and metadata values can embed URLs. Confirm image, object, manifest, and download fields resolve correctly from the production domain.
- **No server-side routing:** Blob Static Website hosting is file-based. Jekyll’s `about/index.html` works at `/about/`; a SPA-style route without a matching object will not.
- **Headers and access control:** Azure Blob static website hosting does not itself offer site-level authentication/authorization or flexible response-header configuration. Microsoft recommends Azure Static Web Apps when those capabilities are required; otherwise, place CDN/Front Door in front for caching and header policies. [learn.microsoft](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website-host)
- **Caching:** If a CDN sits in front, purging it—or using cache-safe hashed asset filenames—is important after deployment. Microsoft’s GitHub Actions example includes a CDN purge step. [learn.microsoft](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-static-site-github-actions)
- **Secrets:** Avoid using a long-lived account key or SAS token unless OIDC cannot be used. A published Jekyll-to-Azure example uses a SAS token and uploads directly to `$web`, which demonstrates the older working model, but federated identity is the stronger design. [bene](https://www.bene.haus/blog-setup/)

## Relevant examples

- Microsoft documents enabling the feature and explains that `$web` is the container automatically created to hold static-site files. [learn.microsoft](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website-host)
- Microsoft’s GitHub Actions guide provides the Azure login plus `az storage blob upload-batch … -d '$web'` deployment model. [learn.microsoft](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-static-site-github-actions)
- A Jekyll-specific walkthrough shows the same conceptual pipeline: Jekyll build output uploaded to the `$web` container via GitHub Actions. [bene](https://www.bene.haus/blog-setup/)

The key question for the Digital Grinnell repository is therefore not whether Jekyll can run *in* Azure Blob Storage—it cannot—but where its Jekyll build occurs: locally, a GitHub Actions runner, Azure DevOps, or another CI host. Once compiled, it is simply a static file synchronization into `$web`.