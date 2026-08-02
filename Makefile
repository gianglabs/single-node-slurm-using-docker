VERSION :=1.3.0
DOCKERFILE := ./slurm/Dockerfile
IMAGE := nttg8100/river-slurm:$(VERSION)

.phony: dev publish
dev: $(DOCKERFILE)
	docker build slurm -t ${IMAGE}

publish: dev
	docker push $(IMAGE)

start: dev
	docker run --rm --name slurm-dev --network host --privileged -d ${IMAGE}

test:
	docker exec -u river -w /home/river slurm-dev sbatch --wrap="echo Hello"

# this one only run on local with approriate permission, Github Actions limit permission
test-singularity:
	docker exec -u river -w /home/river slurm-dev /home/river/.pixi/bin/singularity run library://sylabsed/examples/lolcow