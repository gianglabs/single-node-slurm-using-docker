VERSION :=1.1.0
DOCKERFILE := ./slurm/Dockerfile
IMAGE := nttg8100/river-slurm:$(VERSION)

.phony: dev publish
dev: $(DOCKERFILE)
	docker build slurm -t ${IMAGE}

publish: dev
	docker push $(IMAGE)

start: dev
	docker run --rm --name slurm-dev -p 8081:22 --privileged -d ${IMAGE}

test:
	docker exec -u river slurm-dev /home/river/.pixi/bin/singularity run library://sylabsed/examples/lolcow