# Dockerfile for testing portableralph with Claude Code
# Build: docker build -t portableralph .
# Run: docker run -it --env-file .env.docker portableralph
# Container name: ralphcontainer

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    jq \
    git \
    ca-certificates \
    gnupg \
    sudo \
    wget \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (LTS version for Claude CLI compatibility)
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally via npm
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user for security
RUN useradd -m -s /bin/bash -G sudo ralphuser \
    && echo "ralphuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create working directories
RUN mkdir -p /home/ralphuser/portableralph \
    && mkdir -p /home/ralphuser/.config \
    && mkdir -p /home/ralphuser/.ralph \
    && mkdir -p /home/ralphuser/.claude \
    && mkdir -p /home/ralphuser/test-workspace

# Copy repository files
COPY --chown=ralphuser:ralphuser . /home/ralphuser/portableralph/

# Make scripts executable
RUN chmod +x /home/ralphuser/portableralph/*.sh \
    && chmod +x /home/ralphuser/portableralph/lib/*.sh 2>/dev/null || true

# Set up PATH for ralphuser
RUN echo 'export PATH="$HOME/portableralph:$PATH"' >> /home/ralphuser/.bashrc \
    && echo 'export PATH="/usr/local/bin:$PATH"' >> /home/ralphuser/.bashrc

# Switch to non-root user
USER ralphuser

# Set working directory
WORKDIR /home/ralphuser/portableralph

# Set default shell
SHELL ["/bin/bash", "-c"]

# Install portableralph for the user
RUN bash install.sh --local || true

# Default command - interactive bash shell
CMD ["/bin/bash"]
