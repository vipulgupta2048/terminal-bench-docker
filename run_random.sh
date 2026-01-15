#!/bin/bash
# =============================================================================
# Terminal-Bench 2.0 Random Task Runner
# =============================================================================
#
# Run your agent on a random subset of Terminal-Bench tasks.
# Useful for quick testing and statistical sampling.
#
# USAGE:
#   ./run_random.sh           # Run 5 random tasks (default)
#   ./run_random.sh 10        # Run 10 random tasks
#   ./run_random.sh 3         # Run 3 random tasks
#
# HOW IT WORKS:
#   1. Selects N random tasks from the known task list
#   2. Runs them in parallel (max 4 concurrent)
#   3. Collects and summarizes results
#
# TIPS:
#   - Great for initial testing before running full suite
#   - Results are saved in ./random_results_<timestamp>/
#   - Each task's full log is saved for debugging
#
# =============================================================================

set -e

# Ensure Docker is in PATH (macOS)
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"

# Number of random tasks to run (default: 5)
COUNT=${1:-5}

# -----------------------------------------------------------------------------
# Known Terminal-Bench Tasks
# -----------------------------------------------------------------------------
# This is a curated list of Terminal-Bench tasks.
# Modify this list based on your testing needs.
#
# Categories:
# - Git operations: git-init, configure-git-webserver
# - Data processing: log-summary-date-ranges, distribution-search
# - Security/CTF: crack-7z-hash, sql-injection, password-recovery
# - ML/AI: gpt2-codegolf, pytorch-model-cli, caffe-cifar-10
# - System: pypi-server, cobol-modernization

KNOWN_TASKS=(
    "log-summary-date-ranges"
    "break-filter-js-from-html"
    "largest-eigenval"
    "merge-diff-arc-agi-task"
    "gpt2-codegolf"
    "adaptive-rejection-sampler"
    "caffe-cifar-10"
    "chess-best-move"
    "cobol-modernization"
    "configure-git-webserver"
    "crack-7z-hash"
    "custom-memory-heap-crash"
    "distribution-search"
    "feal-linear-cryptanalysis"
    "llm-inference-batching-scheduler"
    "path-tracing"
    "password-recovery"
    "pytorch-model-cli"
    "pypi-server"
    "sql-injection"
)

# -----------------------------------------------------------------------------
# Main Function
# -----------------------------------------------------------------------------

run_random_tests() {
    local count=$1

    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║       Terminal-Bench 2.0 - Random Task Runner                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Selecting $count random tasks..."
    echo ""

    # Shuffle and pick random tasks
    # Note: On macOS, you may need: brew install coreutils (for gshuf)
    if command -v shuf &> /dev/null; then
        SELECTED=($(printf '%s\n' "${KNOWN_TASKS[@]}" | shuf | head -n $count))
    elif command -v gshuf &> /dev/null; then
        SELECTED=($(printf '%s\n' "${KNOWN_TASKS[@]}" | gshuf | head -n $count))
    else
        echo "ERROR: 'shuf' or 'gshuf' not found"
        echo "On macOS, install with: brew install coreutils"
        exit 1
    fi

    echo "Selected tasks:"
    for task in "${SELECTED[@]}"; do
        echo "  - $task"
    done
    echo ""

    # Create results directory
    RESULTS_DIR="$SCRIPT_DIR/random_results_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$RESULTS_DIR"
    echo "Results will be saved to: $RESULTS_DIR"
    echo ""

    # Track parallel processes
    MAX_PARALLEL=4
    pids=()
    running=0

    echo "Starting $count tasks in parallel (max $MAX_PARALLEL concurrent)..."
    echo ""

    for task in "${SELECTED[@]}"; do
        # Wait if we have too many running
        while [ $running -ge $MAX_PARALLEL ]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    unset 'pids[$i]'
                    ((running--))
                fi
            done
            pids=("${pids[@]}")  # Re-index array
            sleep 1
        done

        # Launch task in background
        (
            output=$("$SCRIPT_DIR/run_test.sh" -t "$task" -n 1 2>&1)

            # Extract result from output
            mean=$(echo "$output" | grep -E "│\s*Mean\s*│" | grep -o '[0-9]\.[0-9]*' | head -1)
            errors=$(echo "$output" | grep -E "│\s*Errors\s*│" | grep -o '[0-9]*' | tail -1)

            # Determine status
            if [ "$mean" = "1.000" ] || [ "$mean" = "1.0" ]; then
                echo "PASS" > "$RESULTS_DIR/$task.status"
            elif [ -n "$errors" ] && [ "$errors" -gt 0 ] 2>/dev/null; then
                echo "TIMEOUT" > "$RESULTS_DIR/$task.status"
            elif [ -n "$mean" ]; then
                echo "FAIL:$mean" > "$RESULTS_DIR/$task.status"
            else
                echo "ERROR" > "$RESULTS_DIR/$task.status"
            fi

            # Save full log
            echo "$output" > "$RESULTS_DIR/$task.log"
        ) &

        pid=$!
        pids+=($pid)
        ((running++))
        echo "  Started: $task (PID: $pid)"
        sleep 2  # Stagger launches
    done

    echo ""
    echo "All tasks launched. Waiting for completion..."
    echo "(This may take 10-30 minutes depending on tasks)"
    echo ""

    # Wait for all tasks
    for pid in "${pids[@]}"; do
        wait $pid 2>/dev/null || true
    done

    # -----------------------------------------------------------------------------
    # Display Results
    # -----------------------------------------------------------------------------

    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "                      FINAL RESULTS"
    echo "════════════════════════════════════════════════════════════════"
    echo ""

    passed=0
    failed=0
    timeout=0

    for task in "${SELECTED[@]}"; do
        if [ -f "$RESULTS_DIR/$task.status" ]; then
            status=$(cat "$RESULTS_DIR/$task.status")
            case $status in
                PASS)
                    echo "  PASS     $task"
                    ((passed++))
                    ;;
                TIMEOUT)
                    echo "  TIMEOUT  $task"
                    ((timeout++))
                    ;;
                ERROR)
                    echo "  ERROR    $task (check $RESULTS_DIR/$task.log)"
                    ((failed++))
                    ;;
                FAIL:*)
                    mean=${status#FAIL:}
                    echo "  FAIL     $task (score=$mean)"
                    ((failed++))
                    ;;
            esac
        else
            echo "  ???      $task (no result)"
            ((failed++))
        fi
    done

    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo "Summary: $passed passed, $failed failed, $timeout timed out"
    echo "Pass rate: $(echo "scale=1; $passed * 100 / $count" | bc)%"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    echo "Detailed logs: $RESULTS_DIR/"
    echo "Full task logs: ./jobs/"
}

# Run
run_random_tests "$COUNT"
