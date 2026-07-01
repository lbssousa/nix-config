{ root, lib }:
let
  allFiles = lib.filesystem.listFilesRecursive root;
in
builtins.filter (
  path:
  let
    pathStr = toString path;
  in
  lib.hasSuffix ".nix" pathStr && builtins.baseNameOf pathStr != "imports.nix"
) allFiles
