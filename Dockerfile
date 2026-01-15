# =============================================================================
# Terminal-Bench Agent Docker Image (OPTIONAL)
# =============================================================================
#
# This Dockerfile creates a pre-built image with your agent installed.
# Using a pre-built image is OPTIONAL but can speed up benchmark runs
# by skipping the installation step for each task.
#
# WHEN TO USE:
# - Debugging: Run the image interactively to test your agent
# - Speed: Skip installation overhead when running many tasks
# - Consistency: Ensure all tasks use the exact same environment
#
# WHEN NOT NEEDED:
# - Harbor creates fresh containers for each task by default
# - The install.sh.j2 template handles installation automatically
#
# BUILD:
#   ./build-image.sh
#
# TEST INTERACTIVELY:
#   docker run -it my-agent-image bash
#
# =============================================================================

FROM ubuntu:24.04

# Labels for identification
LABEL maintainer="your-email@example.com"
LABEL description="Terminal-Bench agent environment"

# -----------------------------------------------------------------------------
# Install system dependencies in a single layer
# Modify this section based on your agent's requirements
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    # Essential tools
    curl \
    ca-certificates \
    gnupg \
    git \
    # PTY emulation for interactive agents
    expect \
    # Add other system packages your agent needs:
    # build-essential \
    # python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Install runtime environment (CUSTOMIZE)
# Uncomment the section that matches your agent
# -----------------------------------------------------------------------------

# === Node.js 20.x (for npm-based agents) ===
# RUN mkdir -p /etc/apt/keyrings \
#     && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
#     && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
#     && apt-get update \
#     && apt-get install -y nodejs \
#     && rm -rf /var/lib/apt/lists/*

# === Python 3.12 (for pip-based agents) ===
# RUN apt-get update && apt-get install -y \
#     python3.12 \
#     python3-pip \
#     python3-venv \
#     && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Install your agent CLI (CUSTOMIZE)
# -----------------------------------------------------------------------------

# === npm-based installation ===
# RUN npm install -g my-agent-cli

# === pip-based installation ===
# RUN pip3 install my-agent-cli

# === Binary download ===
# RUN curl -L https://example.com/my-agent-linux-amd64 -o /usr/local/bin/my-agent \
#     && chmod +x /usr/local/bin/my-agent

# -----------------------------------------------------------------------------
# Setup working directory
# -----------------------------------------------------------------------------

# Create directories
RUN mkdir -p /app /root/.my_agent /installed-agent

# Set working directory (tasks run here)
WORKDIR /app

# -----------------------------------------------------------------------------
# Default command (for interactive testing)
# -----------------------------------------------------------------------------
CMD ["/bin/bash"]
