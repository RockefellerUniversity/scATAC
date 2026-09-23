# Teaching at RU

A template repository from which to build workshops and other teaching materials
in a standard manner, so they integrate with other RU material. An example can be
found [here](https://rockefelleruniversity.github.io/RU_RNAseq/).

This guide is for **authoring a new course from this template**. To migrate an
existing (older, package-based) course onto this pipeline, see
[`MIGRATION.md`](MIGRATION.md).

## How to use this template

* Click **'Use this template'** at the top right of the repository to create your
  own course repository.

* All course content lives in the top-level **`docs/`** folder — the single tree
  that holds both your **sources** and the **rendered site**. GitHub Pages serves
  the rendered site from `docs/` (Settings → Pages → *master / docs*), and the
  GitHub Actions in `.github/` recompile it whenever you push.

* You do not rename or manage an R package. The repo root holds only a thin
  `DESCRIPTION` (your dependencies) plus the `.github/` workflows; everything you
  edit as an author is under `docs/`.

* To set up your course you mainly: fill in the content sources under `docs/`,
  and update the two config files (`docs/_course.yml` and the root `DESCRIPTION`).
  There are placeholders, examples and formatting guides throughout. Anything
  surrounded by double question marks **`[??]`** is helper text to be replaced.

* **Edit sources, not generated files.** Under `docs/` you edit `notebooks/*.qmd`
  (the presentations), `exercises/*.qmd`, `descriptions/*.Rmd`, `data/`, `imgs/`
  and `_course.yml`. Everything else in `docs/` is regenerated on each build — do
  not edit it by hand: the whole of **`presentations/`** (slides, single pages and
  extracted code), `exercises/{answers,exercises}/`, `index.html`,
  `releases.html`, `search.json`, `site_libs/`, and the root `README.md` (which is
  generated from your Course Overview).

* If you find mistakes, or parts of the template that could be clearer, please
  fork and submit a pull request, or raise an issue.

* To see how the template compiles, visit the
  [web page](https://rockefelleruniversity.github.io/RU_course_template/), or look
  at other [compiled courses](https://rockefelleruniversity.github.io/RU_RNAseq/).

## Course content

Content is authored as **Quarto** documents (`.qmd`). Each presentation renders
from one source to slides, a single page and downloadable R code.

#### Course slides
Find these at **`docs/notebooks/*.qmd`** (rendered output lands in
`docs/presentations/`, which you don't edit).
Check out `Session1.qmd` for formatting (slide breaks with `---`, two columns,
section-divider slides, `eval=FALSE` + `load()` for heavy chunks, etc.).

You can **repeat a header** (`## Topic`) across several continuation slides so
each slide in a section shows its title in the deck — the single page
automatically collapses those repeats to a single heading (the content flows on
underneath).

#### Exercises
Find these at **`docs/exercises/*.qmd`**.
Check out the example for how the `toMessage` parameter shows/hides solutions
(answers vs exercise versions).

## Authoring for RAG

This course material is also used as a knowledge base for a retrieval-augmented
generation (RAG) system, ingested with the [`ragnar`](https://ragnar.tidyverse.org)
R package. `ragnar` handles the mechanics — converting pages to markdown,
heading-aware chunking (each chunk carries its heading trail as context), and
recording each chunk's source — so good retrieval mostly comes down to **how you
author** and **what gets ingested**.

**Author so each section stands on its own:**

* **Use a clear heading hierarchy.** Chunks are cut on markdown structure, so
  your `##`/`###` headings are the chunk boundaries — one idea per section with a
  descriptive title.
* **Keep sections self-contained.** Avoid references like "as we saw on the
  previous slide"; a retrieved chunk is read out of context, so restate or link
  the point explicitly.
* **Keep code next to the prose that explains it**, so a single chunk holds both
  the code and what it does.
* **Caption figures / add alt text.** Plots render as images and are invisible to
  text retrieval — a caption is the only thing RAG can index for a figure.

**Ingest the right output.** Point the ingester at the **single-page** renders
(`docs/presentations/singlepage/*.html`) and the exercise pages — one clean page
per session, including executed results. Do **not** ingest the reveal.js slide
decks (`.../slides/*.html`; they inline JS + base64 and convert to noise), the
purled `.R` (code with no prose), or the site scaffolding (`site_libs/`,
`index.html`, `releases.html`, `search.json`). Because sources and rendered
output now live together under `docs/`, select files precisely rather than
globbing all of `docs/`.

**Version the corpus.** `ragnar` records *where* a chunk came from but not *which
course version* it is. To keep answers tied to a specific release, ingest the
material as of each release tag and attach a `version` field to those chunks (see
the course's Releases page / GitHub releases).

## Config files

#### DESCRIPTION
Find this at the repo root: **`DESCRIPTION`**.
A thin dependency manifest — list only the packages your **course content** uses
(it is installed just to resolve dependencies and to build the front-page install
instructions; the rendering engine supplies its own build tooling). Do **not**
add build-only packages such as `rmarkdown`/`knitr` here.

If you have non-R dependencies, put them in the `SystemRequirements` field using
the name of the conda package. We use Herper to install that software.

#### Descriptions
Find these at **`docs/descriptions/`**.
These files contain the descriptive text the cover page is built from. There are
two kinds:

1. **Course Overview** (`CourseOverview.Rmd`) — a description of the overall
   course. This section also becomes the repo's top-level `README.md`.
2. **Session overview** (`SessionNOverview.Rmd`) — one per session you break the
   course into (there can be just one for a single-session course).

#### _course.yml
Find this at **`docs/_course.yml`**.
Lists the names of all the content files. Update `Description.CourseName` first.
`Presentations` is a **list of sessions**, in the order they should appear (your
first session's `.qmd` should be first). Each session is an entry with its own
`title`, `PresRmd`, `PresOverviewRmd`, and `Exercises` (a list of that session's
exercise `.qmd` files — ownership is explicit, not positional):

```yaml
Presentations:
  - title: Session1
    PresRmd: Session1.qmd
    PresOverviewRmd: Session1Overview.Rmd
    Exercises:
      - MyExercise1.qmd
      - MyExercise2.qmd
  - title: Session2
    PresRmd: Session2.qmd
    PresOverviewRmd: Session2Overview.Rmd
    Exercises:
      - MyExercise3.qmd
```

If any file is renamed from the template, update this to match. To add a
session, add another entry to the list; to add an exercise to a session, add
another line under that session's `Exercises`.

## .github files for compiling

The compilation workflows live in the top-level `.github/` directory. They detect
pushes, recompile the content into `docs/`, and run basic checks of the R code.
There are three, plus a link checker:

1. **compilation-check** — builds the course (rendering in place into `docs/`) and
   publishes it; GitHub Pages serves `docs/`.
2. **OS-check** — checks the course compiles across macOS, Windows and Ubuntu
   Linux (R release and devel).
3. **legacy-R-check** — attempts to compile on every major R release since 3.5
   (Linux only), documenting the R-version compatibility floor.
4. **link-check** — after a successful build, verifies the site's links (local
   files/anchors + remote reachability) and reports broken ones.

The shared install-and-compile logic lives in the composite action at
`.github/actions/compile-course`, which the build workflows call. During the
migration period the workflows pin the Quarto rendering engine with
`compilecourses-ref: quarto-migration` — keep that pin until the engine is cut
over to its default branch. Unlike the old template, there is no package name to
replace in these scripts (they read the content from the repo directly). Most
standard courses work as-is; occasional customization is course-specific.

## Finished?

Once you have finished, let us know and we will take a fork onto the Rockefeller
GitHub, start the process of getting it compiling, and help review the content.

## Help

If you need help, contact the BRC [brc@rockefeller.edu], or raise an issue.
