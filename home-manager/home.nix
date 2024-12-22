{ pkgs, ... }:
{
  home.stateVersion = "25.05";

  home.packages = (
    with pkgs;
    [
      # Tools
      direnv
      ffmpeg
      git
      neovim
      nix-direnv
      nixfmt-rfc-style
      ripgrep

      # GUI
      arc-browser
      kitty
      slack
      spotify

      # Languages
      bun
      nodejs_22
      (fenix.complete.withComponents [
        "cargo"
        "clippy"
        "rust-src"
        "rustc"
        "rustfmt"
      ])
    ]
  );

  home.sessionVariables = {
    EDITOR = "nvim";

    # XDG base directories
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_RUNTIME_DIR = "$TMPDIR";

    CARGO_HOME = "$HOME/.local/share/cargo";
  };

  # Don't show the "Last login" message for every new terminal.
  home.file.".hushlogin" = {
    text = "";
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Disable greeting
      set fish_greeting

      fish_vi_key_bindings

      set fish_cursor_default     block      blink
      set fish_cursor_insert      line       blink
      set fish_cursor_replace_one underscore blink
      set fish_cursor_visual      block
    '';
    shellAliases = {
      ga = "git add";
      gc = "git commit";
      gco = "git checkout";
      gcp = "git cherry-pick";
      gdiff = "git diff";
      gl = "git prettylog";
      gp = "git push";
      gs = "git status";
      gt = "git tag";
      cat = "bat";
    };
  };

  catppuccin.flavor = "mocha";
  catppuccin.enable = true;

  programs.bat.enable = true;
  programs.fzf.enable = true;
  programs.kitty = {
    enable = true;
    shellIntegration.mode = "no-sudo";
    shellIntegration.enableFishIntegration = true;
    settings = {
      # font_family = "JetBrains Mono NL";
      font_family = "Cascadia Code";
      font_size = 13;
      adjust_line_height = "130%";
      hide_window_decorations = "titlebar-only";
      window_padding_width = 10;
    };
  };

  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
    silent = true;
    nix-direnv.enable = true;
  };

  programs.ssh = {
    enable = true;
    extraConfig = "IdentityAgent \"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
  };

  programs.git = {
    enable = true;
    userName = "Dante Issaias";
    userEmail = "dante@issaias.com";
    extraConfig = {
      init.defaultBranch = "main";
      commit.gpgsign = true;
      user.signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB7muwsYWV2wwi9frDZlp2AwCMP0ohzoBBWjsxD1LW7/";
      gpg.format = "ssh";
      gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    };
  };
}
