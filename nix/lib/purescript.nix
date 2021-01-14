{ stdenv
, nodejs
, easyPS
, nix-gitignore
}:

{
  # path to generated purescript sources
  psSrc
  # path to project sources
, src
  # name of the project
, name
  # packages as generated by psc-pacakge2nix
, packages
  # spago packages as generated by spago2nix
, spagoPackages
  # web-common project
, webCommon
  # node_modules to use
, nodeModules
  # control execution of unit tests
, checkPhase
}:
let
  # Cleans the source based on the patterns in ./.gitignore and the additionalIgnores
  cleanSrcs = nix-gitignore.gitignoreSource [ "/*.adoc" "/*.nix" ] src;

in
stdenv.mkDerivation {
  inherit name checkPhase;
  src = cleanSrcs;
  buildInputs = [ nodeModules easyPS.purs easyPS.spago easyPS.psc-package ];
  buildPhase = ''
    export HOME=$NIX_BUILD_TOP
    shopt -s globstar
    ln -s ${nodeModules}/node_modules node_modules
    ln -s ${psSrc} generated
    ln -sf ${webCommon} web-common

    sh ${spagoPackages.installSpagoStyle}
    sh ${spagoPackages.buildSpagoStyle} src/**/*.purs test/**/*.purs generated/**/*.purs ./web-common/**/*.purs
    ${nodejs}/bin/npm run webpack
  '';
  doCheck = true;
  installPhase = ''
    mv dist $out
  '';
}
