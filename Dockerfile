# Stage 1: Build environment with dependencies
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS builder

# Set non-interactive frontend for package installation
ENV OPENCV_PYTHON_HEADLESS=1

# Install system dependencies and Python 3.12
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    software-properties-common \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-venv \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Create and activate a virtual environment with Python 3.12
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip
RUN pip install --upgrade pip

# Install PyTorch with CUDA
RUN pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu128

# Set up the application directory
WORKDIR /app

# Clone the main ComfyUI repository
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git .

# Install headless opencv before other requirements to avoid interactive prompts
RUN pip install opencv-python-headless

# Install ComfyUI's Python dependencies
RUN pip install -r requirements.txt

# --- Custom Nodes Installation ---
# This section clones all custom nodes and installs their dependencies.

# Define a shell function for cloning and installing nodes to keep the Dockerfile DRY.
RUN \
    clone_and_install() { \
        repo_url=$1; \
        dir_name=$2; \
        target_dir="/app/custom_nodes/$dir_name"; \
        git clone --depth=1 "$repo_url" "$target_dir"; \
        if [ -f "$target_dir/pyproject.toml" ]; then \
            echo "Installing requirements for $dir_name"; \
            pip install -e "$target_dir"; \
        fi; \
    }; \
    clone_and_install https://github.com/ltdrdata/ComfyUI-Manager.git ComfyUI-Manager && \
    clone_and_install https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git ComfyUI-VideoHelperSuite && \
    clone_and_install https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git ComfyUI-Frame-Interpolation && \
    clone_and_install https://github.com/kijai/ComfyUI-KJNodes.git ComfyUI-KJNodes && \
    clone_and_install https://github.com/jags111/efficiency-nodes-comfyui.git efficiency-nodes-comfyui && \
    clone_and_install https://github.com/evanspearman/ComfyMath.git ComfyMath && \
    clone_and_install https://github.com/crystian/comfyui-crystools.git comfyui-crystools && \
    clone_and_install https://github.com/rgthree/rgthree-comfy.git rgthree-comfy && \
    clone_and_install https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git ComfyUI-Inspire-Pack && \
    clone_and_install https://github.com/ltdrdata/ComfyUI-Impact-Pack.git ComfyUI-Impact-Pack && \
    clone_and_install https://github.com/city96/ComfyUI-GGUF.git ComfyUI-GGUF && \
    clone_and_install https://github.com/kijai/ComfyUI-WanVideoWrapper.git ComfyUI-WanVideoWrapper && \
    clone_and_install https://github.com/pollockjj/ComfyUI-MultiGPU.git ComfyUI-MultiGPU && \
    clone_and_install https://github.com/Flow-two/ComfyUI-WanStartEndFramesNative.git ComfyUI-WanStartEndFramesNative && \
    clone_and_install https://github.com/orssorbit/ComfyUI-wanBlockswap.git ComfyUI-wanBlockswap && \
    clone_and_install https://github.com/yolain/ComfyUI-Easy-Use.git ComfyUI-Easy-Use && \
    clone_and_install https://github.com/WASasquatch/was-node-suite-comfyui.git ComfyUI-was-node-suite-comfyui && \
    clone_and_install https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git ComfyUI-Custom-Scripts && \
    clone_and_install https://github.com/spacepxl/ComfyUI-Image-Filters.git ComfyUI-Image-Filters && \
    clone_and_install https://github.com/jamesWalker55/comfyui-various.git ComfyUI-various

# --- Model Downloading ---
# Download checkpoint and VAE models.
RUN wget --content-disposition -P /app/models/checkpoints https://huggingface.co/SG161222/Realistic_Vision_V5.1_noVAE/resolve/main/Realistic_Vision_V5.1.safetensors
RUN wget --content-disposition -P /app/models/vae https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors


# Stage 2: Final runtime image
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

# Install Python and other minimal runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy virtual environment and application code from the builder stage
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app .

# Activate the virtual environment for the final image
ENV PATH="/opt/venv/bin:$PATH"

# Expose the port ComfyUI will listen on. Google Cloud Run provides the PORT env var.
EXPOSE 8080

# Start the ComfyUI server
# --listen is required to accept connections from outside the container.
# --port uses the PORT environment variable for compatibility with Cloud Run.
CMD ["python3", "main.py", "--listen", "0.0.0.0", "--port", "8080"]
