# ComfyUI Worker

Docker-based ComfyUI worker with CUDA support.

## Quick Start

```bash
make build
make run
```

## Make Commands

| Command | Description |
|---------|-------------|
| `make init` | Initialize git submodules and create symlinks |
| `make deps` | Generate requirements.txt from all library dependencies |
| `make build` | Build Docker image (runs deps automatically) |
| `make run` | Run container with GPU access |

## Building the Docker Image

Build the Docker image with the default CUDA version (13.0.2):

```bash
make build
```

### Custom CUDA Version

To build with a different CUDA version, run docker buildx directly:

```bash
docker buildx build --build-arg CUDA_VERSION=12.8.1 -t comfyui-worker .
```

## Running the Container

### Basic Run

Run the container with GPU access:

```bash
make run
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
