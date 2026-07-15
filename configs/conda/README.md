# Tool: conda

Conda is the Anaconda/Miniconda package and environment manager for Python.
This config redirects environment storage to `$XDG_DATA_HOME/conda/envs` and
package cache to `$XDG_CACHE_HOME/conda/pkgs`, keeping the home directory
clean and consistent with XDG base directory conventions.

## Files

- `condarc` -- conda's main YAML configuration; read from `~/.config/conda/condarc`
  (via the `CONDARC` env var or the XDG config path, depending on conda version)
  or from `~/.condarc` when symlinked there.

## Symlink destination

`~/.condarc` -> `${DOTFILEDIR}/configs/conda/condarc`

Wired via the `_:safe-link` entry in `taskfiles/links.yml` `configs:` sub-task.

## Feature gate

Always on -- no feature flag. `miniconda` is declared as a cask in
`manifests/machines/<name>.toml [packages].casks` for machines that use it
(currently `atium`); the condarc is lightweight enough to be always-on (it
simply redirects data paths and disables telemetry).

## References

- `taskfiles/links.yml` -- `configs:` sub-task registers the symlink (Plan 06)
