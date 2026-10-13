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
    inputs.nix-index-database.homeModules.nix-index
  ];

  # `, <cmd>` runs any nixpkgs program without installing it. The fish
  # command-not-found handler from nix-index is not wanted, so nix-index is off.
  programs.nix-index.enable = false; # the module sets this to true by default
  programs.nix-index-database.comma.enable = true;

  home.stateVersion = "26.05";

  xdg.dataFile."pi/agent/extensions/parallel-web-search.ts".source = ./pi/parallel-web-search.ts;
  xdg.dataFile."pi/agent/extensions/background-compaction.ts".source = ./pi/background-compaction.ts;
  xdg.dataFile."pi/agent/APPEND_SYSTEM.md".source = ./pi/APPEND_SYSTEM.md;
  xdg.configFile."opencode/AGENTS.md".source = ./pi/APPEND_SYSTEM.md;

  # pi writes to settings.json itself (deviceId etc.), so it cannot be a
  # read-only link. Merge ./pi/settings.json into it instead; keys from this
  # repo win over keys already in the file.
  home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] /* sh */ ''
    settings="${dataHome}/pi/agent/settings.json"
    if [[ -z "''${DRY_RUN:-}" ]]; then
      mkdir -p "$(dirname "$settings")"
      [[ -s "$settings" ]] || echo '{}' > "$settings"
      tmp=$(mktemp)
      ${lib.getExe pkgs.jq} -s '.[0] * .[1]' "$settings" ${./pi/settings.json} > "$tmp" \
        && mv "$tmp" "$settings"
    fi
  '';

  home.packages = with pkgs; [
    ffmpeg
    ripgrep
    fd
    tokei
    curl
    pnpm
    jq
    terraform
    awscli2
    github-cli
    mergiraf
    go
    python311
    jj-starship
    _1password-cli
    ghq
    pandoc
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2
    # The opencode2 package only ships `opencode2`; keep the `opencode` name.
    (pkgs.runCommand "opencode" { } ''
      mkdir -p $out/bin
      ln -s ${lib.getExe' inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2 "opencode2"} $out/bin/opencode
    '')
    ast-grep
    xh
    sd
    dust
    hyperfine
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
      tree-sitter
      gopls
      nixfmt
      vscode-langservers-extracted
      lua-language-server
      nixd
      stylua
      tailwindcss-language-server
      fswatch # https://github.com/neovim/neovim/pull/27347
      terraform-ls
      yaml-language-server
      stylelint-lsp
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
    RUSTUP_HOME = "${dataHome}/rustup";

    PI_CODING_AGENT_DIR = "${dataHome}/pi/agent";
    # pi is updated through the llm-agents.nix flake input, not by itself.
    PI_SKIP_VERSION_CHECK = "1";

    HOMEBREW_CACHE = "${cacheHome}/homebrew";
    HOMEBREW_LOGS = "${stateHome}/homebrew/logs";

    LESSHISTFILE = "${stateHome}/lesshst";

    NODE_REPL_HISTORY = "${stateHome}/node_repl_history";
    NPM_CONFIG_USERCONFIG = "${configHome}/npm/npmrc";
    # pnpm ignores the project .npmrc when it fetches the pinned pnpm version.
    PNPM_CONFIG_REGISTRY = "https://registry.yarnpkg.com/";
    PNPM_CONFIG_GLOBAL_PNPMFILE = "${configHome}/pnpm/global_pnpmfile.cjs";

    DOCKER_CONFIG = "${configHome}/docker";
    FLY_CONFIG_DIR = "${stateHome}/fly";
  };

  xdg.configFile."npm/npmrc".text = ''
    prefix=${dataHome}/npm
    cache=${cacheHome}/npm
    init-module=${configHome}/npm/config/npm-init.js
    logs-dir=${stateHome}/npm/logs
    registry=https://registry.yarnpkg.com/
  '';

  # registry.yarnpkg.com metadata points tarballs at registry.npmjs.org, which
  # some networks block. npm rewrites the host itself; pnpm needs this fetcher.
  xdg.configFile."pnpm/global_pnpmfile.cjs".text = ''
    const NPMJS = "https://registry.npmjs.org/";
    const YARN = "https://registry.yarnpkg.com/";
    module.exports = {
      fetchers: [
        {
          canFetch: (_id, r) => typeof r?.tarball === "string" && r.tarball.startsWith(NPMJS),
          fetch: (_cafs, r) => ({ delegate: { ...r, tarball: YARN + r.tarball.slice(NPMJS.length) } }),
        },
      ],
    };
  '';

  home.sessionPath = [
    "${dataHome}/cargo/bin"
    "${dataHome}/npm/bin"
  ];

  # Don't show the "Last login" message for every new terminal.
  home.file.".hushlogin".text = "";

  # Rex config: one Lua file managed from this repo (key bindings / actions).
  xdg.configFile."rex/init.lua".source = ./rex/init.lua;

  # Rex font and theme are NOT in init.lua. They live in the
  # com.superlogical.rex defaults domain. Font and theme IDs are plain
  # strings; the custom theme itself is a JSON array stored as a Data value,
  # so it must be written with `defaults write -data`. This runs as the user.
  # Quit Rex before switching, or Rex may overwrite these on quit.
  home.activation.rexAppearance = lib.hm.dag.entryAfter [ "writeBoundary" ] /* sh */ ''
    DOMAIN=com.superlogical.rex
    THEME_ID="custom-B9DB6786-2D8E-49B8-BF09-CB7B6038DC0F"
    HEX=$(/usr/bin/xxd -p ${./rex/catppuccin-themes.json} | tr -d '\n')
    run /usr/bin/defaults write "$DOMAIN" "Workspace.terminalFontName" -string "Berkeley Mono"
    run /usr/bin/defaults write "$DOMAIN" "Workspace.customThemes" -data "$HEX"
    run /usr/bin/defaults write "$DOMAIN" "Workspace.darkThemeID"  -string "$THEME_ID"
    run /usr/bin/defaults write "$DOMAIN" "Workspace.lightThemeID" -string "$THEME_ID"
  '';

  programs.carapace = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.mise = {
    enable = true;
    enableFishIntegration = true;
    globalConfig = {
      tools = {
        node = "26.10.0";
        rust = "nightly";
      };
      settings.idiomatic_version_file_enable_tools = [
        "node"
        "rust"
      ];
    };
  };

  # Run mise install
  home.activation.miseInstall = lib.hm.dag.entryAfter [ "linkGeneration" "installPackages" ] /* sh */ ''
    (
      unset __HM_SESS_VARS_SOURCED
      set +u
      . "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh"
      set -u
      export PATH="${config.home.profileDirectory}/bin:$PATH"
      run ${lib.getExe config.programs.mise.package} --cd "${configHome}/mise" install
    )
  '';

  programs.fish = {
    enable = true;
    functions.fish_greeting = "";
    interactiveShellInit = ''
      fish_vi_key_bindings

      set fish_cursor_default     block      blink
      set fish_cursor_insert      line       blink
      set fish_cursor_replace_one underscore blink
      set fish_cursor_visual      block

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

      aliases.sync = [
        "util"
        "exec"
        "--"
        "sh"
        "-c"
        "jj git fetch && jj rebase -d 'trunk()'"
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
