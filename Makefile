.PHONY: init

init:
	git submodule --quiet update --init --recursive --force
	find ./libs -maxdepth 1 -type d -name "comfyui-*" -exec sh -c 'ln -sf "$$(realpath {})" "libs/comfyui/custom_nodes/$$(basename {})"' \;