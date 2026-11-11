{ lan-mouse-niri, system }:
lan-mouse-niri.packages.${system}.default.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ../patches/lan-mouse-stable-protocol.patch ];
})
