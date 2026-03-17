# Developer Guide

This document covers everything needed to build, modify, test, and publish the `river-slurm` Docker image locally.

## Prerequisites

- Docker (with BuildKit support)
- `make`
- [`act`](https://github.com/nektos/act) — for running GitHub Actions workflows locally
- SSH client

## Repository structure

```
.
├── Makefile
├── README.md
├── Readme.developer.md       # this file
├── .github/
│   └── workflows/
│       └── test_and_publish.yml
└── slurm/
    ├── Dockerfile
    ├── run.sh                # container entrypoint
    ├── slurm.conf.template   # SLURM config (<<CPUS>> and <<MEMORY>> are substituted at runtime)
    ├── slurmdbd.conf         # SLURM accounting daemon config
    ├── my.cnf                # MariaDB config
    └── .ssh/
        └── id_rsa.pub        # public key copied into the container for SSH access
```

## Local development workflow

### 1. Build the image

```bash
make dev
```

Runs `docker build slurm -t nttg8100/river-slurm:<VERSION>`.

### 2. Start the container

```bash
make start
```

Runs the container with `--privileged` (required so `sysctl kernel.unprivileged_userns_clone=1` can be set at startup for Singularity). The container is named `slurm-dev` and SSH is exposed on port `8081`.

### 3. SSH into the container

```bash
ssh river@localhost -p 8081
```

Default password: `password`. Alternatively use the key from `slurm/.ssh/id_rsa`.

### 4. Run the smoke test

With the container running (`make start`), run:

```bash
make test
```

This executes `singularity run library://sylabsed/examples/lolcow` as user `river` inside the container. A successful run confirms Singularity, user namespaces, and network access are all working.

### 5. Stop and clean up

```bash
docker stop slurm-dev
```

## Configuration

### SLURM node resources

CPU count and memory are injected at container startup via `run.sh` using `slurm.conf.template`. The defaults are:

| Parameter | Default |
|---|---|
| CPUs | `2` |
| Memory (MB) | `2048` |

Override at runtime:

```bash
docker run --rm --name slurm-dev -p 8081:22 --privileged -d nttg8100/river-slurm:<VERSION> /opt/run.sh 4 4096
```

### SSH key

The container copies `slurm/.ssh/id_rsa.pub` into `river`'s `authorized_keys` at build time. To use your own key:

```bash
cp ~/.ssh/id_rsa.pub slurm/.ssh/id_rsa.pub
make dev
```

## Modifying the Dockerfile

Key sections to be aware of:

- **System packages** — installed in the first `RUN apt-get` block
- **User `river`** — created with sudo access; SSH key injected from `slurm/.ssh/id_rsa.pub`
- **Singularity** — installed via [`pixi`](https://pixi.sh) as user `river` into `~/.pixi/bin/`
- **SLURM/munge directories** — set up with correct ownership in the second `RUN` block
- **Entrypoint** — `run.sh` handles service startup and `sysctl` for user namespaces

> Do not use `sysctl` in a `RUN` layer — it has no effect at build time. Use `run.sh` instead.

## Versioning

The image version is defined at the top of `Makefile`:

```makefile
VERSION := 1.1.0
```

Update this before publishing a new release. The CI workflow reads this value automatically.

## Testing the CI workflow locally with `act`

[`act`](https://github.com/nektos/act) runs GitHub Actions workflows locally using Docker.

**Simulate a pull request (build + test only):**
```bash
act pull_request
```

**Simulate a push to main (build + test + publish):**
```bash
act push -s DOCKERHUB_USERNAME=nttg8100 -s DOCKERHUB_TOKEN=<your_token>
```

**Run only the build-and-test job:**
```bash
act pull_request -j build-and-test
```

If prompted to choose a runner image, select `Medium` or pass explicitly:
```bash
act pull_request -P ubuntu-latest=catthehacker/ubuntu:act-latest
```

## Publishing

```bash
make publish
```

This builds the image and pushes it to Docker Hub as `nttg8100/river-slurm:<VERSION>`. You must be logged in:

```bash
docker login
```

In CI, publishing is handled automatically on push to `main` using the `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` repository secrets.
