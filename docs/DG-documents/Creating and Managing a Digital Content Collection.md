# Creating and Managing a Digital Content Collection

This runbook describes the Digital Grinnell model for publishing a collection as an independent CollectionBuilder site. It uses the Theatre, Dance and Performance Studies Production Archive (`tdps`) as its example.

## Deploy the main site

Use this procedure only to publish the root Digital Grinnell directory site from the `main` branch. It uploads the generated site directly to the Azure static website's `$web` container, replacing root files such as `index.html` and `collections.html`.

```sh
git switch main
git pull --ff-only origin main

rake deploy

source .env
az storage blob upload-batch \
  --destination '$web' \
  --source _site \
  --overwrite
```

`rake deploy` sets `JEKYLL_ENV=production` and builds the current branch into `_site/`. `source .env` loads the local Azure account and authentication-mode settings; the file is untracked and must not contain a storage key or SAS token.

Do not include `--destination-path` when deploying `main`. A destination path such as `tdps` publishes a collection below `$web/tdps/` and does not replace the root directory site.

After the upload completes, verify the root site and its collection directory:

```text
https://digitalgrinnell-secondary.z19.web.core.windows.net/
https://digitalgrinnell-secondary.z19.web.core.windows.net/collections.html
```

## The publishing model

One repository serves two different purposes:

| Purpose | Git branch | Jekyll metadata | Azure destination | Public URL |
| --- | --- | --- | --- | --- |
| Directory of all Digital Grinnell collections | `main` | `_data/digital_collections.csv` | `$web/` | `https://digitalgrinnell-secondary.z19.web.core.windows.net/` |
| One item-level collection | `tdps` | `_data/tdps.csv` | `$web/tdps/` | `https://digitalgrinnell-secondary.z19.web.core.windows.net/tdps/` |

The `main` branch is the outer directory. It contains one row for each published collection and points visitors to collection sites.

Each collection branch is an independent item site. It contains the collection's item metadata, CollectionBuilder item-page generator, item browse page, collection-specific navigation, and collection branding. The branch name does not create an Azure URL on its own. The public subdirectory is created by the combination of `baseurl` during the Jekyll build and `--destination-path` during upload.

## Requirements before starting

- Ruby, Bundler, and the repository gems are installed.
- `bundle exec jekyll build` completes on the local machine.
- Azure CLI is authenticated with an account that can write blobs to the `digitalgrinnell` storage account's `$web` container.
- The untracked `.env` file defines the local Azure settings. It must never contain or expose a storage key or SAS token in Git.
- Item metadata is available as a UTF-8 CSV with a header row and stable, unique `objectid` values.

The local Azure deployment commands use Microsoft Entra login authentication. Before deploying, load the local settings:

```sh
source .env
```

If the Azure CLI session has expired, sign in again:

```sh
az login
```

## Create a collection branch

Start from a current `main` branch. Substitute the collection slug everywhere shown as `tdps`.

```sh
git switch main
git pull --ff-only origin main
git switch -c tdps
```

From this point onward, edits to `_config.yml`, pages, templates, and `_data/tdps.csv` belong to the `tdps` branch. Do not make collection-specific changes on `main`.

## Add item metadata

Put the collection's item-level data in:

```text
_data/tdps.csv
```

The CSV base name and Jekyll configuration must match:

```text
_data/tdps.csv  <->  metadata: tdps
```

`_data/digital_collections.csv` is not an item-metadata template. It is the `main` branch's directory/catalog data and has a different schema. Do not copy it as the starting point for an item collection.

At a minimum, every public top-level item needs a unique non-empty `objectid`. CollectionBuilder uses it to generate an item page named `items/<objectid>.html`.

TDPS contains compound objects. Its rows with a `parentid` are child records, so they should normally not appear as separate top-level browse cards. The page generator and browse script intentionally use top-level records only. Leave `parentid` blank for parent/top-level items and set it for children.

Before building, check that object IDs are present and unique. The following command reports the number of data rows, missing IDs, and duplicate IDs without changing the CSV:

