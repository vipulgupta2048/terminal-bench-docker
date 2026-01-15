# Terminal-Bench Docker Setup

Run your AI coding agents against [Terminal-Bench 2.0](https://www.tbench.ai/) using Docker.

> **New to this?** Read the full setup guide: [Running Terminal-Bench on Docker](https://mixster.dev/2026/01/15/terminal-bench-docker/)

## Prerequisites

```bash
# Docker Desktop - must be running
docker info

# uv package manager
curl -LsSf https://astral.sh/uv/install.sh | sh

# Harbor CLI
uv tool install harbor
```

**Apple Silicon users:** Add to your shell profile:
```bash
export DOCKER_DEFAULT_PLATFORM=linux/amd64
```

## Quick Start

```bash
git clone https://github.com/vipulgupta2048/terminalbenchdocker.git
cd terminalbenchdocker

# Test with a single task
./run_test.sh -t "git-init"

# Run full benchmark (8 parallel)
./run_test.sh
```

## Repository Structure

```
├── my_agent/
│   ├── __init__.py              # Your agent class (start here)
│   └── templates/
│       └── install.sh.j2        # Container setup script
├── config.yaml                  # Sequential execution
├── config-parallel.yaml         # Parallel execution (8 tasks)
├── run_test.sh                  # Main test runner
└── run_random.sh                # Random task sampler
```

## Implement Your Agent

Edit `my_agent/__init__.py`:

1. Update `HOST_CONFIG_DIR` to your agent's auth directory
2. Implement `setup()` to install dependencies and upload credentials
3. Implement `create_run_agent_commands()` to run your agent

Edit `my_agent/templates/install.sh.j2`:
- Add system packages, runtime (Node.js/Python), and your agent CLI

## Run Options

```bash
./run_test.sh                     # Full suite, 8 parallel
./run_test.sh -t "task-name"      # Single task
./run_test.sh -t "git-*" -n 3     # Pattern match, 3 trials each
./run_test.sh -c 4                # 4 parallel workers
./run_random.sh 5                 # 5 random tasks
```

## Results

Results saved to `./jobs/<timestamp>/`:
- `result.json` - Aggregate scores
- `<task>/agent/command-0/stdout.txt` - Agent output
- `<task>/verifier/reward.txt` - Score (0.0-1.0)

## Common Issues

| Issue | Fix |
|-------|-----|
| `exec format error` | Set `DOCKER_DEFAULT_PLATFORM=linux/amd64` |
| `not a TTY` | Use `expect`/`unbuffer` (see template) |
| `Connection Issue` | Use `network_mode: host` in config |
| Agent auth fails | Check `HOST_CONFIG_DIR` path |

See the [full troubleshooting guide](https://mixster.dev/2026/01/15/terminal-bench-docker/) for details.

## License

MIT License - See [LICENSE](LICENSE)
