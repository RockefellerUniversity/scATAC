# Roadmap — planned and deferred work

Forward-looking plans for the RU course pipeline (`compileCourses` engine +
this template). These are things we designed, discussed or deliberately set
aside during the Quarto migration and the flat/single-tree restructure.

This file is **not** the day-to-day go-live checklist (pushing branches, merging
the open PR, cutting releases) — that's tracked in the PR itself. For migrating
an existing course see [`MIGRATION.md`](MIGRATION.md); for authoring a new one
see [`GettingStarted.md`](GettingStarted.md).

Each item: **what**, **why it's deferred**, and a concrete **first step**.

---

## 1. Interactive exercises / quizzes in the slides and notebooks

**What.** Let learners type and *run* code inside the material — e.g. "write an
expression that returns 2" — with the answer auto-checked. Aimed at intro-level
courses.

**Tool.** [`quarto-live`](https://r-wasm.github.io/quarto-live/) — runs R via
**WebR** and Python via **Pyodide** entirely in the browser (WebAssembly). It
fits this pipeline because it:
- needs **no server**, so it works on GitHub Pages;
- covers **R and Python**, matching the ambidextrous plan;
- provides `exercise` cells with hints, solutions and **grading**, not just a
  runnable console;
- supports both `revealjs` and `html`, which matters because every session
  renders to both from one source.

Rejected alternatives: **`learnr`** (needs a Shiny server — rules out Pages),
**`shinylive`** (overkill for a quiz). For plain multiple-choice with no code
execution, **`webexercises`** is far lighter and worth considering separately.

**Why deferred.** Several unknowns interact with our current engine config:
- **`embed-resources: true`** on decks/single pages vs. WebR loading its runtime
  and assets at page load — likely needs `embed-resources: false` on interactive
  pages (as we already did for the front page).
- **Extension shipping** — Quarto extensions live in `_extensions/`, so the
  engine would need to stage it into the content root (same pattern as the
  `.scss` themes and the Lua filter).
- **WASM package availability** — WebR has WASM builds for much of CRAN but
  **thin Bioconductor coverage**, so this is realistic for intro/base-R teaching,
  not genomics workloads.
- **Payload** — the R runtime is tens of MB on first load.
- **Purl interaction** — exercise cells would land awkwardly in the extracted
  code output and probably need excluding.

**First step.** Spike it: stage the extension from the engine and add one graded
exercise to a session, then render and inspect (a) the deck, (b) the single page,
and (c) the purled code. That answers the embed-resources and dual-format
questions concretely before committing.

---

## 2. RAG corpus — release-driven and versioned

**What.** Ingest the course material into the RAG store (the `ragnar` R package)
so answers are grounded in, and cite, a specific course version.

**Approach — ingest from releases.** Releases are the right unit because the
published site only ever holds the *current* build (each `Autobuild` overwrites
`docs/`), so **prior versions exist only in the repo's tags**. A tag is immutable,
reproducible, and carries the version label intrinsically.

Pipeline: enumerate releases via the GitHub API (the same call the Releases page
makes) → for each tag get the tree (`git worktree add ../v2.0 v2.0`, or the tag
tarball) → ingest that tag's `docs/presentations/singlepage/*.html` and exercise
pages → stamp `version = <tag>` as a **chunk metadata column** (not page text —
you want to filter and cite on it, and HTML→markdown drops `<meta>` tags).

**Design points / gotchas.**
- **Tag *after* the build.** The rendered `docs/` is committed by `Autobuild`; a
  tag cut before that build captures stale HTML against newer sources.
- **Near-duplicate chunks across versions** — most content repeats between
  releases, so retrieval can surface the same paragraph N times. Default queries
  to the latest version and filter on `version`, or retain only the last few
  releases. This is the main quality risk.
- **Unreleased/current state** — between releases the corpus lags the site. If
  RAG should answer about current material, ingest master separately as
  `version: "dev"` and exclude it by default.
- **Coverage** depends on tagging discipline (history starts when tagging did).
- **Optional `manifest.json`** — the engine could emit
  `{course, version, built, commit, sessions}` into `docs/` at build time for
  finer provenance. Largely optional under release-driven ingest, since the tag
  already supplies the version.

**Already done.** `ragnar` handles HTML→markdown, heading-aware chunking (each
chunk carries its heading trail) and source provenance, so no engine-side "RAG
export" is needed. The authoring conventions (headings as chunk boundaries,
self-contained sections, code-with-prose, figure captions, what *not* to ingest)
are written up in `GettingStarted.md` → *Authoring for RAG*.

