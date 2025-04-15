{
  pkgs,
  inputs,
  ...
}:
{
  home.stateVersion = "25.05";

  home.packages = (
    with pkgs;
    [
      # Tools
      ffmpeg
      ripgrep
      fd
      nvd
      tokei
      inputs.neovim-nightly-overlay.packages.${pkgs.system}.default

      # Languages
      bun
      nodejs_22
      nixfmt-rfc-style
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

  programs.ghostty = {
    enable = true;
    package = null;
    settings = {
      font-size = 15;
      font-thicken = true;
      adjust-cell-height = 2;
      mouse-hide-while-typing = true;
      alpha-blending = "linear-corrected";
      font-family = "Berkeley Mono";

      # Disable ligatures
      font-feature = [
        "-calt"
        "-liga"
        "-dlig"
      ];
    };
  };

  programs.fish = {
    enable = true;
    functions = {
      fish_greeting = "";
    };
    interactiveShellInit = ''
      fish_vi_key_bindings

      set fish_cursor_default     block      blink
      set fish_cursor_insert      line       blink
      set fish_cursor_replace_one underscore blink
      set fish_cursor_visual      block


      # Won't be neeeded once this is released: https://github.com/fish-shell/fish-shell/pull/10685
      set -g fish_vi_force_cursor 1
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

  programs.eza = {
    enable = true;
    enableFishIntegration = true;
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];
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
    ignores = [
      ".direnv"
      ".envrc"
      "shell.nix"
    ];
    delta = {
      enable = true;
    };
    signing = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB7muwsYWV2wwi9frDZlp2AwCMP0ohzoBBWjsxD1LW7/";
      format = "ssh";
      signByDefault = true;
      signer = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    };
    extraConfig = {
      init.defaultBranch = "main";
    };
  };
}
