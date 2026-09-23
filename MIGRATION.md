# Course migration guide — old pipeline → flat Quarto pipeline

Living checklist for migrating an existing RU course (rmarkdown/xaringan, package
`inst/` layout) to the new **flat Quarto** pipeline this template implements.
Update it as the pipeline evolves.

## Strategy (how the migration is staged)

- The engine (`RockefellerUniversity/compileCourses`) lives on the
  **`quarto-migration`** branch. Engine `master` stays the **old rmarkdown
  compiler** so un-migrated courses keep building.
- Each course **opts in** by pinning `compilecourses-ref: quarto-migration` in
  its workflows. Migrate courses **one at a time**.
- **Final cut-over (later, once all courses are migrated):** merge engine
  `quarto-migration` → `master` and strip every `compilecourses-ref` pin.
- Engine API (flat): `compileSingleCourseMaterial(contentDir, targetDir, repo,
  name, branch, freeze, installPkg)` — reads content from the flat top-level
  folders; installs the thin package only for dependencies.

---

## Per-course checklist

### 1. Content conversion (`.Rmd` → `.qmd`, xaringan → Quarto)
- [ ] Presentations `.Rmd` → `.qmd`. Header `output: {moon_reader, html_document}`
      + `params: isSlides` → **drop** (formats inherit from the project
      `_quarto.yml`: revealjs + html).
- [ ] `params$isSlides` `cat()` if/else blocks → Quarto conditional divs:
      `::: {.content-visible when-format="html"}` for page-only content.
      **NB:** `content-visible when-format="html"` *also* matches revealjs — use
      `::: {.content-hidden when-format="revealjs"}` to exclude from the deck.
- [ ] Slide separators: keep bare `---` (a *headingless* slide break in revealjs;
      renders as `<hr>` on the page). Author continuation slides as one
      `## Topic` followed by `---` breaks — **do not repeat the header** (so the
      single page shows it once). Replaces the old duplicate-header munging.
- [ ] `.pull-left[` / `.pull-right[` → `::: {.columns}` / `::: {.column width="50%"}`.
- [ ] `--` incremental pause → `. . .`.
- [ ] Section-divider slides: `# Title {background-color="#23373B"}` (full-green
      slide), **not** `.inverse`.
