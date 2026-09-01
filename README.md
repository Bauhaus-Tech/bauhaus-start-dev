# bauhaus-start-dev

`bauhaus-start-dev` creates a local Git workspace designed for working on
several branches of the same project at once. Instead of repeatedly switching
branches in one checkout, it keeps a bare repository and creates one linked Git
worktree per requested branch. Each worktree receives a local-only
`.local-dev/` directory that Git ignores.

This is useful when, for example, `main`, a feature branch, and a bug-fix
branch must remain available side by side.

## Resulting workspace

For a repository named `minha-app` and branches `main`, `feat-101`, and
`feat-102`, the tool creates:

```text
minha-app/
├── .bare/                 # shared bare Git repository
│   └── info/exclude       # contains .local-dev/
├── main/                  # Git worktree for main
│   └── .local-dev/        # ignored, machine-specific files
├── feat-101/              # Git worktree for feat-101
│   └── .local-dev/
└── feat-102/              # Git worktree for feat-102
    └── .local-dev/
```

Files in `.local-dev/` are ignored through the shared repository's
`.bare/info/exclude`; they are never added to the project's `.gitignore`.

## Requirements

- Bash and Git.
- The GitHub CLI (`gh`) only when using `--create-repo`, authenticated with
  `gh auth login`.
- Access to the remote repository when cloning a remote source.

Run the script as an executable, never with `source`:

```bash
./bauhaus-start-dev --help
```

## Usage

```text
./bauhaus-start-dev -r <repository> -b <branch> [-b <branch> ...] [options]
```

`--repo` and at least one `--branch` are required. Repeat `--branch` to create
multiple worktrees in a single run.

| Option | Description |
| --- | --- |
| `-r`, `--repo REPOSITORY` | Repository source. Accepts a GitHub `owner/repo` slug, a GitHub URL, another Git URL, or a local Git path. |
| `-b`, `--branch BRANCH` | Branch to check out. If it exists remotely, it is checked out as a tracking branch; otherwise it is created from the repository's current `HEAD`. Repeat this option for each worktree. |
| `-d`, `--directory DIR` | Parent directory where the repository workspace is created. Defaults to the current directory. |
| `--create-repo` | Creates a missing GitHub repository. Only works with an `owner/repo` GitHub repository argument. It ensures a `main` worktree exists and sets `main` as the GitHub default branch. |
| `--public` | Makes a repository created with `--create-repo` public. |
| `--private` | Makes a repository created with `--create-repo` private. This is the default. |
| `--https` | Uses HTTPS for a GitHub slug; HTTPS is already the default. |
| `-h`, `--help` | Displays the built-in usage summary. |

## Examples

Create worktrees for the existing `main` and `feat-101` branches in the
current directory:

```bash
./bauhaus-start-dev -r Bauhaus-Tech/minha-app -b main -b feat-101
```

Create the same workspace below a chosen parent directory:

```bash
./bauhaus-start-dev \
  --repo Bauhaus-Tech/minha-app \
  --branch main \
  --branch feat-101 \
  --directory ~/workspace
```

Use a local bare repository or another local Git source instead of GitHub:

```bash
./bauhaus-start-dev --repo /path/to/minha-app.git --branch main
```

Create a missing private GitHub repository and add a feature worktree. The
tool adds `main` automatically because a newly created repository needs a
default branch:

```bash
gh auth login
./bauhaus-start-dev -r Bauhaus-Tech/minha-app --create-repo -b feat-101
```

Add `--public` to make the newly created repository public:

```bash
./bauhaus-start-dev \
  -r Bauhaus-Tech/minha-app \
  --create-repo \
  --public \
  -b feat-101
```

## Behavior and safety

- Running the same command again reuses registered worktrees, so it is safe to
  re-run for an existing workspace.
- If the destination exists but is not a workspace managed by this tool, the
  command stops rather than altering its files.
- Invalid or unsafe branch names are rejected.
- Existing local branches are reused; remote branches are set up to track
  `origin/<branch>`; missing branches are created from `HEAD`.
- A repository must have at least one commit before a new branch can be
  created. `--create-repo` creates an initial commit for this reason.

## Test

Run the integration test from the repository root:

```bash
./tests/test_bauhaus_start_dev.sh
```

The test uses an isolated local bare remote and does not require GitHub access.
