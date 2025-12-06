.PHONY: init deps build run

init:
	git submodule --quiet update --init --recursive --force
	find ./libs -maxdepth 1 -type d -name "comfyui-*" -exec sh -c 'ln -sf "$$(realpath {})" "libs/comfyui/custom_nodes/$$(basename {})"' \;

deps:
	uv run --with "packaging~=25.0" --with "tomlkit~=0.13" -- scripts/combine_requirements.py libs/*

build:
	docker buildx build --build-arg CUDA_VERSION=13.0.2 -t comfyui-worker .

run:
	docker run --gpus all -it -p 8080:8080 comfyui-worker