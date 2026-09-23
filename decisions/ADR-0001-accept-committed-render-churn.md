# ADR-0001: Accept git churn from committed rendered course output; trim per-repo, on demand

- Status: accepted
- Date: 2026-09-23
- Deciders: Matt Paul

## Context

The course pipeline (`compileCourses` engine + `RU_course_template`, and every course
migrated onto them) renders each session to self-contained HTML (`embed-resources: true`)
and commits the rendered `docs/` tree on every push to `master` (the `Autobuild` step);
GitHub Pages serves it via deploy-from-branch. Because rendered output is self-contained
(base64-inlined assets) and every rebuild rewrites the changed files, and git retains every
version of every blob forever, the repository grows monotonically — content size stays
roughly constant, but `.git` does not.

Measured directly (2026-09-22/23): `RU_course_template`'s `.git` is a modest 68M for a
trivial two-session template. Real courses are far worse — `.git` objects alone (excluding
Git LFS where present): `RU_ATACseq` 488M, `scRNA-seq` 395M, `ATAC.Cut-Run.ChIP` 3.6G,
`RU_RNAseq` 5.1G. `RU_RNAseq`'s history was also found to contain directly-committed sample
FASTQ files (`ERR458755.fastq.gz`, 71MB; `ENCFF332KDA_sampled.fastq.gz`, 44MB) and knitr
`_cache` blobs (~40-44MB each) with identical content hashes re-committed as distinct blobs
multiple times across history — real, measured churn from the old (pre-Quarto) pipeline that
the new pipeline risks repeating at scale as more, heavier courses migrate.

The question: how much of this growth do we actually try to prevent, given what the rendered
output is *for*? Two concrete, non-negotiable use cases constrain the answer:

1. A persistent, retrievable local/GitHub copy of rendered output — including from local
   renders — that isn't just "whatever is currently live."
2. The front page's "Download the material" link
   (`https://github.com/{repo}/{name}/archive/{branch}.zip`, generated in
   `compileCourses/inst/extdata/index.qmd` lines ~218-226) must package rendered HTML +
   data + code together, so students can use the material fully offline in class with no
   internet connection. Course material is also authored right up to the last minute before
   a training session, and releases are only ever cut *after* a session runs (retrospective,
   not a pre-class gate) — so "current" and "downloadable" must stay in sync continuously,
   not just at release points.

## Decision

- **Keep committing rendered `docs/` to git on every real push to `master`, unchanged.**
  The resulting repository growth is accepted as the direct cost of the two use cases above,
  not treated as a defect to engineer away.
- **Keep the `paths-ignore` CI fix already shipped**
  (`.github/workflows/{compilation-check.yml,OS-check.yaml,legacy-R-check.yaml}`). This
  eliminates only *wasted* rebuilds — the `Autobuild` commit re-triggering a full CI run that
  produces no new output, and prose-only edits (`**.md`) — and has no effect on freshness:
  any real content change (`docs/notebooks`, `docs/exercises`, `docs/data`, `docs/imgs`,
  `docs/_course.yml`, `DESCRIPTION`) still triggers a full rebuild and commit exactly as
  before.
- **Do not pursue `actions/deploy-pages`** (never committing `docs/`) or
  **release-gated publishing** (committing `docs/` only at tag time) — both are ruled out by
  the requirements above (see Alternatives).
- **Handle actual bloat reactively, per repository, not via a global architecture change.**
  As each course migrates onto this pipeline, watch its `.git` size. If a specific course's
  repository becomes a real problem, trim it individually via a **release-anchored history
  squash**: most existing courses already carry release tags (e.g. `Intro_To_R_1Day` has
  `v1.0`/`v2.0`/`v3.0`). Using `git filter-repo`, collapse every stretch of commits *between*
  two consecutive release tags to a single commit, preserving each release tag's tree content
  byte-for-byte, then `git gc --prune=now` to reclaim the now-unreferenced intermediate blobs,
  then force-push. This is deliberately manual, on-demand, and scoped to one repository at a
  time — never scheduled or automated — invoked only when that repository's size is an actual
  problem, not preemptively.
- **Left open, not decided here:** what (if anything) to do about `RU_RNAseq`'s
  already-committed raw FASTQ files and duplicated cache blobs, and what size ceiling should
  guide new or updated course sample data going forward ("small dummy files" was the stated
  intent, but the measured files are 40-70MB — well above what "small" suggests). To be
  addressed case-by-case as each course migrates, not resolved by this record.

## Alternatives considered

- **Deploy via `actions/deploy-pages`, never commit `docs/` to git** (zero git churn) — the
  cleanest technical fix for growth, but rejected: it removes the persistent local/GitHub
  copy of rendered output, and the "Download the material" branch-archive zip would contain
  only source `.qmd` files with no rendered HTML, breaking the offline-in-class requirement
  entirely.
- **Commit/publish `docs/` only when cutting a release tag** — rejected: doesn't fit the
  actual authoring cadence. Edits continue until the last minute before a session; a release
  is cut only afterward. Gating the committed/downloadable copy to release time would leave
  the live site and download package stale exactly when they need to be freshest.
- **Drop `embed-resources: true` for slide decks** (share assets across files instead of
  base64-duplicating them into each one) — would reduce bytes-per-commit without breaking
  offline packaging (shared asset folders still ship in the same tree/zip), but decks would
  stop being individually-portable single files. Deferred as an optional future lever, not
  decided as part of this record.
- **Git LFS for rendered HTML** — not pursued; judged not worth the added workflow and quota
  overhead for this use case.

## Consequences

- Course repositories built on this pipeline will keep growing indefinitely under normal use;
  this is expected, not a bug to chase. `RU_RNAseq` (5.1G) and `ATAC.Cut-Run.ChIP` (3.6G) are
  the current high-water marks and are the most likely near-term candidates for trimming once
  they're brought onto the new pipeline.
- No automated size gate or CI check enforces a size ceiling — growth is monitored by
  occasional manual measurement (`du -sh .git`, `git count-objects -v`), not continuously.
- When trimming is eventually applied to a specific repository via the release-anchored
  squash: every release tag's *commit* SHA changes even though its *content* doesn't (commit
  SHAs depend on parent history); anyone pinning a specific commit rather than a tag name will
  find it gone. It is a genuine history rewrite requiring a force-push — existing clones and
  forks must re-clone rather than pull. Day-to-day edit history between releases is
  permanently discarded; only release-tagged snapshots remain retrievable. Each trim is a
  one-off, manual operation on one repository, done only when that repository's size is
  actually a problem.
- This record does not resolve what to do about `RU_RNAseq`'s already-committed FASTQ files
  or set a concrete sample-data size ceiling — both remain open, to be handled during that
  course's migration.
- Supersedes the "Recommended combination" in `ROADMAP.md` item 10 (git churn), which
  previously recommended `actions/deploy-pages` plus release-gated publishing; `ROADMAP.md`
  is being updated to match this decision as a follow-up.
