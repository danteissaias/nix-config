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

  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    ffmpeg
    ripgrep
    fd
    tokei
    curl
    jq
    pnpm
    rustup
    terraform
    awscli2
    github-cli
    mergiraf
    go
    python311
    jj-starship
    carapace
    _1password-cli
    fnm
    ghq
  ];

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
    package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;
    vimAlias = true;
    viAlias = true;
    defaultEditor = true;
    extraPackages = with pkgs; [
      # TODO: Remove when we get 0.26.1 from nixpkgs
      (pkgs.rustPlatform.buildRustPackage rec {
        pname = "tree-sitter";
        version = "0.26.1";
        src = pkgs.fetchFromGitHub {
          owner = "tree-sitter";
          repo = "tree-sitter";
          rev = "v${version}";
          hash = "sha256-k8X2qtxUne8C6znYAKeb4zoBf+vffmcJZQHUmBvsilA=";
        };
        cargoHash = "sha256-hnFHYQ8xPNFqic1UYygiLBWu3n82IkTJuQvgcXcMdv0=";
        cargoBuildFlags = [
          "-p"
          "tree-sitter-cli"
        ];
        doCheck = false;
      })
      gopls
      nixfmt
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
  xdg.configFile."nvim/init.lua".enable = lib.mkForce false;

  programs.man.generateCaches = false;

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
    registry=https://registry.yarnpkg.com/
  '';

  home.sessionPath = [
    # Node.js managed by n
    "${dataHome}/n/bin"
    "${dataHome}/cargo/bin"
  ];

  # Don't show the "Last login" message for every new terminal.
  home.file.".hushlogin".text = "";

  home.file.".pi/agent/AGENTS.md".text = ''
    - Prefer `jj` over `git`
    - Prefer modern CLI tools (`fd`, `rg`, `jq`, `bat`, `eza`, `fzf`, etc.)
    - No code comments
    - No emdashes, no bold, no emoji.
    - Prefer plain words (is/has) over puffed-up ones (serves as/represents).
  '';

  programs.ghostty = {
    enable = true;
    package = null;
    settings = {
      auto-update = "off";
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
    functions.fish_greeting = "";
    interactiveShellInit = ''
      fish_vi_key_bindings

      set fish_cursor_default     block      blink
      set fish_cursor_insert      line       blink
      set fish_cursor_replace_one underscore blink
      set fish_cursor_visual      block

      # TODO can nix do these?
      carapace _carapace | source
      fnm env --use-on-cd --shell fish | source
    '';
    shellAliases = {
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
    (fromTOML (builtins.readFile "${pkgs.starship}/share/starship/presets/nerd-font-symbols.toml"))
    {
      nix_shell.impure_msg = "";
      directory.fish_style_pwd_dir_length = 1; # turn on fish directory truncation
      directory.truncation_length = 2; # number of directories not to truncate
      custom.jj = {
        command = "jj-starship --no-symbol";
        shell = [ "sh" ];
        format = "$output ";
        detect_folders = [ ".jj" ];
      };
      git_branch.disabled = true;
      git_status.disabled = true;
      git_state.disabled = true;
      git_commit.disabled = true;
    }
  ];

  catppuccin.flavor = "mocha";
  catppuccin.enable = true;
  catppuccin.autoEnable = true;

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
    enableDefaultConfig = false;
    settings."*" = {
      ForwardAgent = false;
      ServerAliveInterval = 0;
      ServerAliveCountMax = 3;
      Compression = false;
      AddKeysToAgent = "no";
      HashKnownHosts = false;
      UserKnownHostsFile = "~/.ssh/known_hosts";
      ControlMaster = "no";
      ControlPath = "~/.ssh/master-%C";
      ControlPersist = "no";
      # Use 1Password agent
      IdentityAgent = ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';
    };
  };

  programs.btop.enable = true;

  programs.delta.enable = true;
  programs.delta.enableGitIntegration = true;

  programs.git = {
    enable = true;
    signing = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB7muwsYWV2wwi9frDZlp2AwCMP0ohzoBBWjsxD1LW7/";
      format = "ssh";
      signByDefault = true;
      signer = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    };
    settings = {
      user = {
        name = "Dante Issaias";
        email = "dante@issaias.com";
      };

      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      ghq.root = "~/Repos";
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
      revsets.bookmark-advance-to = "@-";
      aliases.tug = [
        "bookmark"
        "advance"
      ];

      templates.git_push_bookmark = "\"dante/\" ++ committer.timestamp().format(\"%m-%d\") ++ \"_\" ++ description_slug(description)";

      # Replace all non-word characters with -
      # Replace multiple --- with a single -
      # Remove a starting or ending -
      template-aliases."description_slug(description)" = ''
        truncate_end(
          244,
          description
            .first_line()
            .lower()
            .replace(regex:"[[:^word:]]", "-")
            .replace(regex:"-+", "-")
            .replace(regex:"^-|-$", "")
        ) 
      '';

      # Instead of signing all commits during creation when signing.behavior is set to own,
      # the git.sign-on-push configuration can be used to sign commits only upon running jj
      # git push. All mutable unsigned commits being pushed will be signed prior to pushing.
      # This might be preferred if the signing backend requires user interaction or is slow,
      # so that signing is performed in a single batch operation.
      git.sign-on-push = true;
    };
  };

}
