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

This builds the image and runs the container with `--network host --privileged` (host networking shares the host's ports, so the container's services are moved to non-conflicting ports; `--privileged` is required for Singularity user namespaces).

**SSH into the cluster:**
```bash
ssh river@localhost -p 2222
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

The container runs with `--network host`, so it shares the host's network namespace. To avoid clashing with services running directly on the host (host Slurm uses 6817-6819, sshd uses 22, MySQL uses 3306), all service ports are moved to non-conflicting ports:

| Port | Service |
|---|---|
| 2222 | SSH (host sshd uses 22) |
| 6917 | slurmctld |
| 6918 | slurmd |
| 6919 | slurmdbd |
| 3307 | MariaDB |

### Running multiple concurrent instances

`run.sh` accepts an optional third argument — a **port offset** added to every service port.
This allows several SLURM containers to run side by side on the shared host network.

| Service | Base port | With offset N |
|---|---|---|
| sshd | 2222 | 2222 + N |
| slurmctld | 6917 | 6917 + N |
| slurmd | 6918 | 6918 + N |
| slurmdbd | 6919 | 6919 + N |
| MariaDB | 3307 | 3307 + N |

(munge needs no offset — it binds a per-container Unix socket, not a host TCP port.)

Override the resources and offset at runtime:

```bash
docker run --rm --name slurm-0 --network host --privileged -d nttg8100/river-slurm:<VERSION>
docker run --rm --name slurm-1 --network host --privileged -d nttg8100/river-slurm:<VERSION> /opt/run.sh 2 2048 100
```

Each instance gets a unique port range (e.g. offset `0` → SSH on 2222, offset `100` → SSH on 2322).

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
