# Noctalia's Wi-Fi list merges access points with the same name into one row, so a network served
# by several access points (2.4 and 5 GHz, mesh nodes, several routers) shows up once and one
# cannot choose which to join. The patch lists every access point with its band and channel.
# This builds Noctalia from source instead of using the Noctalia cache.
{ lib, noctalia, pkgs, ... }:

{
  programs.noctalia.package = noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./../patches/noctalia-ap-list.patch ];
  });
}
