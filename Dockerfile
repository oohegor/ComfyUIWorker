# syntax=docker/dockerfile:1

# Define CUDA version as a build argument with default value
ARG CUDA_VERSION=13.0.2

FROM nvidia/cuda:${CUDA_VERSION}-cudnn-runtime-ubuntu24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    CUDA_VERSION=${CUDA_VERSION}

# Install system dependencies, Python 3.12, and build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    python3 \
    python3-pip \
    python3-venv \
    git \
    wget \
    ca-certificates \
    make \
    && rm -rf /var/lib/apt/lists/*

# Download the latest uv
ADD https://astral.sh/uv/install.sh /uv-installer.sh
RUN sh /uv-installer.sh && rm /uv-installer.sh
ENV PATH="/root/.local/bin/:$PATH"

# Create virtual environment
RUN uv venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Run make init to initialize submodules and create symlinks
RUN make init

# Run make deps to collect all dependency requirements
RUN make deps

# Install the package in editable mode using uv
RUN uv pip install -r requirements.txt

# Expose port
EXPOSE 8080

# Default command - override as needed
CMD ["uv", "run", "--", "libs/comfyui/main.py", "--listen", "0.0.0.0", "--port", "8080"]
