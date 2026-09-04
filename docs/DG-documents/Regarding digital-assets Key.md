The breakage is expected: you changed the HTML references to your Azure asset host, but that host has not yet been populated with the required library files. I’ll check the `$web/assets/` contents and the repository’s available library sources to give you a concrete setup command.

Execution complete: Inspect Azure shared assets

Ran terminal command:  `if [ -f .env ]; then echo 'Sourcing .env'; . ./.env; fi && echo '--- Azure account ---' && az account show --output json 2>/dev/null || echo 'Azure CLI not logged in; try az login' && echo '--- Azure blob listing ---' && az storage blob list --account-name digitalgrinnell --container-name '$web' --prefix 'assets/' --auth-mode login --output json --query "[0:100].name" 2>&1 && echo '--- Repo asset/library scan ---' && find . \( -path './_site' -o -path './.jekyll-cache' \) -prune -o \( -iname 'bootstrap5' -o -iname 'leaflet' -o -iname 'spotlight.bundle.js' -o -iname 'lazysizes.min.js' -o -iname 'datatables.min.js' -o -iname 'MarkerCluster.css' -o -iname 'leaflet.fullscreen.css' \) -print | sort`

The Azure asset folder contains this project’s own CSS/data files but lacks the vendor libraries referenced by `digital-assets`; meanwhile the Iowa State branding comes from separate `organization-*` settings, not this key. I’m checking the exact expected Azure paths now so the correction is precise.

Execution complete: Verify vendor asset paths

`digital-assets` controls only the browser URLs for shared vendor libraries. It does not control the Iowa State organization name or logo; those still come from these separate keys:

```yml
organization-name:
organization-link:
organization-logo-banner:
organization-logo-nav:
```

Your CSS/JavaScript is broken because the current Azure `$web/assets/` folder has this project’s files, but it **does not contain** the vendor files referenced by the templates:

```text
assets/bootstrap5/bootstrap.min.css
assets/bootstrap5/bootstrap.bundle.min.js
assets/bootstrap5/datatables/datatables.min.css
assets/bootstrap5/datatables/datatables.min.js
assets/js/lazysizes.min.js
assets/js/spotlight.bundle.js
assets/leaflet/...
```

## What to set now

For now, restore the existing Iowa State asset host on both `main` and `tdps`:

```yml
digital-assets: https://isuu00001library102stg.z21.web.core.windows.net/assets
```

That is the correct immediate setting because those library files already exist there. `rake deploy` will generate HTML that links to that host, and local `bundle exec jekyll serve` should load the CSS and JavaScript again.

## When to switch to Digital Grinnell Azure assets

Set this on both branches only **after** you have populated your Azure static site with a complete shared library tree:

```yml
digital-assets: https://digitalgrinnell-secondary.z19.web.core.windows.net/assets
```

The corresponding Azure blob layout must be:

```text
$web/assets/bootstrap5/bootstrap.min.css
$web/assets/bootstrap5/bootstrap.bundle.min.js
$web/assets/bootstrap5/datatables/datatables.min.css
$web/assets/bootstrap5/datatables/datatables.min.js
$web/assets/js/lazysizes.min.js
$web/assets/js/spotlight.bundle.js
$web/assets/leaflet/leaflet.css
$web/assets/leaflet/leaflet.fullscreen.css
$web/assets/leaflet/leaflet.fusesearch.css
$web/assets/leaflet/MarkerCluster.css
$web/assets/leaflet/MarkerCluster.Default.css
```

There may be additional supporting files, especially Leaflet image assets and any JavaScript files required by pages using maps, galleries, or tables. Copy the complete vendor directories, not only the CSS files.

This is a one-time shared infrastructure upload to `$web/assets/`. Do not upload it below `$web/tdps/assets/`; every collection branch should use the same root-level asset URL.

## Branch Settings

```yml
# main
baseurl:
metadata: digital_collections
digital-assets: https://isuu00001library102stg.z21.web.core.windows.net/assets

# tdps
baseurl: "/tdps"
metadata: tdps
digital-assets: https://isuu00001library102stg.z21.web.core.windows.net/assets
```

After the Azure asset library has been copied and tested, change only `digital-assets` on both branches to the Digital Grinnell URL. `baseurl` and `metadata` remain branch-specific.

Created 4 todos