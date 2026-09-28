# OCA Aggregated Modules

[![Odoo](https://img.shields.io/badge/Odoo-19.0-F1972B)](https://www.odoo.com)
[![Maintained by STeSI](https://img.shields.io/badge/maintained%20by-STeSI%20Consulting-F1972B)](https://stesi.consulting)

One repository with the OCA modules used by STeSI projects, so an Odoo.sh build clones one
submodule instead of one per OCA repository.

GitHub Actions writes every folder at the root. Do not edit them by hand: the next sync
overwrites them.

# How it works

`repos.txt` lists the sources, one per line:

```
<url> <branch> [module1,module2,...]
```

| Field | Meaning |
|---|---|
| `url` | Public repository, HTTPS |
| `branch` | Branch to follow, `19.0` |
| modules | Optional, comma-separated: keep only these modules; omit it to mirror the whole repository |

`sync.sh` runs for each line:

1. `git ls-remote` reads the branch head.
2. The script skips the line when the head and the module list match `.sync.lock`.
3. Otherwise it fetches the head with `--depth 1` and writes its tree, or the listed modules
   only, into `/<repo name>`.
4. One commit per repository. The body carries `Upstream: <url>@<sha>`, a GitHub link and
   `Modules: ...`. The link opens `compare/<previous sha>...<new sha>` with every upstream
   commit and file change since the last sync; the first sync of a repository links
   `tree/<sha>` instead.

A folder whose line left `repos.txt` gets removed in its own commit. A missing branch or a
listed module absent upstream stops the run with an error.

The upstream history stays in the source repositories: the sha in each sync commit points
to it.

# Workflow

`.github/workflows/sync.yml` runs every night at 04:00 UTC, on every push that changes
`repos.txt` or `sync.sh`, and on demand:

```bash
gh workflow run sync.yml -R ingegniamo/oca_aggregated_modules --ref 19.0
```

It pushes only when a repository changed.

# Use in a project

```bash
git submodule add -b 19.0 https://github.com/ingegniamo/oca_aggregated_modules.git oca
git submodule update --remote oca   # pick up the latest sync
```

# Credits

**Authors:** STeSI Consulting

**Contributors:** Michele Di Croce — dicroce.m@stesi.consulting