**First step.** Write the ingestion script against one course with real releases
(e.g. `Intro_To_R_1Day`, which has v1.0/v2.0/v3.0) and check retrieval quality
across versions before generalising.

---

## 3. Migrate the live courses

**What.** Move the real courses (RNAseq, ChIPseq, …) onto the Quarto + flat
single-tree pipeline, one at a time, following `MIGRATION.md`.

**Why deferred.** Deliberate sequencing: finish and prove the template/engine
first, then migrate. Each course is its own effort (content conversion plus the
layout move).

**First step.** Pick one course, work `MIGRATION.md` end to end, and treat any
friction as a fix to the guide.

---

## 4. Final engine cut-over

**What.** Once *all* courses are migrated: merge the engine's `quarto-migration`
branch into engine `master` and strip every `compilecourses-ref: quarto-migration`
pin from the course workflows.

**Why deferred.** The pin is the opt-in mechanism during the phased migration;
engine `master` intentionally remains the **old rmarkdown compiler** so
un-migrated courses keep building.

**First step.** Only after item 3 completes — then a single coordinated PR per
course to drop the pins.

---

## 5. Python / multi-language courses

**What.** Make a Python-based course a first-class citizen.

**State.** The engine was structured to keep the two language-specific seams
swappable, and the front page is already language-neutral (the presentation link
is "Code", not "R code", and "Notebook" links to the `.qmd`). What's still
R-specific:
- **Dependency install** — currently the R package/`DESCRIPTION` model; Python
  needs conda/pip via `Config/reticulate` (the front page already has a Python
  install branch).
- **Code extraction** — `knitr::purl` → `.R`; a Python course wants `.py` or a
  `quarto convert` to `.ipynb`.
- **The Docker tab** — the recipe is the Bioconductor image, so it's R-only. A
  non-R course currently gets a fallback line rather than a container recipe.

**First step.** Define the Python container recipe and the `.py`/`.ipynb`
extraction, then run a small Python course through the pipeline.

---

## 6. Heavy-course robustness (from the original redesign, still open)

**What.** The pre-Quarto redesign proposal (`REDESIGN.md`, since removed from the
repo — see git history) suggested rendering each session in its **own subprocess**
(`callr` / `xfun::Rscript_call`) to bound peak memory and isolate failures. That
part was never implemented — Quarto solved the double-render/text-munging
problems, but not memory.

**Why it matters.** Genomics courses (alignment, counting, large object loads) on
~7 GB CI runners can OOM non-deterministically; today all renders share one R
process, so peak memory is set by the heaviest session and namespaces accumulate.

**Related, accepted for now.** Quarto's knitr engine executes **once per output
format**, so each session renders twice; a committed `_freeze/` makes the second
pass reuse results. Fine for current content, worth revisiting for heavy courses.

**First step.** Only when a real course actually OOMs — then wrap the per-session
render in a subprocess and measure. If the compute is genuinely heavy rather than
just memory-hungry, jump to item 9 (render on the HPC) instead.

---

## 7. CI hardening

