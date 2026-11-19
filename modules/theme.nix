# Blue accents for SDDM and the shared cursor theme.
{ pkgs, ... }:

let
  flavor = "mocha";
  accent = "blue";
in
{
  environment.systemPackages = [
    pkgs.catppuccin-cursors.mochaBlue
    (pkgs.catppuccin-sddm.override {
      inherit flavor accent;
      font = "Pretendard";
      fontSize = "10";
      background = "${../files/blue-hour.jpg}";
    })
  ];

  fonts = {
    packages = with pkgs; [
      pretendard
      noto-fonts-cjk-sans
      nerd-fonts.jetbrains-mono
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Pretendard" "Noto Sans CJK KR" ];
      monospace = [ "JetBrainsMono Nerd Font" "Noto Sans Mono CJK KR" ];
    };
  };

  services.displayManager.sddm = {
    theme = "catppuccin-${flavor}-${accent}";
    extraPackages = [ pkgs.kdePackages.qtsvg ];
  };
}
