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

### Basic Run

Run the container with GPU access:

```bash
docker run --gpus all -p 8080:8080 comfyui-worker
```

### Run in Detached Mode

Run the container in the background:

```bash
docker run -d --gpus all -p 8080:8080 --name comfyui-worker comfyui-worker
```

### Run with Volume Mounts

Mount directories for models and outputs:

```bash
docker run --gpus all -p 8080:8080 \
  -v $(pwd)/models:/app/libs/comfyui/models \
  -v $(pwd)/output:/app/libs/comfyui/output \
  comfyui-worker
```

### Access the Application

Once running, access ComfyUI at:
- http://localhost:8080

### Stop the Container

```bash
docker stop comfyui-worker
```

### View Logs

```bash
docker logs -f comfyui-worker
```

## Requirements

- Docker with BuildKit support
- NVIDIA Docker runtime (for GPU access)
- NVIDIA GPU with CUDA support