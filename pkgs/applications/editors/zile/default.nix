{ fetchurl, stdenv, pkgconfig, ncurses, boehmgc, perl, help2man }:

stdenv.mkDerivation rec {
  name = "zile-2.4.13";

  src = fetchurl {
    url = "mirror://gnu/zile/${name}.tar.gz";
    sha256 = "03mcg0bxkzprlsx8y6h22w924pzx4a9zr7zm3g11j8j3x9lz75f7";
  };

  buildInputs = [ pkgconfig ncurses boehmgc ];
  nativeBuildInputs = [ help2man perl ];

  # `help2man' wants to run Zile, which fails when cross-compiling.
  crossAttrs.nativeBuildInputs = [];

  # Tests can't be run because most of them rely on the ability to
  # fiddle with the terminal.
  doCheck = false;

  # XXX: Work around cross-compilation-unfriendly `gl_FUNC_FSTATAT' macro.
  preConfigure = "export gl_cv_func_fstatat_zero_flag=yes";

  meta = with stdenv.lib; {
    description = "Lightweight Emacs clone";

    longDescription = ''
      GNU Zile, which is a lightweight Emacs clone.  Zile is short
      for Zile Is Lossy Emacs.  Zile has been written to be as
      similar as possible to Emacs; every Emacs user should feel at
      home.

      Zile has all of Emacs's basic editing features: it is 8-bit
      clean (though it currently lacks Unicode support), and the
      number of editing buffers and windows is only limited by
      available memory and screen space respectively.  Registers,
      minibuffer completion and auto fill are available.  Function
      and variable names are identical with Emacs's (except those
      containing the word "emacs", which instead contain the word
      "zile"!).

      However, all of this is packed into a program which typically
      compiles to about 130Kb.
    '';

    homepage = http://www.gnu.org/software/zile/;

    license = licenses.gpl3Plus;

    maintainers = with maintainers; [ pSub ];

    platforms = platforms.unix;
  };
}
