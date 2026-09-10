# collection-template branch

This branch is the starting point for new Digital Grinnell item collections. It is
`tdps` with collection-specific data and branding stripped out and replaced with
placeholders, so it already carries the item-collection machinery that `main`
(the portal branch) intentionally does not have:

- `_plugins/cb_page_gen.rb` (generates `/items/<objectid>.html` pages)
- `pages/collections.md` configured as the item browse page (`layout: browse`,
  `permalink: /browse.html`)
- `_includes/js/browse-js.html` filtering on `objectid`/`parentid` and linking to
  generated item pages
- `_data/config-nav.csv` with item-collection navigation (`Browse`, `Subjects`,
  `Locations`, `Map`, `Timeline`, `Data`, `About`)
- `_data/collection-template.csv`, a placeholder metadata CSV using the standard
  CollectionBuilder fields from `_data/config-metadata.csv`

To start a new collection:

```sh
git switch collection-template
git pull --ff-only origin collection-template
git switch -c my-new-collection
mv _data/collection-template.csv _data/my-new-collection.csv
```

Then follow `docs/DG-documents/Creating and Managing a Digital Content Collection.md`
starting at "Configure the collection site" — update `_config.yml` (`baseurl`,
`metadata`), replace the placeholder CSV with real item metadata, and replace the
`TEMPLATE TODO` markers in `pages/about.md`, `pages/faq.md`, and `_data/theme.yml`
with real collection content.

Do not merge `collection-template` into `main`, and do not merge collection
branches into `collection-template`. Keep it a clean, minimal starting point.
