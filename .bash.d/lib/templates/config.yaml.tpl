core:
  theme: default
  default_ide: vscode
  update_check_ttl_sec: 43200
  confirm_update_divergence: false
  max_parallel_threads: 8
  backup_warning_mb: 500
  log_rotate_bytes: 1048576

paths:
  vcs_root_dir: ~/vcs
  vcs_personal_dir: ~/vcs/personal
  vcs_exports_dir: ~/vcs/personal/exports
  dotfiles_dir: ~/vcs/personal/mt-devops-framework
  sync_repo_dir: ~/vcs/personal/mt-devops-framework
  ai_workspace_dir: ~/workspaces/ai
  iam_scripts_dir: /tmp/scripts/iam
  docker_root_dir: ~/.docker
  export_dir: /tmp/exports
  backup_dir: ~/backups

ai:
  enable_ai: true
  default_provider: gemini
  system_prompt_file: ~/.bash.d/config/ai/system_prompt.md
  max_context_bytes: 150000
  max_retries: 3
  max_context_files: 1000
  # The model names below are point-in-time picks, not permanent defaults --
  # providers rev their model lineups on their own schedule. A background
  # check (see mt-ai-models/mt-set-claude-model/mt-set-gemini-model) now
  # watches the active provider's live catalog and nags (via the shell
  # startup banner and 'mt-doctor') once its configured model is no longer
  # listed, so this no longer needs to be a recurring-self-audit item --
  # it only matters here for what a brand-new install starts pinned to.
  model_check_ttl_sec: 86400
  providers:
    gemini:
      model: gemini-3.6-flash
      enable_extended_reasoning: false
    claude:
      model: claude-sonnet-5
    # No API key needed -- shells out to a headless 'claude -p' using
    # whichever account Claude Code itself is logged into. Leave model
    # blank to use Claude Code's own default; otherwise an alias
    # ("sonnet", "opus") or a full model ID both work.
    claude_code:
      model: ""
    local:
      base_url: "http://localhost:11434/v1"
      model: llama3.2

git:
  feature_branch_prefix: feature/
  enable_format_on_push: true
  # Bitbucket workspace/project mt-git-clone routes into automatically --
  # unlike GitHub/GitLab, a Bitbucket clone URL only ever encodes the
  # workspace (git@bitbucket.org:<workspace>/<repo>.git), never the
  # project it's grouped under, so that second level can't be derived
  # from the URL and has to be configured instead.
  bitbucket_server: ""
  bitbucket_workspace: ""

llm_exports:
  enable_auto_cleanup: true
  auto_cleanup_days: 7
  file_blocklist_regex: (secret|token|credential|password|passwd|id_rsa|id_ed25519|\.pem$|\.p12$|\.pfx$|\.npmrc$|\.netrc$|kubeconfig|service.?account.*\.json$|.*-key.*\.json$|\.tfvars(\.json)?$|(^|/)\.env(\..+)?$|lock\.hcl|__pycache__|\.mt_cache.*|\.mt_data\.tsv|\.profile_update_cache|\.style\.yapf|\.update_check_cache|\.zoxide_cache\.sh|\.env\.cache)
  dir_ignore_glob: .git|.dev|.vscode|.idea|node_modules|__pycache__|.terraform|venv|.venv|.mt_cache*|target
  warn_file_threshold: 500
  max_file_threshold: 2000

docker:
  restart_blocklist_csv: "redis,postgres,local-db"
  default_registry: gar
  gar_region: europe-west2
  gar_repo: ""
  dockerhub_namespace: ""

server:
  default_port: 8000
  enable_auth: false
  enable_lan_bridge: false
  idle_timeout_sec: 1800

cicd:
  default_provider: github

minikube:
  driver: docker
  cpus: 2
  memory_mb: 4000

display:
  show_git: true
  show_gcp: true
  show_ai: true
  show_k8s: true
  show_ai_model: true
  compact_labels: false
  gcp_display: both
  git_branch_max_len: 30
  prod_bg_warning: false