```sh
ruby -rcsv -e '
rows = CSV.table("_data/tdps.csv", headers: true)
ids = rows.map { |row| row[:objectid].to_s.strip }
puts "records: #{rows.length}"
puts "missing objectid: #{ids.count(&:empty?)}"
puts "duplicate objectid: #{ids.reject(&:empty?).tally.select { |_, count| count > 1 }.length}"
'
```

Rows without `objectid` are skipped. In the current TDPS data, 15 rows are skipped for this reason; the verified build generates 73 top-level item pages.

## Configure the collection site

Edit the root-level `_config.yml` while the collection branch is checked out. These are active YAML keys, not comments:

```yml
url: "https://digitalgrinnell-secondary.z19.web.core.windows.net"
baseurl: "/tdps"
metadata: tdps
```

The three collection identifiers must agree:

```text
metadata: tdps                 -> reads _data/tdps.csv
baseurl: "/tdps"              -> generates internal links below /tdps/
--destination-path tdps        -> uploads files below $web/tdps/
```

The `url` value identifies the public host, not a Git branch. `baseurl` identifies the collection's location below that host.

### CollectionBuilder page generator

The collection branch must include `_plugins/cb_page_gen.rb`. This plugin generates the static item pages from the CSV. Its default behavior is appropriate for an item collection:

- Reads the data file named by `metadata`.
- Requires an `objectid`.
- Generates pages in `_site/items/`.
- Uses `display_template` to select an item layout, falling back to the generic `item` layout.
- Excludes child rows with `parentid` by default.

Do not assume a successful Jekyll build means that item pages exist. A missing generator can allow the build to finish while producing no `_site/items/` directory.

### Shared JavaScript and CSS assets

The `digital-assets` setting is not created by `rake deploy`. It is a URL prefix used by templates to load shared vendor files such as Bootstrap, Leaflet, DataTables, lazysizes, and Spotlight.

The Digital Grinnell Azure `$web/assets/` directory does not currently contain the complete vendor library tree. Therefore, retain the Iowa State shared asset host until the Digital Grinnell replacement has been uploaded and tested:

```yml
digital-assets: https://isuu00001library102stg.z21.web.core.windows.net/assets
```

Use the same `digital-assets` value on `main` and every collection branch. Do not add `/tdps` to it.

Only change it after all required vendor files are present under the root Azure asset path:

```yml
digital-assets: https://digitalgrinnell-secondary.z19.web.core.windows.net/assets
```

Expected examples include:

```text
$web/assets/bootstrap5/bootstrap.min.css
$web/assets/bootstrap5/bootstrap.bundle.min.js
$web/assets/bootstrap5/datatables/datatables.min.css
$web/assets/bootstrap5/datatables/datatables.min.js
$web/assets/js/lazysizes.min.js
$web/assets/js/spotlight.bundle.js
$web/assets/leaflet/leaflet.css
$web/assets/leaflet/leaflet.fullscreen.css
$web/assets/leaflet/MarkerCluster.css
$web/assets/leaflet/MarkerCluster.Default.css
```

Copy complete vendor directories, including supporting Leaflet images and JavaScript, rather than only the files listed above.

### Branding and content

Collection-specific branding is controlled by `_config.yml` and collection pages, not by `digital-assets`. Set the organization values for Digital Grinnell:

```yml
title: Digital Grinnell
organization-name: "Digital Grinnell"
organization-link: https://www.grinnell.edu/academics/libraries
organization-logo-banner: https://digitalgrinnell.blob.core.windows.net/theme-elements/grinnell-college-logo.png
organization-logo-nav: https://digitalgrinnell.blob.core.windows.net/theme-elements/grinnell-college-logo.png
```

The TDPS branch uses the configurable `_includes/footer.html` through `_layouts/default.html`. This avoids the inherited hard-coded Iowa State footer. Its homepage, `pages/index.html`, is collection-specific and links to `/browse.html`.

