{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (config.xdg)
    cacheHome
    configHome
    dataHome
    stateHome
    ;
in
{
  imports = [
    inputs.catppuccin.homeModules.catppuccin
  ];

  home.stateVersion = "25.05";

  home.packages = (
    with pkgs;
    [
      ffmpeg
      ripgrep
      fd
      tokei
      curl
      jq
      jujutsu
      bun
      pnpm
      rustup
      terraform
      awscli2
      flyctl
      github-cli
      global-npm
    ]
  );

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/etc/nix-darwin";
  };

  xdg.enable = true;
  home.preferXdgDirectories = true;

  programs.neovim = {
    enable = true;
    package = inputs.neovim-nightly-overlay.packages.${pkgs.system}.default;
    vimAlias = true;
    viAlias = true;
    defaultEditor = true;
    extraPackages = with pkgs; [
      nixfmt-rfc-style
      vtsls
      vscode-langservers-extracted
      lua-language-server
      nixd
      stylua
      prettierd
      tailwindcss-language-server
      fswatch # https://github.com/neovim/neovim/pull/27347
      terraform-ls
    ];
  };

  home.sessionVariables.MANPAGER = "nvim +Man!";

  # Prevent home manager from creating an init.lua, I'm not managing my neovim
  # config with nix yet.
  catppuccin.nvim.enable = false;

  # Make various apps use XDG directories.
  home.sessionVariables = {
    BUNDLE_USER_CONFIG = "${configHome}/bundle/config";
    BUNDLE_USER_CACHE = "${cacheHome}/bundle";
    BUNDLE_USER_PLUGIN = "${dataHome}/bundle/plugin";

    CARGO_HOME = "${dataHome}/cargo";

    LESSHISTFILE = "${stateHome}/lesshst";

    NODE_REPL_HISTORY = "${stateHome}/node_repl_history";
    NPM_CONFIG_USERCONFIG = "${configHome}/npm/npmrc";

    DOCKER_CONFIG = "${configHome}/docker";
    FLY_CONFIG_DIR = "${stateHome}/fly";

    N_PREFIX = "${dataHome}/n";
  };

  xdg.configFile."npm/npmrc".text = ''
    prefix=${dataHome}/npm
    cache=${cacheHome}/npm
    init-module=${configHome}/npm/config/npm-init.js
    logs-dir=${stateHome}/npm/logs
  '';

  home.sessionPath = [
    # Node.js managed by n
    "${dataHome}/n/bin"
  ];

  # Don't show the "Last login" message for every new terminal.
  home.file.".hushlogin".text = "";

  programs.ghostty = {
    enable = true;
    package = null;
    settings = {
      # font-size = 14;
      # font-thicken = true;
      # font-thicken-strength = 50;
      # adjust-cell-height = 3;
      # alpha-blending = "linear-corrected";
      mouse-hide-while-typing = true;
      font-family = "Berkeley Mono";

      keybind = [
        # Shift+Enter newline in Claude Code
        "shift+enter=text:\\n"
      ];

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
      cdx = ''
        # from: <https://x.com/iannuttall/status/1965090297630826931>
        # Note: with auto confirmation. Use at your own risk. Thanks!
        codex -m gpt-5-codex --yolo -c model_reasoning_effort=high -c model_reasoning_summary_format=experimental --search $argv
      '';
      fish_greeting = "";
    };
    interactiveShellInit = ''
      fish_vi_key_bindings

      set fish_cursor_default     block      blink
      set fish_cursor_insert      line       blink
      set fish_cursor_replace_one underscore blink
      set fish_cursor_visual      block
    '';
    shellAliases = {
      # ga = "git add";
      # gc = "git commit";
      # gco = "git checkout";
      # gcp = "git cherry-pick";
      # gdiff = "git diff";
      # gl = "git log";
      # gp = "git push";
      # glr = "git pull --rebase";
      # gs = "git status";
      # stash = "git stash";
      # pop = "git stash pop";
      git = "echo 'use jj instead'";
      cat = "bat";
      sw = "nh darwin switch";
    };
    shellAbbrs = {
      pb = "pbpaste | jq";
      # Granola
      apply = "pnpm run dev:apply";
      run = "pnpm run dev";
      gen = "pnpm run dev:terraform:generate-output";
      cache = "./scripts/clear-cache.sh";
      deploy = "DEV_PROFILE=danteissaias pnpm dev:lambda:deploy";
    };
  };

  programs.starship.enable = true;
  programs.starship.settings = lib.mkMerge [
    (builtins.fromTOML (
      builtins.readFile "${pkgs.starship}/share/starship/presets/nerd-font-symbols.toml"
    ))
    {
      nix_shell.impure_msg = "";
      directory.fish_style_pwd_dir_length = 1; # turn on fish directory truncation
      directory.truncation_length = 2; # number of directories not to truncate
    }
  ];

  catppuccin.flavor = "mocha";
  catppuccin.enable = true;

  programs.bat.enable = true;
  programs.fzf.enable = true;

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

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
    # Use 1Password agent
    extraConfig = "IdentityAgent \"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
  };

  programs.btop.enable = true;

  programs.git = {
    enable = true;
    userName = "Dante Issaias";
    userEmail = "dante@issaias.com";
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
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        email = "dante@issaias.com";
        name = "Dante Issaias";
      };

      # Use 1Password SSH key for signing commits
      signing = {
        behavior = "own";
        backend = "ssh";
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB7muwsYWV2wwi9frDZlp2AwCMP0ohzoBBWjsxD1LW7/";
        backends.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      };

      # Use delta as the default pager
      ui = {
        pager = "delta";
        diff-formatter = ":git";
      };

      # Silence help message
      ui.default-command = "log";

      # Move the closest bookmark to the current commit.
      aliases.tug = [
        "bookmark"
        "move"
        "--from"
        "heads(::@- & bookmarks())"
        "--to"
        "@-"
      ];

      # Instead of signing all commits during creation when signing.behavior is set to own,
      # the git.sign-on-push configuration can be used to sign commits only upon running jj
      # git push. All mutable unsigned commits being pushed will be signed prior to pushing.
      # This might be preferred if the signing backend requires user interaction or is slow,
      # so that signing is performed in a single batch operation.
      git.sign-on-push = true;
    };
  };

}
