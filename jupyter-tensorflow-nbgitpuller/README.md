# jupyter-tensorflow-nbgitpuller

Upstream [Jupyter TensorFlow CUDA notebook](https://quay.io/repository/jupyter/tensorflow-notebook:cuda-2026-09-01)
plus [nbgitpuller](https://github.com/jupyterhub/nbgitpuller), which lets
lecturers distribute course material through a link that clones or updates a git
repository into each student's home directory without overwriting their work.

TensorFlow with CUDA, for the GPU notebook profiles.

## Pinned versions

| Component | Version |
| --- | --- |
| Base image | `quay.io/jupyter/tensorflow-notebook:cuda-2026-09-01` |
| Base digest | `sha256:4eec486ebade2506351ecbf78bc0ef6992ebde61bfb21cd26e2eac2934468cf3` |
| nbgitpuller | `1.3.0` |

Bumping the base image or nbgitpuller means updating the `FROM`/`ARG` in the
`Dockerfile`, this table, and `VERSION`. A nbgitpuller bump takes the new
nbgitpuller version; a base-image-only bump takes a revision suffix, e.g.
`1.3.0-2`.

## Why the GPU flavours need nbgitpuller too

It is tempting to add nbgitpuller only to the CPU image, on the grounds that
nbgitpuller writes into the user's home directory and that volume is mounted by
every JupyterHub profile.

That reasoning is wrong. `/hub/user-redirect/git-pull` redirects to
`/user/<name>/git-pull`, meaning whichever server the user currently has
running. There is no profile selection in the link. A student sitting on a GPU
profile who clicks a course link would get a 404 from a server with no
`git-pull` endpoint. Every profile a student can be on therefore needs the
extension.

## Size

The base is roughly 4.53 GiB compressed, so this is not a small image. The
added layer is only the nbgitpuller wheel. Because layers are content-addressed,
a node that already holds the upstream base does not re-download it when pulling
this image, it only fetches the new layer.

## Platforms

`linux/amd64` only. CUDA images target amd64 hardware, and the base is large
enough that building an unused arm64 variant is not worth the registry space.