Review inherited content before publication. In this repository, `pages/about.md`, `pages/faq.md`, `_data/banner-feature-images.csv`, and some legacy templates contain Iowa State text or links. Keep only pages that are appropriate for the collection, or rewrite them for Digital Grinnell.

## Browse, navigation, and item links

An item collection must use an item browse page, not the portal's collection directory page.

For TDPS, the browse page is defined in `pages/collections.md` with these values:

```yml
title: Browse Items
layout: browse
permalink: /browse.html
```

The browse JavaScript must select top-level item records with an `objectid` and create local item links:

```liquid
{%- assign items = site.data[site.metadata] | where_exp: 'item','item.objectid and item.parentid == nil' -%}
```

Each card links to the generated static item page:

```liquid
{{ '/items/' | relative_url }}{{ item.objectid | slugify: 'pretty' }}.html
```

Apply that same link to the card's thumbnail image, not only the title text and the "Visit Collection" button. The stock browse card markup in `_includes/js/browse-js.html` does not wrap the `<img>` in an `<a>`; without that change, clicking the title or button navigates correctly, but clicking the picture itself does nothing.

Do not use the portal-only filter `item.status == "published"` for item metadata. That field belongs to `digital_collections.csv`, where each row describes an entire collection. TDPS item rows do not use it, which previously resulted in a `0 of 0 items` browse display.

A fresh checkout of `main` still carries the portal defaults for all three of these: `pages/collections.md` has `title: Browse Collections` and `permalink: /collections.html`, and `_includes/js/browse-js.html` filters on `item.status == "published"` and links to the external `item.url` with an unlinked thumbnail. That is correct for `main`'s own portal directory page (see "Starting a second collection branch" below) but must be edited on every new item-collection branch.

Collection navigation should route to item-site pages. The current TDPS configuration uses:

```csv
display_name,stub,dropdown_parent
Home,/
Browse,/browse.html
Subjects,/subjects.html
Locations,/locations.html
Map,/map.html
Timeline,/timeline.html
Data,/data.html
About,/about.html
```

With `baseurl: "/tdps"`, Jekyll turns `/browse.html` into `/tdps/browse.html` in generated HTML.

## Build and validate locally

Build the branch with production settings:

```sh
rake deploy
```

In this repository, `rake deploy` sets `JEKYLL_ENV=production` and runs:

```sh
bundle exec jekyll build
```

It reads `_config.yml` from the currently checked-out branch and writes the static output to `_site/`. It does not upload to Azure.

For an isolated validation build that does not overwrite the normal `_site/` directory:

```sh
bundle exec jekyll build --destination /tmp/tdps-site-check
```

Confirm the expected pages exist:

```sh
test -f /tmp/tdps-site-check/index.html
test -f /tmp/tdps-site-check/browse.html
find /tmp/tdps-site-check/items -maxdepth 1 -name '*.html' -type f | wc -l
```

For TDPS, the final command should report `73` with the current metadata. A result of zero means that the page generator is missing, the configured metadata file is not being loaded, or the data has no valid top-level `objectid` records.

Validate generated links before upload:

```sh
grep -q 'var items = \[\]' /tmp/tdps-site-check/browse.html && echo "ERROR: browse data is empty"
grep -q '/tdps/items/' /tmp/tdps-site-check/browse.html && echo "Item links include the baseurl"
```

Use a local server for visual review:

```sh
bundle exec jekyll serve
```

When `baseurl: "/tdps"` is set, open:

```text
http://127.0.0.1:4000/tdps/
```

The root local URL, `http://127.0.0.1:4000/`, can correctly return the configured 404 page because the collection is built for the `/tdps/` path.

Check:

- Home page title and organization logo.
- `/tdps/browse.html` shows expected items rather than `0 of 0`.
- A browse-card link opens `/tdps/items/<objectid>.html`.
- A compound-object parent and child display correctly.
- Browser developer tools show no missing CSS or JavaScript resources.
- `git diff --check` reports no whitespace errors for the files being committed.

## Deploy the collection to Azure

Build from the collection branch first:

```sh
git switch tdps
rake deploy
```

