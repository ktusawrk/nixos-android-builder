# Create an environment similar to `pkgs.buildFHSEnv`, but with a twist:
# No symlinks to the nix store are included, `/bin` and `/lib` include regular
# files. Executables are patched to look for their dynamic linker and libraries
# in `/lib`. You'd still have to ship a dynamic linker that searches /lib,
# see i.e. glibc-vanilla
{
  lib,
  writers,
  writeText,
  runCommandNoCC,
}:
{
  pins,
  storePaths,
}:
let
  buildFHSEnv = writers.writePython3 "build-fhsenv" {
    flakeIgnore = [ "E501" ]; # Line too long
  } ./fhsenv.py;

  pins' = writeText "pins" (lib.concatMapStringsSep "\n" builtins.toString pins);
in
runCommandNoCC "fhsenv" { } ''
  ${buildFHSEnv} ${storePaths} $out ${pins'}
''
