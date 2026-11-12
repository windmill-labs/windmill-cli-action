# Windmill CLI action

Installs the [Windmill](https://www.windmill.dev) CLI (`wmill`, npm package [`windmill-cli`](https://www.npmjs.com/package/windmill-cli)) and optionally runs one `wmill` command against a workspace. It replaces the `npm install -g windmill-cli` and `wmill sync push ...` steps of the git sync CI workflows in the [Windmill docs](https://www.windmill.dev/docs/advanced/git_sync).

## Deploy a repository to a workspace on merge

```yaml
name: Deploy to Windmill
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: windmill-labs/windmill-cli-action@v1
        with:
          command: sync push --yes --skip-variables --skip-secrets --skip-resources
          token: ${{ secrets.WMILL_TOKEN }}
          workspace: my-workspace
          base-url: https://app.windmill.dev
          cli-version: 1.868.0
```

## Install only

Leave `command` empty and call `wmill` in later steps:

```yaml
      - uses: windmill-labs/windmill-cli-action@v1
        with:
          cli-version: 1.868.0
      - run: wmill sync pull --yes --workspace my-workspace --token "$WMILL_TOKEN" --base-url https://app.windmill.dev
        env:
          WMILL_TOKEN: ${{ secrets.WMILL_TOKEN }}
```

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `command` | no | | Arguments passed to `wmill`, e.g. `sync push --yes`. Empty: only install `wmill`. |
| `token` | no | | Windmill API token; store it as a secret. When set, `--workspace`, `--token` and `--base-url` are appended to the command. |
| `workspace` | when `token` is set | | Workspace id. |
| `base-url` | no | `https://app.windmill.dev` | Base URL of the instance; set it for self-hosted Windmill. |
| `cli-version` | no | `latest` | `windmill-cli` version. Pin it so CI does not change with each release. |
| `node-version` | no | `24` | Node.js version used to run `wmill`. |
| `working-directory` | no | `.` | Directory in which `wmill` runs (the folder holding `wmill.yaml`). |

`command` is split on whitespace and passed to `wmill` as separate arguments. It is never evaluated by a shell, so quotes, `$VARIABLES`, `$(...)` and globs are passed literally. For arguments that contain spaces, use the install-only mode and call `wmill` in a `run` step.

## Notes

- With `token` set, the action passes `--base-url`, which makes `wmill` use only the given token and workspace and ignore any stored CLI profile.
- `sync push` writes every local file selected by `wmill.yaml` to the workspace. Use a dedicated token and the `includes`/`excludes` settings of `wmill.yaml` ([sync docs](https://www.windmill.dev/docs/advanced/cli/sync)) so the repository only manages the paths it owns.
- Works on Linux, macOS and Windows runners (steps run in `bash`).

## License

Apache 2.0, see [LICENSE](LICENSE).
