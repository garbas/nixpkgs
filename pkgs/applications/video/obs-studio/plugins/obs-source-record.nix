{ lib
, stdenv
, fetchFromGitHub
, gst_all_1
, pkg-config
, meson
, ninja
, obs-studio
, cmake
}:

let
  rev = "8d71fc5c6994cce68b912ae3c075e39415f982aa";
in stdenv.mkDerivation rec {
  pname = "obs-source-record";
  version = "0.3.0-${rev}";

  src = fetchFromGitHub {
    owner = "exeldro";
    repo = "obs-source-record";
    inherit rev;
    sha256 = "sha256-paw5sE0B7GxBreIoCxfg6gQf9vCRoxKyc84EjHKc5NY=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio ];

  cmakeFlags = [
    "-DBUILD_OUT_OF_TREE=1"
  ];

  meta = with lib; {
    description = "Plugin for OBS Studio to add a filter that allows you to record a source.";
    homepage = "https://github.com/exeldro/obs-source-record";
    maintainers = with maintainers; [ garbas ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
