Searched for text `@import` (`**/*.scss`), 2 results

Ran terminal command:  `bundle exec ruby -e "require 'sass-embedded'; puts Sass.info" 2>&1; echo '---'; bundle list | grep -i sass; echo '---'; bundle exec jekyll -v`

Ran terminal command:  `bundle show jekyll-sass-converter`

Ran terminal command:  `grep -rn "silence\|deprecat\|sass_config\|def sass_configs\|OPTIONS\|def convert" /Users/mcfatem/.gem/ruby/3.4.1/gems/jekyll-sass-converter-3.1.0/lib | head -60`

Searched for text `sass:` (`**/_config.yml`), 1 result

These are non-fatal warnings (build exit code is 0) coming from Dart Sass 1.87 flagging the old `@import` syntax, which will only actually break in Dart Sass 3.0. Rewriting to the module system (`@use`/`@forward`) is risky here because `cb.scss` computes theme variables via Liquid and relies on `@import`'s shared global scope to pass them into the Bootstrap-style partials — converting that correctly without visual regressions is a much larger job than warranted right now. I'll silence the warning at the compiler level instead. 

Execution complete: Rebuild site and check warnings

Ran terminal command:  `bundle exec jekyll build > /tmp/cb_digital_grinnell_jekyll_build.log 2>&1; exit_code=$?; echo "EXIT_CODE:$exit_code"; echo "IMPORT_WARNING_LINES:"; grep -in "Deprecation Warning \[import\]" /tmp/cb_digital_grinnell_jekyll_build.log || echo "none"; exit $exit_code`

Fixed. Added `silence_deprecations: [import]` under the `sass:` key in `_config.yml:83`, and the build now completes with exit code 0 and no `@import` deprecation warnings.

## Note for later: 

This only suppresses the warning, it doesn't migrate the code. A real fix means rewriting _sass/*.scss and `cb.scss` to use `@use`/`@forward` with explicit module configuration instead of relying on `@import`'s shared global scope — worth doing before Dart Sass 3.0 actually removes `@import`, but it's a real refactor, not a config tweak.

## Additional SASS Deprecations Addressed

Searched for regex `shift-color|@function|mix\(|darken\(|lighten\(|red\(|green\(|blue\(|opacity\(|saturate\(|adjust-hue\(` (`**/*.scss`), 18 results

This is a self-contained fix — the deprecated calls (`red()`, `green()`, `blue()`, `mix()`, `opacity()`, `darken()`) are all in one file, `_theme-colors.scss`, and have direct `sass:color` module equivalents. I'll convert those calls in place; this doesn't touch the `@import`/global-scope pattern I flagged earlier as risky. 

Now rebuild to confirm the `color-functions` warnings are gone and nothing else broke. 

Execution complete: Rebuild and check color warnings

Ran terminal command:  `build_output=$(bundle exec jekyll build 2>&1); build_exit=$?; printf '%s\n' "$build_output"; printf '\n__BUILD_EXIT:%s\n' "$build_exit"; printf '\n__SASS_MATCHES:\n'; printf '%s\n' "$build_output" | grep -Ei 'Deprecation Warning \[color-functions\]|Deprecation Warning|Sass.*(deprecat|error)|error:' || true; printf '\n__BTN_COUNT:%s\n' "$(grep -c 'btn-primary' _site/assets/css/cb.css || true)"; exit "$build_exit"`

Ran terminal command:  `cat /Users/mcfatem/Library/Application\ Support/Code/User/workspaceStorage/8faab38f2396932560d4e616be5d4261/GitHub.copilot-chat/chat-session-resources/b98360b8-3bf6-4f61-8d5d-a34e402cd795/call_0gTJMbTWAdqTEQE5emI2vMem__vscode-1788446581499/content.txt | tail -n 200`

Ran terminal command:  `bundle exec jekyll build >/tmp/cb_jekyll_build.log 2>&1; build_exit=$?; echo "BUILD_EXIT:$build_exit"; echo "---SASS_MATCHES---"; grep -Ei 'Deprecation Warning \[color-functions\]|Deprecation Warning|Sass.*(deprecat|error)|error:' /tmp/cb_jekyll_build.log || true; echo "---BTN_COUNT---"; grep -c 'btn-primary' _site/assets/css/cb.css || true; exit "$build_exit"`

Completed with input:  `bundle exec jekyll build >/tmp/cb_jekyll_build.log 2>&1; build_exit=$?; echo "BUILD_EXIT:$build_exit"; echo "---SASS_MATCHES---"; grep -Ei 'Deprecation Warning \[color-functions\]|Deprecation Warning|Sass.*(deprecat|error)|error:' /tmp/cb_jekyll_build.log || true; echo "---BTN_COUNT---"; grep -c 'btn-primary' _site/assets/css/cb.css || true; exit "$build_exit"`

The compiled channel values from `color.channel()` can come back as non-integers (e.g. `106.4`) due to internal color-space handling, unlike the old `red()`/`green()`/`blue()`, which always returned integers — that's what broke `nth()`. I'll round them to restore the old integer behavior. 

Execution complete: Rebuild after rounding fix

Ran terminal command:  `bundle exec jekyll build`

The build succeeds again (exit 0), and the `color-functions` warnings are gone.

What changed in `_theme-colors.scss`:
- Added `@use "sass:color";`
- `mix()` → `color.mix()`
- `red()/green()/blue()` → `color.channel(..., $space: rgb)`, rounded (the module function can return fractional channel values, which broke `nth()` lookup in `luminance()` — fixed by wrapping in `round()`)
- `opacity()` → `color.channel($foreground, "alpha")`
- `darken()` → `color.adjust($color, $lightness: -N%)`

One category remains: `global-builtin` (functions like `map-get`, `map-merge`, `nth`, `type-of`, `abs`, `unit` used as bare globals instead of `sass:map`/`sass:list`/`sass:meta`/`sass:math`). That's a broader, separate cleanup across this file — let me know if you want me to do that pass too, or add it to `silence_deprecations` for now the way we did with `import`.

Completed: *Fix deprecated color functions in _theme-colors.scss* (2/3)
