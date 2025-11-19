# syntax=docker/dockerfile:1

# Define CUDA version as a build argument with default value
ARG CUDA_VERSION=12.8.1

# ============================================================================
# Builder Stage - NVIDIA CUDA with cuDNN devel
# ============================================================================
FROM nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubuntu24.04 AS builder

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    CUDA_VERSION=${CUDA_VERSION}

# Install system dependencies, Python 3.12, and build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-dev \
    python3-pip \
    python3.12-venv \
    build-essential \
    git \
    wget \
    ca-certificates \
    make \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Install uv for faster package installation
RUN wget -qO- https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:${PATH}"

# Create virtual environment
RUN uv venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# Run make init to initialize submodules and create symlinks
RUN make init

# Install the package in editable mode using uv
RUN uv pip install -e .


# ============================================================================
# Runner Stage - NVIDIA CUDA with cuDNN runtime
# ============================================================================
ARG CUDA_VERSION=12.8.1
FROM nvidia/cuda:${CUDA_VERSION}-cudnn-runtime-ubuntu24.04 AS runner

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    CUDA_VERSION=${CUDA_VERSION}

# Install runtime dependencies and Python 3.12
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 \
    python3-pip \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Copy application files from builder stage
COPY --from=builder /app /app

# Activate virtual environment
ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONPATH=/app:${PYTHONPATH}

# Expose port
EXPOSE 8080

# Default command - override as needed
CMD ["python3.12", "libs/comfyui/main.py", "--listen", "0.0.0.0", "--port", "8080"]
