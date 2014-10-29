{ stdenv, fetchurl
, bzip2, curl, expat, jsoncpp, libarchive, xz, zlib
, useNcurses ? false, ncurses, useQt4 ? false, qt4
, wantPS ? false, ps ? null
}:

with stdenv.lib;

assert wantPS -> (ps != null);

let
  os = stdenv.lib.optionalString;
  majorVersion = "3.2";
  minorVersion = "2";
  version = "${majorVersion}.${minorVersion}";
in

stdenv.mkDerivation rec {
  name = "cmake-${os useNcurses "cursesUI-"}${os useQt4 "qt4UI-"}${version}";

  inherit majorVersion;

  src = fetchurl {
    url = "${meta.homepage}files/v${majorVersion}/cmake-${version}.tar.gz";
    sha256 = "0y3w83al0vh9ll7fnqm3nx7l8hsl85k8iv9abxb791q36rp4xsdd";
  };

  enableParallelBuilding = true;

  # CYGWINTODO: check patches, they remove cygwin stuff

  patches =
    # Don't search in non-Nix locations such as /usr, but do search in
    # Nixpkgs' Glibc.
    optional (stdenv ? glibc) ./search-path-3.2.patch ++
    optional (stdenv ? cross) (fetchurl {
      name = "fix-darwin-cross-compile.patch";
      url = "http://public.kitware.com/Bug/file_download.php?"
          + "file_id=4981&type=bug";
      sha256 = "16acmdr27adma7gs9rs0dxdiqppm15vl3vv3agy7y8s94wyh4ybv";
<<<<<<< HEAD
    });

  buildInputs =
    [ bzip2 curl expat libarchive xz zlib ]
    ++ optional (jsoncpp != null) jsoncpp
=======
    }) ++
    # fix cmake detection of openssl libs
    # see: http://public.kitware.com/Bug/bug_relationship_graph.php?bug_id=15386
    #      and http://www.cmake.org/gitweb?p=cmake.git;a=commitdiff;h=c5d9a8283cfac15b4a5a07f18d5eb10c1f388505#patch1
    [./cmake_find_openssl_for_openssl-1.0.1m_and_up.patch] ++
      stdenv.lib.optional stdenv.isCygwin ./2.8.11-cygwin.patch;

  buildInputs = optionals (!stdenv.isCygwin) [ curl expat zlib bzip2 libarchive ]
>>>>>>> cygwin cmake
    ++ optional useNcurses ncurses
    ++ optional useQt4 qt4;

  propagatedBuildInputs = optional wantPS ps;

  CMAKE_PREFIX_PATH = stdenv.lib.concatStringsSep ":" buildInputs;

  configureFlags =
    [
      "--docdir=/share/doc/${name}"
      "--mandir=/share/man"
    ]
    ++ optional (!stdenv.isCygwin) "--system-libs"
    ++ optional (jsoncpp == null) "--no-system-jsoncpp"
    ++ optional useQt4 "--qt-gui"
    ++ ["--"]
    ++ optional (!useNcurses) "-DBUILD_CursesDialog=OFF";

  setupHook = ./setup-hook.sh;

  dontUseCmakeConfigure = true;

  preConfigure = optionalString (stdenv ? glibc)
    ''
      source $setupHook
      fixCmakeFiles .
      substituteInPlace Modules/Platform/UnixPaths.cmake \
        --subst-var-by glibc ${stdenv.glibc}
    '';

  meta = {
    homepage = http://www.cmake.org/;
    description = "Cross-Platform Makefile Generator";
    platforms = if useQt4 then qt4.meta.platforms else stdenv.lib.platforms.all;
    maintainers = with stdenv.lib.maintainers; [ urkud mornfall ttuegel ];
  };
}
