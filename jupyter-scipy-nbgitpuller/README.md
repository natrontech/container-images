# jupyter-scipy-nbgitpuller

Upstream [Jupyter scipy-notebook](https://quay.io/repository/jupyter/scipy-notebook)
plus [nbgitpuller](https://github.com/jupyterhub/nbgitpuller), which lets
lecturers distribute course material through a link that clones or updates a git
repository into each student's home directory without overwriting their work.

## Pinned versions

| Component | Version |
| --- | --- |
| Base image | `quay.io/jupyter/scipy-notebook:2026-09-01` |
| Base digest | `sha256:41e9176dc64072976c43c037f853ae9a95ca34aeb0170c58a1b304d62fbde486` |
| nbgitpuller | `1.3.0` |

Bumping the base image or nbgitpuller means updating the `ARG`/`FROM` in the
`Dockerfile`, this table, and `VERSION`. A nbgitpuller bump takes the new
nbgitpuller version; a base-image-only bump takes a revision suffix, e.g.
`1.3.0-2`.

## Why this image exists

nbgitpuller is not part of the upstream Jupyter Docker Stacks and cannot be added
at runtime. A `pip install --user` lands in `~/.local`, which the `jupyter`
entrypoint does not see, because it runs conda's Python. The server extension
therefore never loads and `/user-redirect/git-pull` returns 404. Installing into
the conda environment is the only reliable route, which requires an image.

It is tempting to add it only to this CPU image, on the grounds that nbgitpuller
writes into the user's home directory and that volume is mounted by every
JupyterHub profile. That reasoning is wrong: `/hub/user-redirect/git-pull`
redirects to `/user/<name>/git-pull`, meaning whichever server the user
currently has running, with no profile selection in the link. A student on a GPU
profile who clicks a course link would get a 404. Every profile a student can be
on needs the extension, which is why `jupyter-pytorch-nbgitpuller` and
`jupyter-tensorflow-nbgitpuller` exist alongside this one.

## Usage

As a JupyterHub singleuser image:

```yaml
singleuser:
	image:
		name: ghcr.io/natrontech/container-images/jupyter-scipy-nbgitpuller
		tag: "1.3.0"
```

A pull link then has the shape:

```
https://<hub>/hub/user-redirect/git-pull?repo=<repo-url>&branch=<branch>&urlpath=lab/tree/<path>
```

For a public repository no credentials belong in the URL. Avoid the
`https://user:TOKEN@host/...` form: these links are handed to students and end up
in browser history, proxy logs and course pages.

## Platforms

`linux/amd64` only. The consuming cluster is amd64, and the base image is large
enough that building an unused arm64 variant is not worth the registry space.
Remove `PLATFORMS` to restore the repository default.
