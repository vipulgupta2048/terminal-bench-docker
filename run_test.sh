#!/bin/bash
# =============================================================================
# Terminal-Bench 2.0 Test Runner
# =============================================================================
#
# Run your agent against the Terminal-Bench benchmark suite.
#
# USAGE:
#   ./run_test.sh                              # Run full suite (8 parallel)
#   ./run_test.sh -t "task-name"               # Run specific task
#   ./run_test.sh -t "task-name" -n 3          # Run task with 3 trials
#   ./run_test.sh -c 4                         # Run full suite with 4 parallel
#
# OPTIONS:
#   -t, --task         Task name or pattern (default: all tasks)
#   -n, --trials       Number of trials per task (default: 1)
#   -c, --concurrency  Number of parallel tasks (default: 8)
#   -m, --multiplier   Timeout multiplier (default: 15)
#   -h, --help         Show this help message
#
# EXAMPLES:
#   ./run_test.sh -t "git-init"                # Test a simple task first
#   ./run_test.sh -t "docker-*"                # Run all docker-related tasks
#   ./run_test.sh -t "sql-*" -n 5              # Run SQL tasks 5 times each
#
# TIPS:
#   - Start with a single easy task to verify your setup works
#   - Check ./jobs/ for detailed logs if tasks fail
#   - Adjust -c based on your machine's RAM (each container uses ~2-4GB)
#
# =============================================================================

set -e

# Ensure Docker is in PATH (macOS)
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"

# Add agent to Python path
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"

# Default configuration
TASK_NAME=""
NUM_TRIALS=1
CONCURRENCY=8
TIMEOUT_MULTIPLIER=15

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--task)
            TASK_NAME="$2"
            shift 2
            ;;
        -n|--trials)
            NUM_TRIALS="$2"
            shift 2
            ;;
        -c|--concurrency)
            CONCURRENCY="$2"
            shift 2
            ;;
        -m|--multiplier)
            TIMEOUT_MULTIPLIER="$2"
            shift 2
            ;;
        -h|--help)
            # Print header comments as help
            head -35 "$0" | tail -33
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            Terminal-Bench 2.0 - Test Runner                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Task:        ${TASK_NAME:-"Full Suite (all tasks)"}"
echo "  Trials:      $NUM_TRIALS"
echo "  Concurrency: $CONCURRENCY"
echo "  Timeout:     ${TIMEOUT_MULTIPLIER}x"
echo ""

# -----------------------------------------------------------------------------
# Pre-flight Checks
# -----------------------------------------------------------------------------

echo "Running pre-flight checks..."
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker not found!"
    echo ""
    echo "Please install Docker Desktop:"
    echo "  - macOS: brew install --cask docker"
    echo "  - Or download from https://www.docker.com/products/docker-desktop"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "ERROR: Docker daemon not running!"
    echo ""
    echo "Please start Docker Desktop and wait for it to be ready."
    echo "On macOS: open -a Docker"
    exit 1
fi
echo "  [OK] Docker is running"

# Check Harbor
if ! command -v harbor &> /dev/null; then
    echo "ERROR: Harbor not found!"
    echo ""
    echo "Install Harbor with:"
    echo "  uv tool install harbor"
    echo ""
    echo "If you don't have uv, install it first:"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi
echo "  [OK] Harbor is installed"

# Check agent module can be imported
if ! python3 -c "import my_agent" 2>/dev/null; then
    echo "WARNING: Cannot import 'my_agent' module"
    echo "Make sure PYTHONPATH includes this directory"
    echo ""
fi
echo "  [OK] Python path configured"

# -----------------------------------------------------------------------------
# TIP: Check for agent authentication
# -----------------------------------------------------------------------------
# Uncomment and customize this section for your agent:
#
# CONFIG_DIR="$HOME/.my_agent"
# if [ ! -d "$CONFIG_DIR" ]; then
#     echo "ERROR: Agent not authenticated!"
#     echo ""
#     echo "Please run your agent locally first to set up authentication:"
#     echo "  my-agent login"
#     echo ""
#     echo "Or create the config directory manually:"
#     echo "  mkdir -p $CONFIG_DIR"
#     exit 1
# fi
# echo "  [OK] Agent authentication found"

echo ""
echo "Starting Terminal-Bench run..."
echo ""

# -----------------------------------------------------------------------------
# Build Harbor Command
# -----------------------------------------------------------------------------

# IMPORTANT: Update the agent import path to match your agent class name
# Format: module_name:ClassName
AGENT_IMPORT_PATH="my_agent:MyAgent"

CMD="harbor run -d terminal-bench@2.0 --agent-import-path $AGENT_IMPORT_PATH"
CMD="$CMD -n $NUM_TRIALS --timeout-multiplier $TIMEOUT_MULTIPLIER"
CMD="$CMD --n-concurrent $CONCURRENCY"

# Add task filter if specified
if [ -n "$TASK_NAME" ]; then
    CMD="$CMD -t \"$TASK_NAME\""
fi

# -----------------------------------------------------------------------------
# Run the Benchmark
# -----------------------------------------------------------------------------

eval $CMD

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Run Complete!"
echo ""
echo "Results saved in: ./jobs/"
echo ""
echo "To view results:"
echo "  ls -la jobs/"
echo "  cat jobs/<timestamp>/result.json"
echo ""
echo "To debug a failed task:"
echo "  cat jobs/<timestamp>/<task-name>/agent/command-0/stdout.txt"
echo "════════════════════════════════════════════════════════════════"
