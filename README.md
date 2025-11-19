# ComfyUI Worker

Docker-based ComfyUI worker with CUDA support.

## Building the Docker Image

Build the Docker image with CUDA 12.8.1:

```bash
docker buildx build --build-arg CUDA_VERSION=12.8.1 -t comfyui-worker .
```

### Custom CUDA Version

To build with a different CUDA version, change the `CUDA_VERSION` argument:

```bash
docker buildx build --build-arg CUDA_VERSION=12.6.0 -t comfyui-worker .
```

### Default Build

The default CUDA version is `12.8.1`, so you can omit the build argument:

```bash
docker buildx build -t comfyui-worker .
```

## Running the Container

```bash
docker run --gpus all -p 8080:8080 comfyui-worker
```

## Requirements

- Docker with BuildKit support
- NVIDIA Docker runtime (for GPU access)