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
multiple worktrees in a single run, or to select multiple worktrees/branches
for removal.

| Option | Description |
| --- | --- |
| `-r`, `--repo REPOSITORY` | Repository source. Accepts a GitHub `owner/repo` slug, a GitHub URL, another Git URL, or a local Git path. |
| `-b`, `--branch BRANCH` | Branch to check out. If it exists remotely, it is checked out as a tracking branch; otherwise it is created from the repository's current `HEAD`. Repeat this option for each worktree. |
| `-d`, `--directory DIR` | Parent directory where the repository workspace is created. Defaults to the current directory. |
| `--remove-local` | Removes each selected local worktree after confirmation. |
| `--remove-remote` | Deletes each selected branch from `origin` after confirmation. |
| `--create-repo` | Creates a missing GitHub repository. Only works with an `owner/repo` GitHub repository argument. It ensures a `main` worktree exists and sets `main` as the GitHub default branch. Cannot be combined with a removal option. |
| `--public` | Makes a repository created with `--create-repo` public. |
| `--private` | Makes a repository created with `--create-repo` private. This is the default. |
| `--https` | Uses HTTPS for a GitHub slug; HTTPS is already the default. |
| `-h`, `--help` | Displays the built-in usage summary. |

## Examples

### Create worktrees in the current directory

Create worktrees for the existing `main` and `feat-101` branches in the
current directory:

```bash
./bauhaus-start-dev -r Bauhaus-Tech/minha-app -b main -b feat-101
```

### Create worktrees in a chosen directory

Create the same workspace below a chosen parent directory:

```bash
./bauhaus-start-dev \
  --repo Bauhaus-Tech/minha-app \
  --branch main \
  --branch feat-101 \
  --directory ~/workspace
```

### Add a worktree to an existing workspace

To add a branch after the workspace has already been created, run the tool from
the workspace's parent directory and provide the same repository name. For
example, from the directory that contains the existing `bauhaus-start-dev/`
workspace:

```bash
bauhaus-start-dev -r Bauhaus-Tech/bauhaus-start-dev -b feat-002
```

This creates or checks out `bauhaus-start-dev/feat-002/` while reusing the
existing `bauhaus-start-dev/.bare/` repository. Do not run this command from
inside `bauhaus-start-dev/`; either change to its parent directory or pass that
parent explicitly with `--directory`.

```bash
bauhaus-start-dev \
  -r Bauhaus-Tech/bauhaus-start-dev \
  -b feat-002 \
  --directory /path/to/the/workspace-parent
```

### Use a local Git source

Use a local bare repository or another local Git source instead of GitHub:

```bash
./bauhaus-start-dev --repo /path/to/minha-app.git --branch main
```

### Create a private GitHub repository

Create a missing private GitHub repository and add a feature worktree. The
tool adds `main` automatically because a newly created repository needs a
default branch:

```bash
gh auth login
./bauhaus-start-dev -r Bauhaus-Tech/minha-app --create-repo -b feat-101
```

### Create a public GitHub repository

Add `--public` to make the newly created repository public:

```bash
./bauhaus-start-dev \
  -r Bauhaus-Tech/minha-app \
  --create-repo \
  --public \
  -b feat-101
```

### Remove worktrees and branches

Use `--remove-local` to remove the selected local worktree,
`--remove-remote` to delete its branch from `origin`, or combine both. The tool
asks for confirmation before every local and remote operation; press `y` (or
type `yes`) to proceed. Any other input, including end-of-file, keeps that
item.

```bash
# Remove only the local feat-101 worktree.
./bauhaus-start-dev -r Bauhaus-Tech/minha-app -b feat-101 --remove-local

# Delete the remote branch, while keeping its local worktree.
./bauhaus-start-dev -r Bauhaus-Tech/minha-app -b feat-101 --remove-remote

# Remove both, confirming each operation separately.
./bauhaus-start-dev -r Bauhaus-Tech/minha-app -b feat-101 --remove-local --remove-remote
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
- Removal operates only on an existing managed workspace. Local removal uses
  `git worktree remove` without forcing, so Git refuses to remove a worktree
  with uncommitted changes.

## Test

Run the integration test from the repository root:

```bash
./tests/test_bauhaus_start_dev.sh
```

The test uses an isolated local bare remote and does not require GitHub access.
