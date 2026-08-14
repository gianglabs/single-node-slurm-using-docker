VERSION :=1.5.0
DOCKERFILE := ./slurm/Dockerfile
IMAGE := nttg8100/river-slurm:$(VERSION)
.ONESHELL:

.phony: dev publish
dev: $(DOCKERFILE)
	docker build slurm -t ${IMAGE}

publish: dev
	docker push $(IMAGE)

start: dev
	docker run --rm --name slurm-dev --network host  --privileged -d ${IMAGE}

start-minimal: dev
	docker rm -f slurm-dev 2>/dev/null || true
	docker run --rm --name slurm-dev --network host --privileged -e ENABLE_ACCOUNTING=false -e ENABLE_SSHD=false -d ${IMAGE}

test:
	JOB_OUTPUT=$$(docker exec -u river -w /home/river slurm-dev sbatch --wrap="echo Hello")
	JOB_ID=$$(echo "$$JOB_OUTPUT" | awk '{print $$NF}')
	echo "Submitted job $$JOB_ID, waiting for completion..."
	sleep 10
	docker exec -u river slurm-dev sacct -j $$JOB_ID --format=JobID,State,ExitCode

test-minimal:
	JOB_OUTPUT=$$(docker exec -u river -w /home/river slurm-dev sbatch --wrap="echo Hello")
	JOB_ID=$$(echo "$$JOB_OUTPUT" | awk '{print $$NF}')
	echo "Submitted job $$JOB_ID, waiting for completion..."
	sleep 10
	docker exec slurm-dev squeue -j $$JOB_ID --noheader
	docker exec slurm-dev bash -c "! pgrep -x slurmdbd" && echo "slurmdbd: not running (OK)"
	docker exec slurm-dev bash -c "! pgrep -x sshd" && echo "sshd: not running (OK)"

# this one only run on local with approriate permission, Github Actions limit permission
test-singularity:
	docker exec -u river -w /home/river slurm-dev /home/river/.pixi/bin/singularity run library://sylabsed/examples/lolcow