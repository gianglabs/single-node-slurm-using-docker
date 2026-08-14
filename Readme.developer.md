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
    ├── slurm.conf.template   # SLURM config (<<CPUS>>, <<MEMORY>> and port placeholders are substituted at runtime)
    ├── slurmdbd.conf.template   # SLURM accounting daemon config template
    ├── my.cnf.template       # MariaDB config template
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

**Full mode (with accounting + sshd):**
```bash
make start
```

**Minimal mode (no accounting, no sshd):**
```bash
make start-minimal
```

Runs the container with `--privileged` (required so `sysctl kernel.unprivileged_userns_clone=1` can be set at startup for Singularity). The container is named `slurm-dev`.

### 3. SSH into the container

```bash
ssh river@localhost -p 2222
```

Default password: `password`. Alternatively use the key from `slurm/.ssh/id_rsa`.

> Not available in minimal mode (`ENABLE_SSHD=false`).

### 4. Run the smoke test

With the container running, run:

**Full mode — verifies accounting (sacct):**
```bash
make test
```

Submits a batch job, waits for completion, then runs `sacct -j <jobid>` to verify slurmdbd recorded the job.

**Minimal mode — verifies no slurmdbd/sshd:**
```bash
make test-minimal
```

Submits a batch job, verifies it completes, and asserts that `slurmdbd` and `sshd` processes are not running.

### 5. Stop and clean up

```bash
docker stop slurm-dev
```

## Configuration

### SLURM node resources

CPU count, memory, and port offset are injected at container startup via `run.sh` using the
`*.template` configs. The defaults are:

| Parameter | Default |
|---|---|
| CPUs | `2` |
| Memory (MB) | `2048` |
| Offset | `0` |

Override at runtime:

```bash
docker run --rm --name slurm-dev --network host --privileged -d nttg8100/river-slurm:<VERSION> /opt/run.sh 4 4096
```

Run a second concurrent instance with a port offset (see the offset port table in `README.md`):

```bash
docker run --rm --name slurm-dev-2 --network host --privileged -d nttg8100/river-slurm:<VERSION> /opt/run.sh 2 2048 100
```

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `ENABLE_ACCOUNTING` | `true` | Enable MariaDB + slurmdbd job accounting |
| `ENABLE_SSHD` | `true` | Enable sshd for SSH access |

Example — minimal mode without accounting or sshd:
```bash
docker run --rm --name slurm-dev --network host --privileged \
  -e ENABLE_ACCOUNTING=false -e ENABLE_SSHD=false \
  -d nttg8100/river-slurm:<VERSION>
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
VERSION := 1.5.0
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

**Run only the minimal test job:**
```bash
act pull_request -j build-and-test-minimal
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
