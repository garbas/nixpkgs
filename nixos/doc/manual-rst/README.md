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

# Try it for yourself

1. Enter development shell by running

   ```console
   $ nix dev-shell
   ```

2. Build it by running `sphinx-build` command

```console
(nix-shell)$ sphinx-build -M html ./source ./build
```

HTML will be generated in `./build/html` folder.

3. You can also run a development server which will autoreload by running

```console
(nix-shell)$ python live.py
```

It might take some time to build it the first time, but after then it will 
watch all of the source files, rebuild it (faster because things will be 
cached from the first time) and reload the page in the browser.
