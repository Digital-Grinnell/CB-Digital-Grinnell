I’ll trace the outer metadata and any deployment/build machinery that maps a branch to a subdirectory, then inspect reachable Git history and remotes for the original inner-collection branches. This should tell us whether the pattern belongs in Jekyll configuration, Git deployment, or both.

Trace collection deployment design

Searched for text `digital_collections|digital-collections`, 3 results

Searched for text `collection|branch|aaap` (`**/rakelib/**`), 1 result

Searched for text `collection` (`**/_layouts/**`), 11 results

Searched for text `collection` (`**/pages/**`), 82 results

Searched for text `collection` (`**/_includes/**`), 93 results

Searched for text `site.data.digital`, 1 result

Searched for text `branch|origin|upstream|deploy` (`**/docs/**`), 63 results

No matches found. Your search pattern might be excluded completely by either the search.exclude settings or .*ignore files.
If you believe that it should have results, you can check into the .*ignore files and the exclude setting (here are some excluded patterns for reference:[**/node_modules,**/bower_components,**/*.code-search]).
Then if you want to include those files you can call the tool again by setting "includeIgnoredFiles" to true.

Searched for regex `https://digitalcollections|/aaap|/activistag|branch.*deploy|subdirect`, 111 results

No matches found. Your search pattern might be excluded completely by either the search.exclude settings or .*ignore files.
If you believe that it should have results, you can check into the .*ignore files and the exclude setting (here are some excluded patterns for reference:[**/node_modules,**/bower_components,**/*.code-search]).
Then if you want to include those files you can call the tool again by setting "includeIgnoredFiles" to true.

Searched for regex `isu-digital|branch.*aaap|branch.*collection|github.com.*digital`, 4 results

The original model is documented in this repo and is deployment-driven: a branch is not automatically a subdirectory; each branch is built and its `_site` output copied to its matching `$web/<branch>/` prefix. I’ll check the local remote and the original GitHub repository’s available branches to see whether those source branches can be recovered directly.

Execution complete: Inspect available collection branches

Ran terminal command:  `git remote -v && echo '---BRANCHES---' && git branch -a && echo '---REMOTE HEADS---' && git ls-remote --heads https://github.com/isu-digital/digitalcollections.lib.git | sed -n '1,80p'`

Neither the current fork nor the original repository exposes any historical collection branches now, so they cannot be checked out or copied. I’ll read the project’s own deployment notes and task definitions next to turn the recovered pattern into a concrete, repeatable setup for this repository.


The concrete pattern is now clear: `main` is the directory site, while each collection branch is an independent CollectionBuilder site configured with `baseurl: "/<slug>"` and deployed under the corresponding blob prefix. I’ll confirm the exact Azure CLI flag for uploading a build into a virtual subdirectory, then lay out the repeatable workflow without changing the site.

Execution complete: Confirm Azure subdirectory upload

Ran terminal command:  `az storage blob upload-batch --help | sed -n '/Usage:/,/^$/p;/Options:/,/^$/p' | sed '/^$/d' | head -n 220`


You found the key distinction: the old ISU pattern was **one independent CollectionBuilder site per Git branch**, with the branch output uploaded under that branch’s name in Azure.

Neither this fork nor ISU’s current remote retains those branches. Both expose only `main`, so the existing rows in `digital_collections.csv` are a catalog of historic collections, not recoverable branch sources.

**Structure**

| Layer | Git branch | Jekyll `baseurl` | Azure destination | Public URL |
|---|---|---:|---|---|
| Directory/catalog | `main` | `""` | `$web/` | `/` |
| Inner collection | `aaap` | `"/aaap"` | `$web/aaap/` | `/aaap/` |

## Sample Guidance

For a new inner collection named `aaap`:

```zsh
git switch main
git switch -c aaap

# Create/add the collection's item-level metadata:
# _data/aaap.csv

# In _config.yml:
# url: "https://digitalgrinnell-secondary.z19.web.core.windows.net"
# baseurl: "/aaap"
# metadata: aaap

rake deploy

source .env
az storage blob upload-batch \
  --destination '$web' \
  --destination-path aaap \
  --source _site \
  --overwrite
```

The branch’s `_data/aaap.csv` must be an **item metadata** CSV for that one collection. The root `digital_collections.csv` is only the outer directory’s collection-level metadata. Add an outer row whose `objectid` is `aaap` and whose `url` is your public `/aaap/` location.

The branch is not intrinsically special to Azure: it is simply a useful way to isolate the source/configuration of one collection. The actual URL structure comes from:

1. `baseurl: "/aaap"` during the branch build, ensuring asset and internal links include `/aaap`.
2. Uploading the resulting `_site` files with `--destination-path aaap`.

Your root catalog currently has `baseurl` empty, which is correct for the directory site. Its current metadata still points to ISU URLs, so replace those catalog records with your own collection slugs and Digital Grinnell URLs as collections are created.

A sensible next implementation is a small `rake deploy:collection[slug]` task that validates the branch/configuration and uploads `_site` to the matching Azure prefix.