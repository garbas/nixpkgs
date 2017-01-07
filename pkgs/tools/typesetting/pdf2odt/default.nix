{ stdenv, lib, makeWrapper, fetchFromGitHub
, bc, coreutils, file, gawk, ghostscript, gnused, imagemagick, zip
, cacert, curl, jq, nix-prefetch-zip, gnugrep
}:

let

  # this could be a script which can be used with any package
  fetchFromGitHubWithUpdate =
    { owner
    , repo
    , branch
    , path ? "src.json"
    }:
    let
      # still need to figure out what to do with this path
      src = fetchFromGitHub (lib.importJSON (./. + ("/" + path)));
      # ignroe the updateScript here, i just copied it from another project
      updateScript = ''
        pushd pkgs/tools/typesetting/pdf2odt

        export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
        github_rev() {
          ${curl.bin}/bin/curl -sSf "https://api.github.com/repos/$1/$2/branches/$3" | \
            ${jq}/bin/jq '.commit.sha' | \
            ${gnused}/bin/sed 's/"//g'
        }
        github_sha256() {
          ${nix-prefetch-zip}/bin/nix-prefetch-zip \
             --hash-type sha256 \
             "https://github.com/$1/$2/archive/$3.tar.gz" 2>&1 | \
             ${gnugrep}/bin/grep "hash is " | \
             ${gnused}/bin/sed 's/hash is //'
        }
        echo "=== ${owner}/${repo}@${branch} ==="
        echo -n "Looking up latest revision ... "
        rev=$(github_rev "${owner}" "${repo}" "${branch}");
        echo "revision is \`$rev\`."
        sha256=$(github_sha256 "${owner}" "${repo}" "$rev");
        echo "sha256 is \`$sha256\`."
        if [ "$sha256" == "" ]; then
          echo "sha256 is not valid!"
          exit 2
        fi
        source_file=${path}
        echo "Content of source file (``$source_file``) written."
        cat <<REPO | ${coreutils}/bin/tee "$source_file"
        {
          "owner": "${owner}",
          "repo": "${repo}",
          "rev": "$rev",
          "sha256": "$sha256"
        }
        REPO
        echo

        popd
      '';
    in
      src // { inherit updateScript; };


in stdenv.mkDerivation rec {
  version = "2014-12-17";
  name = "pdf2odt-${version}";

  src = fetchFromGitHubWithUpdate {
    owner = "gutschke";
    repo = "pdf2odt";
    branch = "master";
  };

  dontStrip = true;

  nativeBuildInputs = [ makeWrapper ];

  path = lib.makeBinPath [
    bc
    coreutils
    file
    gawk
    ghostscript
    gnused
    imagemagick
    zip
  ];

  patches = [ ./use_mktemp.patch ];

  installPhase = ''
    mkdir -p $out/bin $out/share/doc

    install -m0755 pdf2odt $out/bin/pdf2odt
    ln -rs $out/bin/pdf2odt $out/bin/pdf2ods

    install -m0644 README.md LICENSE -t $out/share/doc

    wrapProgram $out/bin/pdf2odt --prefix PATH : ${path}
  '';

  meta = with stdenv.lib; {
    description = "PDF to ODT format converter";
    homepage = http://github.com/gutschke/pdf2odt;
    license = licenses.mit;
    platforms = platforms.all;
    maintainers = with maintainers; [ peterhoeg ];
    inherit version;
  };
}