Upload the generated `_site/` directory into the matching Azure subdirectory:

```sh
source .env

az storage blob upload-batch \
  --destination '$web' \
  --destination-path tdps \
  --source _site \
  --overwrite
```

Quote `'$web'` exactly as shown. The quotes prevent the shell from expanding `$web` as an environment variable.

The upload maps local files to Azure blobs as follows:

```text
_site/index.html                         -> $web/tdps/index.html
_site/browse.html                        -> $web/tdps/browse.html
_site/items/dg_1781276069.html           -> $web/tdps/items/dg_1781276069.html
_site/assets/css/cb.css                  -> $web/tdps/assets/css/cb.css
```

Then verify the public site:

```text
https://digitalgrinnell-secondary.z19.web.core.windows.net/tdps/
```

`upload-batch --overwrite` adds and overwrites files but does not remove old blobs. When pages or object IDs are renamed or deleted, identify and delete stale blobs deliberately after checking the published site. Do not run a broad root-level sync from a collection branch; it could replace the directory site.

## Add the collection to the root directory

Publishing `$web/tdps/` does not update the root site. To make TDPS appear in the Digital Grinnell directory, edit `main` branch `_data/digital_collections.csv`.

That file uses one row per collection, not one row per item. Include at least a stable `objectid`, title, `status: published`, description, and public collection URL. For example:

```csv
objectid,title,status,url,description,subject
tdps,"Theatre, Dance and Performance Studies Production Archive",published,https://digitalgrinnell-secondary.z19.web.core.windows.net/tdps/,"Photographs, playbills, posters, and other materials documenting Grinnell College productions.","Theatre; Dance; Performance"
```

After updating the directory data, rebuild and deploy `main` to the root with no destination path:

```sh
git switch main
rake deploy

source .env
az storage blob upload-batch \
  --destination '$web' \
  --source _site \
  --overwrite
```

The root deployment updates blobs such as `$web/index.html` and `$web/collections.html`. It does not update a collection under `$web/tdps/` unless the root build happens to contain that path.

## Commit and push

Commit the collection branch after a successful local build and review. Include source changes but not generated `_site/` output unless the repository intentionally tracks it.

```sh
git switch tdps
git status
git add _config.yml _data/tdps.csv _plugins/cb_page_gen.rb \
  _includes/js/browse-js.html pages/collections.md pages/index.html \
  _data/config-nav.csv _layouts/default.html AGENTS.md
git commit -m "Configure TDPS collection site"
git push -u origin tdps
```

Commit the corresponding `main` directory change separately:

```sh
git switch main
git add _data/digital_collections.csv AGENTS.md
git commit -m "Add TDPS to collection directory"
git push origin main
```

Git pushes preserve source history. Azure upload commands publish static output. Neither operation substitutes for the other.

## Update an existing collection

For ordinary metadata or content updates:

```sh
git switch tdps
# edit metadata, pages, or collection configuration
bundle exec jekyll build --destination /tmp/tdps-site-check
# inspect the result
rake deploy

source .env
az storage blob upload-batch \
  --destination '$web' \
  --destination-path tdps \
  --source _site \
  --overwrite

git add <changed-files>
git commit -m "Update TDPS collection"
git push
```

If metadata changes add, rename, or remove object IDs, compare the old and new generated item paths and remove obsolete Azure blobs only after confirming the replacement site. Use precise blob paths rather than deleting broad prefixes casually.

## Starting a second collection branch

Do not branch a new collection from an existing collection branch such as `tdps`. Branch from `main`, as in "Create a collection branch" above. A collection branch carries collection-specific state that a new collection does not want as a starting point: its item CSV, its `_config.yml` values (`baseurl`, `metadata`), its nav CSV, and its homepage content. Branching from `tdps` means immediately deleting or overwriting most of what makes the branch distinct, which is more error-prone than starting clean from `main` and re-applying the small set of item-collection template edits.

