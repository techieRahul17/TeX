# TeX
A curated collection of LaTeX templates, snippets, macros, and workflows to create beautiful documents — articles, reports, presentations, resumes and theses — with clarity, consistency and minimal friction.

[![Release](https://img.shields.io/github/v/release/techieRahul17/TeX)](https://github.com/techieRahul17/TeX/releases)
[![License](https://img.shields.io/github/license/techieRahul17/TeX)](https://github.com/techieRahul17/TeX/blob/main/LICENSE)
[![Build Status](https://github.com/techieRahul17/TeX/actions/workflows/ci.yml/badge.svg)](https://github.com/techieRahul17/TeX/actions)
[![Stars](https://img.shields.io/github/stars/techieRahul17/TeX?style=social)](https://github.com/techieRahul17/TeX/stargazers)

> Lightweight, extensible, and well-documented LaTeX resources for academics, students, and professionals.

Contents
- Overview
- Highlights
- Quick start
- Templates & structure
- Usage examples
- Tips & best practices
- Contributing
- Roadmap
- License & support

## Overview
TeX is organized to help you get started quickly with LaTeX projects, providing:
- Clean, production-ready templates (article, report, beamer, resume, thesis)
- Reusable macro packages and style files for consistent typography
- Examples for bibliography with BibTeX/Biber and citation styles
- Build helpers (Makefile / latexmk / scripts) for reproducible compilation
- Notes and recommendations for using Overleaf, TeX Live, or MiKTeX

This repository is ideal if you:
- Want a polished starting point for papers, presentations, or CVs
- Need a consistent set of macros to share across projects
- Prefer automated builds and reproducible outputs

## Highlights
- Modern, minimal templates with sensible defaults
- Readable and maintainable LaTeX code with comments and structure
- Build automation examples (latexmk, Makefile) and CI-ready commands
- Cross-platform compilation guidance (local and cloud services)
- Accessibility-minded and print-ready output where applicable

## Quick start

Prerequisites
- TeX distribution (TeX Live recommended) or Overleaf account
- latexmk or pdflatex + bibtex/biber for manual builds
- Optional: arara for rule-based builds

Clone the repo:
```bash
git clone https://github.com/techieRahul17/TeX.git
cd TeX
```

Compile a template (example using latexmk):
```bash
# From the directory containing main.tex
latexmk -pdf main.tex
# or, if using a specific template folder:
cd templates/article
latexmk -pdf main.tex
```

Manual sequence (if latexmk not available):
```bash
pdflatex main.tex
bibtex main           # or biber main if you use biber
pdflatex main.tex
pdflatex main.tex
```

On Overleaf
- Create a new project and upload the template folder contents.
- Ensure your bibliography engine and compiler settings match (pdflatex vs. xelatex vs. lualatex).

## Templates & repository structure (suggested)
- templates/
  - article/         — Academic / journal articles (with example figures & tables)
  - beamer/          — Presentation slides (themed)
  - resume/          — Minimal resume / CV template
  - thesis/          — Thesis template with frontmatter, chapters, and bibliography
- packages/
  - style.sty        — Shared macros and custom commands
  - macros.tex       — Convenience macros (colors, shortcuts, math)
- examples/
  - bibliography/    — Example .bib and citation usage
  - figures/         — Demo images and figure inclusion examples
- build/
  - Makefile
  - latexmkrc
- ci/
  - ci-latex.yml     — Example GitHub Actions workflow to build PDFs

(If your repo currently differs, tell me the actual structure and I’ll adapt the README.)

## Usage examples

Insert a figure:
```latex
\begin{figure}[ht]
  \centering
  \includegraphics[width=0.8\linewidth]{figures/diagram.pdf}
  \caption{System architecture overview}
  \label{fig:architecture}
\end{figure}
```

Cite with BibTeX:
```latex
% main.tex preamble
\usepackage[backend=biber,style=ieee]{biblatex}
\addbibresource{bibliography/references.bib}

% In document
According to recent work \cite{smith2020example}, ...
...
\printbibliography
```

Switching compilers:
- Use `xelatex` or `lualatex` for better font handling and Unicode support.
- Update compilation command: `latexmk -pdfxe main.tex` or set `-pdflatex="xelatex -interaction=nonstopmode -synctex=1 %O %S"` in latexmkrc.

## Tips & best practices
- Keep the preamble small: put shared macros in a single `.sty` or `macros.tex`.
- Use `latexmk` for reliable, repeated builds.
- For collaboration, prefer a single `.bib` and consistent BibTeX/biber workflow.
- Use PDF/A or embed fonts when preparing final submissions or archival documents.
- Track large binary files (figures) using Git LFS if needed.

## Contributing
Contributions are welcome! To contribute:
1. Fork the repo and create a feature branch: `git checkout -b feat/new-template`
2. Add or improve templates, examples, or docs.
3. Ensure builds succeed locally (`latexmk -pdf`) and add tests/examples when relevant.
4. Open a pull request describing your changes and include screenshots or example PDFs if applicable.

Code style
- LaTeX files should use UTF-8 encoding.
- Keep lines reasonably short and use comments to explain non-trivial macros.
- Name templates clearly (e.g., `article/main.tex`, `beamer/presentation.tex`).

Reporting issues
- Use GitHub Issues to report bugs, request features, or suggest new templates.
- Provide a small reproducible example when possible.

## Roadmap
Planned improvements:
- Additional themed Beamer templates
- Template variants for common publishers and conferences
- CI that publishes built PDFs to releases
- Automated checks for missing references and broken builds

If you have priorities you'd like me to implement, tell me and I can update the roadmap and help create issues or PR templates.

## License
This repository is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgements
Thanks to the LaTeX community and package authors for making powerful tools available. Portions of templates may incorporate commonly used public snippets and packages — attribution included within templates where required.

## Authors and Maintainers
- Author: techieRahul17
- GitHub: [techieRahul17](https://github.com/techieRahul17)
