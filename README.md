# bauhaus-start-dev

Creates this layout from a Git repository:

```text
minha-app/
├── .bare/
│   └── info/exclude       # contains .local-dev/
├── main/
│   └── .local-dev/
├── feat-101/
│   └── .local-dev/
└── feat-102/
    └── .local-dev/
```

Run the script as an executable, never with `source`:

```bash
./bauhaus-start-dev -r Bauhaus-Tech/minha-app -b main -b feat-101
```

To create a missing GitHub repository, authenticate once with `gh auth login`:

```bash
./bauhaus-start-dev -r Bauhaus-Tech/minha-app --create-repo -b feat-101
```

`--create-repo` makes a private repository by default, ensures that a `main`
branch exists, and makes `main` the GitHub default branch. Add `--public`
for a public repository or `--https` when GitHub SSH is not configured.

The target parent defaults to the current directory; use `--directory DIR` to
choose another location. Re-running a command reuses registered worktrees, while
an unrelated existing destination is rejected to protect files.

## Test

```bash
./tests/test_bauhaus_start_dev.sh
```

The test uses an isolated local bare remote; it requires no GitHub access.