- [ ] Keep classic ```` ```{r} ```` chunk headers so the purled `.R` stays clean;
      keep the `eval=FALSE` + `load("data/...")` heavy-compute pattern.
- [ ] Exercises `.Rmd` → `.qmd`. Keep the `params$toMessage` + `echo=toMessage`
      pattern (answers vs exercise). Exercises are **single-page HTML only** — no
      purled `.R`.

### 2. Flatten the structure
Move content out of the package to the repo top level:
- [ ] `inst/extdata/presRaw`   → `notebooks/` (presentation sources; the engine
      renders into `presentations/`, which becomes output-only)
- [ ] `inst/doc`               → `exercises/`
- [ ] `inst/extdata/Descriptions` → `descriptions/`
- [ ] `inst/extdata/data`      → `data/`
- [ ] `inst/extdata/imgs`      → `imgs/`
- [ ] `inst/extdata/_course.yml` → `_course.yml` (repo root)
- [ ] `DESCRIPTION`            → repo root
- [ ] Delete the package wrapper (`R/`, `man/`, `tests/`, `*.Rproj`) and dead
      xaringan CSS (`customCSS/`, `presRaw/*.css`).

### 3. Thin dependency package (root)
- [ ] `DESCRIPTION`: dependencies + `SystemRequirements` only. **Trim
      compile-only deps** (e.g. `rmarkdown`) — keep only what the course
      *content* needs. *(tracked backlog #16)*
- [ ] `NAMESPACE`: minimal/empty (required for the thin package to build).
- [ ] `.Rbuildignore`: exclude the content dirs + build outputs
      (`presentations/`, `exercises/`, `descriptions/`, `data/`, `imgs/`,
      `_course.yml`, `docs/`, `r_course/`, `.github/`, `_freeze/`, `*.Rproj`,
      `link-check-report.tsv`, …) so installing pulls only dependencies.

### 4. `_course.yml`
- [ ] Convert to the structured per-session list format (see
      `GettingStarted.md` → `_course.yml`) if migrating from the old
      space/comma-delimited encoding, and update `PresRmd` / `Exercises` /
      `PresOverviewRmd` entries `.Rmd` → `.qmd`.

### 5. CI / workflows (copy this template's `.github/`)
- [ ] `.github/actions/compile-course/action.yml` (composite: sets up Quarto,
      installs the engine, compiles).
- [ ] `compilation-check.yml`, `OS-check.yaml`, `legacy-R-check.yaml`,
      `link-check.yaml`.
- [ ] Set `compilecourses-ref: quarto-migration` in the three build workflows.
- [ ] Dependency resolution reads from `.` (repo root), no `subdir`.
- [ ] Pin `quarto-dev/quarto-actions/setup@v2` to a version (e.g. `1.4.554`) —
      `release` needs `jq`, which the Bioc docker lacks.
- [ ] `link-check.yaml`: pass a token (`GHTOKEN2`) so github.com links verify
      via the authenticated API; `LINK_CHECK_FAIL_ON_BROKEN` (default true) gates
      the run red on any broken link.

### 6. Publishing (docs-only)
- [ ] GitHub Pages source = **`master` / `/docs`**.
- [ ] `docs/` is the only committed build output. `git add docs` (not
      `r_course`); the publish step **clears `docs/` before copying** so stale
      outputs don't accumulate.
- [ ] `.gitignore` the ephemeral `r_course/` build folder.
- [ ] Point in-course "where's the material" references at `docs/…` (not
      `r_course/…`).

### 7. Freeze (once content stabilises)
- [ ] Commit `_freeze/` at the content root so edits re-execute only the changed
      session, and CI reuses frozen results. Scheduled cron builds full-rebuild
      (canary) via `full-rebuild`.

### 8. Verify
- [ ] Local render: `compileCourses::compileSingleCourseMaterial(contentDir=".")`
      (needs the quarto CLI on PATH); eyeball the site + purled `.R`.
- [ ] Open a PR: `compilation-check` validates the build (no publish). Merge →
      publishes to `docs/`; `link-check` runs post-merge and flags broken links.

---

## Known gotchas (already handled in the engine/template)
- **Front page must be `embed-resources: false`** — otherwise Quarto inlines each
  `<iframe>` deck as a giant `data:` URI (~10 MB page, broken slide previews).
  Per-session decks/pages stay self-contained (`embed-resources: true`).
- `embed-resources` inlines the logo as inline `<svg>` — CSS must size `img`
  **and** `svg`; single-page/exercise logo is a data-URI `<img>`.
- Quarto navbars **don't nest** — flat, one-level menus.
- `yaml::write_yaml` emits `yes/no`; Quarto wants YAML 1.2 `true/false` — the
  engine passes a logical handler.
- **legacy-R-check:** R 3.5/3.6/4.0 are `allow-failure` (non-blocking); the
  compatibility floor is R 4.1 (older toolchains can't build the deps).
- **link-check remote:** github.com links are verified via the authenticated
  `gh` API (a private repo's own URLs 404 to an unauthenticated HEAD). github.io
  **Pages** cross-links can't be auth-verified — genuinely-moved ones will show
  as broken.

---

## Pipeline features still in flight (fold in as they land)
- **#14** Releases summary page (GitHub releases → version/date table, linked
  from the home page). Needs the releases API + token.
- **#15** Generate the top-level `README.md` from the Course Overview section.
- **#16** Trim compile-only deps (`rmarkdown`) from `DESCRIPTION`.
- **#17** RAG-optimized corpus export (clean markdown/plain-text per item +
  metadata front-matter / versioning) — *scoping pending*.