- **Per-course `_freeze/` — done, and now ON.** The engine discarded any
  `_freeze/` Quarto wrote during a build (rendered in a `tempfile()` dir
  deleted on exit) — fixed by copying `pathToPres/_freeze` back to
  `contentDir/_freeze` after rendering (compileCourses@74b5291). **Decided:**
  commit it. `compilation-check.yml` already reuses freeze on normal pushes
  and forces a full rebuild only on the scheduled canary
  (`full-rebuild: ${{ github.event_name == 'schedule' }}`); `OS-check` and
  `legacy-R-check` always force a full rebuild unconditionally (they're
  cross-platform/cross-R-version execution canaries, not speed optimizations,
  and a committed freeze publishes *whoever rendered it*'s results, which
  isn't the point of those legs). This was also the explicit blocker for HPC
  rendering (item 9) — now clear.
- **Skip pointless rebuilds — done.** `paths-ignore` for the generated subset
  of `docs/` and `**.md`, on both `push` and `pull_request`, across all three
  build workflows. Kills the self-triggered `Autobuild` rebuild and doc-only
  churn.
- **Promote non-blocking legs — partly done, R 3.5/3.6 abandoned.**
  `legacy-R-check` R 3.5/3.6/4.0 are `allow-failure: true`. **R 4.1–4.5 now
  pass** (were blocked by a missing `pkgload` dependency, fixed) — worth
  promoting to gating. **R 3.5/3.6 were investigated and two rounds of
  environment-only fixes attempted, neither worked:**
  - R 3.5 fails downloading the engine from GitHub's API
    ("cannot open URL ... api.github.com"). Tried forcing
    `options(download.file.method = "libcurl")` and
    `CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt` — identical failure
    both times. Something deeper in that R build's own TLS stack, not fixable
    via CI config.
  - R 3.6 fails compiling `testthat` from source (Ubuntu 22.04's glibc made
    `SIGSTKSZ` a runtime call, breaking `testthat`'s old vendored Catch
    header). Tried excluding `Suggests` from the dependency install (didn't
    help — `testthat` is a genuine transitive dependency of the 2020-snapshot
    `isoband`/`ggplot2`, not optional) and force-installing a current
    `testthat` from live CRAN before resolving deps (current `testthat`'s own
    minimum-R floor is now above 3.6, so this silently falls through to the
    same broken snapshot version).

  Getting either to pass would require a material change (patching
  `testthat`'s vendored C++, rebuilding `libcurl` against a different TLS
  backend, or dropping `ggplot2`) — out of scope. **Abandoned**; stay
  `allow-failure: true` indefinitely unless something changes upstream
  (a newer PPM snapshot for these R versions, a `testthat`/`isoband` release
  that still supports R 3.6, etc).
- **Link-check policy.** The check now fails the run on **any** broken link. If
  the known-broken links (item 8, now fixed except the intentional test-link
  demo) are kept long-term, consider an ignore-list so the gate reds only on
  *new* breakage rather than sitting permanently red.

---

## 8. Content and site cleanups

- **The known-broken links — done.** The 7 dead cross-reference lines (14
  broken links) to `Intro_To_R_1Day/.../introToR_Session1.html` in
  `docs/notebooks/Session1.qmd`/`Session2.qmd` now point to real anchors
  within this template's own rendered output instead of another course's URL
  structure, so they can't silently rot the same way again. The 2 deliberately
  planted `github.com/rafelleruniversity` test links are **kept as-is** — see
  item 11's notes; they're a working demonstration that `link-check` catches
  real breakage, not a bug.
- **Private-repo badges — resolved.** `RU_course_template` is now public, so
  the Course Integrity badges render normally for everyone; no change needed.
- **Navbar "Notebooks" menu — done.** Added, matching the four per-session
  output links (Slide / Single Page / Code / Notebook).
- **`_course.yml` format — done.** `Presentations` is now a list of per-session
  entries (`title`/`PresRmd`/`PresOverviewRmd`/`Exercises`), each owning its
  own exercises explicitly instead of by array position plus comma-grouping.
  Documented in `GettingStarted.md`.
- **Duplicate chunk label — done.** `index.qmd`'s two `showSysInstall` chunks
  renamed to `showCourseDescription` and `showSysReqInstall`.

---

## 9. Render heavy courses on the HPC

**What.** A path to run expensive computation on the RU SLURM cluster rather than
a laptop or a ~7 GB GitHub runner.

**Intended model (the target design).** An **HPC render** alongside the existing
local render: on the cluster the course renders with *everything executed* — all
chunks run, intermediate files regenerated — and that run's **`_freeze/` cache is
committed and pushed**. GitHub then never does the heavy work: CI re-renders from
the frozen results, so pushes stay cheap. In short, **HPC is the execution
environment and CI is only a formatting pass.**

**Why.** Genomics material (alignment, counting, large object loads) can't
realistically execute in CI. Today's workaround is the `eval=FALSE` +
`load("data/…")` pattern: heavy results are produced by hand, offline, and
shipped as data files. An HPC path would formalise *where those results come
from* instead of leaving it manual and undocumented.

**Hard constraint.** GitHub-hosted runners **cannot reach the RU cluster** (no
network route, no credentials), so an HPC render can never be a step inside the
Actions build. It has to be an **out-of-band step whose outputs are committed**
(or attached to a release) and then consumed by ordinary builds. Any design has
to start from that.

**Three levels, increasing ambition:**

1. **Whole-course render on the cluster.** Submit `compileSingleCourseMaterial()`
   as a SLURM job using the existing RU tooling (`~/Documents/RU/Analysis/HPC`,
   the `rocky9/` templates, `run_qmd_*` + `Herper::local_CondaEnv`; see the
   `ru-hpc-slurm` skill). Simplest, and sufficient if a course is heavy overall.
2. **Per-chunk offload.** Worth knowing: a chunk *option* alone can't do this —
   knitr has no "evaluate this elsewhere" hook. It needs either a custom engine
   (`knitr::knit_engines$set(hpc = …)`) that submits the chunk body and returns
   captured output, or `future.batchtools` with the rocky9 SLURM templates used
   explicitly inside the chunk. Because the job runs in a **separate R session**,
   such chunks need explicit disk-based inputs/outputs rather than shared
   in-memory state — which is exactly the existing `load()` pattern, so the
   content style already fits.
3. **Wire it to caching.** Have the expensive results land in `_freeze/` (or
   `data/`) so ordinary CI builds never re-execute them. This is the same
   underlying problem as the freeze work in item 7 — compute once, reuse
   everywhere — and the two should be designed together. See also item 6
   (subprocess isolation) for the lighter-weight, same-machine variant.

**Reproducibility note.** Results computed in an HPC conda env differ from CI's
Bioconductor docker; capture `sessionInfo()` alongside them and be explicit about
which environment produced the published output.

### Settled design decisions

- **An `hpc` chunk option, plus a render-mode flag.** Mark the expensive chunks
  (`hpc=TRUE`) and let the render mode decide whether they run: only an HPC
  render evaluates them; every other render (local, CI, canaries) skips them.
  Implement with a knitr **option hook**, which can rewrite one option based on
  another — roughly:
  ```r
  knitr::opts_hooks$set(hpc = function(options) {
    if (isTRUE(options$hpc) && !isTRUE(getOption("course.hpc", FALSE)))
      options$eval <- FALSE
    options
  })
  ```
  The engine sets `course.hpc` (or an equivalent param) for the HPC render only.
  Most courses will never mark a chunk, so they are unaffected.
- **This removes the canary conflict.** `OS-check`, `legacy-R-check` and the cron
  can keep `full-rebuild: true`: they still execute all the *light* code across
  OS/R versions and simply never attempt the heavy chunks. The "does this still
  run?" signal survives for everything that can run in CI.
- **Per-format double execution on the cluster is accepted.**

### Open issue to resolve first

**Freeze invalidates per *document*, not per chunk.** Quarto hashes the whole
`.qmd`, so *any* edit — even a typo in prose — invalidates that session's entire
cache. So "edits that don't touch the heavy sections are fine" only holds if the
heavy results are stored somewhere other than the freeze. If they live *only* in
the freeze, a trivial prose edit makes CI re-execute the document with the heavy
chunks disabled and publish a page **silently missing those results** — a green
build with incomplete output, which is the worst failure mode.

Two ways out:

1. **Persist heavy results to files** — the existing `eval=FALSE` + `load("data/…")`
   pattern, now automated: the `hpc=TRUE` chunk computes *and saves*, a normal
   chunk loads. Downstream output is then correct regardless of freeze state, and
   freeze becomes a pure speed optimisation rather than a correctness dependency.
   **Recommended** — it also matches how the courses are already written.
2. **Guard it** — make the render fail loudly when a heavy chunk is skipped and no
   cached or persisted result exists, so an incomplete page can never publish.

Worth doing (2) even alongside (1), as a backstop.

**Also.** If the HPC run remakes large intermediate data, committing it feeds
straight into the churn problem — see item 10 for whether those belong in git, a
release asset, or ignored.

**First step.** Fix the `_freeze` copy-back (item 7 — **near-term**), then render
one real course end to end on the cluster with the existing `run_qmd_*` runner,
commit the cache, and confirm a CI build reuses it without executing. That single
loop proves or disproves the model before any per-chunk machinery is built.

---

## 10. Managing git churn

**The problem.** We commit generated output, so the repo grows monotonically:
- rendered decks and pages are **self-contained** (`embed-resources: true`), so
  each is multi-MB with base64-inlined assets, and *every* rebuild rewrites them;
- an `Autobuild` commit lands on **every push** — including the one the publish
  step itself pushes;
- adopting a committed `_freeze/` (item 7) would add cached figure PNGs that
  churn on every re-execution.

Git keeps every version of all of that, so history grows considerably faster than
the content does. It's tolerable on this template; it's the thing to get right
*before* migrating large, plot-heavy courses.

**Decided — see [ADR-0001](decisions/ADR-0001-accept-committed-render-churn.md).**
Two hard requirements rule out the options that would actually stop the growth:
a persistent, retrievable local/GitHub copy of rendered output (not just whatever
is currently live), and the front-page "Download the material" link, which must
package rendered HTML + data + code together for fully offline in-class use —
combined with an authoring cadence where edits continue until the last minute
before a session and releases are only cut afterward. Given those, **committing
`docs/` on every real push is accepted as a real cost, not a defect to engineer
away.**

**Options, cheapest to most structural:**

1. **Cut pointless rebuilds** — `paths-ignore` for the generated subset of
   `docs/` and `**.md` (item 7). **Done** — kills the self-triggered rebuild and
   doc-only churn, with zero effect on freshness (real content changes still
   rebuild and commit as before). The only lever adopted so far.
2. **Publish on release, not on every push.** ~~Rejected~~ — doesn't fit the
   authoring cadence (see above); would leave the site/download stale exactly
   when it needs to be freshest. See ADR-0001.
3. **Deploy Pages from Actions** (`actions/deploy-pages`) instead of from a
   committed folder. ~~Rejected~~ — `docs/` never entering git breaks both hard
   requirements above (no persistent committed copy; the download zip would have
   source only, no rendered HTML). See ADR-0001.
4. **Drop `embed-resources` for the decks.** Assets get shared instead of
   base64-duplicated into every file, cutting committed volume substantially.
   Cost: decks stop being individually shareable/self-contained, which was a
   deliberate earlier decision — a real trade. **Left open** as an optional
   future lever, not decided.
5. **Git LFS** for rendered HTML/figures. Keeps clones lean but adds quota and
   workflow friction; probably not worth it here.
6. **Trim per-repo, on demand — the actual plan for when a repo balloons.**
   Most existing courses already carry release tags. Rewrite history with
   `git filter-repo` so each stretch of commits *between* two consecutive
   release tags collapses to one commit — every tag's tree content stays
   byte-identical, but the intermediate `Autobuild` churn between releases is
   discarded — then `git gc --prune=now` and force-push. Real costs: every
   release tag's *commit* SHA changes even though its content doesn't; existing
   clones/forks must re-clone, not pull; day-to-day history between releases is
   permanently lost. Deliberately manual, on-demand, one repo at a time — never
   scheduled or automated. Apply only when a specific course's `.git` is
   actually a problem, not preemptively.

**Measured (2026-09-22/23), for reference.** `.git` objects only, excluding Git
LFS where present: `RU_course_template` 68M (trivial 2-session template);
`RU_ATACseq` 488M; `scRNA-seq` 395M; `ATAC.Cut-Run.ChIP` 3.6G; `RU_RNAseq` 5.1G.
`RU_RNAseq`'s history also carries directly-committed sample FASTQ
(`ERR458755.fastq.gz` 71MB, `ENCFF332KDA_sampled.fastq.gz` 44MB) and duplicated
knitr cache blobs (~40-44MB each, same content re-committed multiple times) —
`RU_RNAseq` and `ATAC.Cut-Run.ChIP` are the current high-water marks and the
likeliest near-term candidates for option 6 once migrated.

**Open, not resolved here.** What (if anything) to do about `RU_RNAseq`'s
already-committed FASTQ files, and what size ceiling should guide new/updated
course sample data ("small dummy files" was the intent; the measured files are
40-70MB). Addressed case-by-case as each course migrates — see ADR-0001.

---

## 11. A skill that reviews course content

**What.** A Claude Code skill that reviews a course (new or being migrated) against
the design principles this pipeline has accumulated — authoring conventions,
structural expectations, the things that are easy to get subtly wrong when
writing or migrating a session. Distinct from the automated CI checks (link-check,
compilation-check, etc.): this is for the things a human reviewer would catch by
reading the content, not by running it.

**Why.** By the time item 3 (migrating real courses) is underway, there will be a
recurring need to sanity-check a course's content against everything decided
along the way — conventions that live in `GettingStarted.md`, `MIGRATION.md`,
ADRs, and this roadmap, but that nobody will re-read in full for every course.

**Not started.** No design work done yet — this entry exists to hold the idea and
collect raw material for it as we notice things worth remembering, rather than
trying to design the skill up front.

**Notes toward it (running list — add to this as things come up, don't design
the skill from it yet):**

- *(2026-09-23, from item 8 link-check cleanup)* Distinguish an intentionally
  planted test fixture (e.g. the deliberately-broken `github.com/rafelleruniversity`
  link used to prove `link-check` actually catches breakage) from a genuine
  authoring error. A course-content reviewer needs to not flag the former as a
  bug — but also needs some way to recognize it *is* a deliberate fixture rather
  than assuming every course review should treat all courses as "production."

**First step.** None yet — let this list accumulate; revisit once item 3 is
underway and there's a real course to test a first pass against.
