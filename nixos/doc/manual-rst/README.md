# Sphinx + Markdown

This is an experiment how to use Sphinx to write documentation in Markdown.
[The work done](https://github.com/nlewo/nixpkgs/tree/manualFromReST) by @lewo
was used to build upon.


## Changes since `manualFromReST` branch

* merged current master
* use poetry2nix to provide python environment
* all documentation source is in source folder and build is
* create a flake out of `manual-rst` folder.
* live preview when working with
* added markdown support to sphinx via `recommonmark` package
* use more feature full theme `sphinx_rtd_theme`
* convert one document from rst to md


## Markdown example

For the purpose of this experiment
[`installation/installing.xml.md`](https://github.com/garbas/nixpkgs/blob/manual-markdown-sphinx/nixos/doc/manual-rst/source/installation/installing.xml.md)
document was converted manually from restructuredtext to markdown.
