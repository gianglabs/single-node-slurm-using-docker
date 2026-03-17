# Single-Node SLURM Using Docker

A single-node SLURM HPC cluster running inside a Docker container, intended for local testing and development of HPC workflows.

## Architecture

All SLURM daemons run on a single container:

- `slurmctld` — cluster controller
- `slurmd` — compute node
- `slurmdbd` — accounting daemon (backed by MariaDB)
- `munge` — authentication
- `sshd` — SSH access on port 22 (mapped to 8081)
- `singularity` — container runtime for HPC jobs (installed via pixi as user `river`)

## Requirements

- Docker
- SSH client
- `make`

## Quickstart

**Build and start:**
```bash
make start
```

This builds the image and runs the container with `--privileged` (required for Singularity user namespaces).

**SSH into the cluster:**
```bash
ssh river@localhost -p 8081
```

Default password: `password`

**Submit a test job:**
```bash
srun --pty bash
```

**Run a Singularity container:**
```bash
singularity run library://sylabsed/examples/lolcow
```

## Makefile targets

| Target | Description |
|---|---|
| `make dev` | Build the Docker image |
| `make start` | Build and run the container |
| `make test` | Run Singularity smoke test inside the running container |
| `make publish` | Build and push the image to Docker Hub |

## Ports

| Port | Service |
|---|---|
| 8081 | SSH (mapped from container port 22) |
| 6817 | slurmctld |
| 6818 | slurmd |
| 3306 | MariaDB |

## CI/CD

The GitHub Actions workflow (`.github/workflows/test_and_publish.yml`) runs automatically:

- **On pull request to `main`**: builds the image and runs the Singularity smoke test
- **On push to `main`**: builds, tests, then publishes to Docker Hub as `nttg8100/river-slurm:<version>`

The version is read from `VERSION` in the `Makefile`.

Required repository secrets:

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
