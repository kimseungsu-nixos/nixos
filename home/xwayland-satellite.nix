{ pkgs }:

pkgs.xwayland-satellite.overrideAttrs (old: {
  patches = (old.patches or []) ++ [ ../patches/xwayland-satellite-kakaotalk-dialogs.patch ];
  # Unit tests cover the dialog/tooltip distinction; integration tests need a display.
  postBuild = (old.postBuild or "") + ''
    cargo test --target ${pkgs.stdenv.hostPlatform.rust.rustcTarget} --release --lib window_role_heuristics --no-default-features --features systemd --offline
  '';
})