Do not cherry-pick `pages/collections.md` or `_includes/js/browse-js.html` from `tdps` onto `main`. These files are shared by both the portal directory page and every item collection's browse page, but each reads it differently: `main`'s `_data/digital_collections.csv` has no `parentid` column and depends on the `item.status == "published"` filter and the external `item.url` link to keep the public directory correct, while `main` has no `_plugins/cb_page_gen.rb` and therefore generates no `/items/` pages at all. Overwriting these files with the `tdps` versions would make every unpublished collection visible on the root directory and send every card to a nonexistent `/items/<objectid>.html` page. The `objectid`/`parentid` filter, the `/items/` link, and the linked thumbnail are correct only for an item collection branch and must be reapplied on each new collection branch, not merged into `main`.

Keep genuinely collection-specific work — item metadata, `_config.yml` identifiers, navigation, branding, and the browse-page filter/link edits — out of `main` and scoped to each collection's own branch.

## Troubleshooting

| Symptom | Likely cause | Correction |
| --- | --- | --- |
| Local root URL returns 404, but `/tdps/` loads | The collection uses `baseurl: "/tdps"` | Test at `http://127.0.0.1:4000/tdps/`. This is expected. |
| Browse page says `0 of 0 items` | The browse code is using the portal `status == "published"` condition, or `metadata` does not match the CSV base name | Filter on `objectid` and top-level `parentid`, and set `metadata: tdps`. |
| `_site/items/` is absent | `_plugins/cb_page_gen.rb` is missing or item records lack valid `objectid` values | Restore the CollectionBuilder page generator and verify item IDs. |
| Browse cards link to an external collection URL | A portal browse template is still in use | Link to `{{ '/items/' | relative_url }}{{ item.objectid | slugify: 'pretty' }}.html`. |
| The site has Iowa State branding | Inherited pages, `lib-footer.html`, or hard-coded navigation are still active | Use configurable `footer.html`, update organization settings, and review retained pages/templates. |
| CSS and JavaScript are missing | `digital-assets` points to Azure before the shared vendor assets have been uploaded | Restore the Iowa State shared asset URL temporarily, or upload and verify the complete vendor tree at `$web/assets/`. |
| Root directory does not list TDPS | The root `main` build has not been redeployed or its catalog data lacks a TDPS row | Update `_data/digital_collections.csv` on `main`, build, and upload `_site` to `$web/` without `--destination-path`. |
| Azure TDPS site works but root site is unchanged | Upload used `--destination-path tdps` | This is expected. Deploy `main` separately to the root. |
| Old item URL remains public after deletion | `upload-batch --overwrite` never deletes blobs | Remove only the known obsolete blobs after validating the new deployment. |
| A browse card's title and button navigate, but clicking the thumbnail image does nothing | The card's `<img>` is not wrapped in the item-page `<a>` | Wrap the thumbnail in the same `href` as the title link in `_includes/js/browse-js.html`. |

## Verified TDPS baseline

On September 4, 2026, the TDPS branch was validated with:

```sh
bundle exec jekyll build --destination /tmp/tdps-final-site-check
```

The build completed successfully, generated 73 top-level item pages, and produced a populated `/browse.html` with `/tdps/items/` links. The 15 rows without `objectid` were excluded by the generator as expected.

On September 9, 2026, a local `bundle exec jekyll serve` review of that same branch found three additional issues, all now fixed and committed on `tdps`:

- `_data/tdps.csv` had one duplicate `objectid` (`tdps_dg_1786459286`, used by two different rows); the second row and its child records were renumbered to a unique ID.
- `pages/collections.md` still had the portal's default `title` and `permalink`, so no `/browse.html` was generated; it was updated to the TDPS values shown above.
- `_includes/js/browse-js.html` still used the portal `item.status == "published"` filter and linked cards to the external `item.url`; it was updated to filter on `objectid`/top-level `parentid` and link to the generated item page, and the thumbnail image was wrapped in that same link.

All TDPS `objectid` and `parentid` values that originated as `dg_...` were also namespaced with a `tdps_` prefix, to avoid collisions if object IDs are ever compared or merged across collections.