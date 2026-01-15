"""
Terminal-Bench Agent Template
=============================

This is a template for creating your own AI coding agent for Terminal-Bench 2.0.
Replace the placeholder code with your actual agent implementation.

QUICK START:
1. Rename 'MyAgent' to your agent's name (e.g., 'ClaudeAgent', 'GPTAgent')
2. Update HOST_CONFIG_DIR to point to your agent's auth directory
3. Implement the setup() method to install your agent in the container
4. Implement create_run_agent_commands() to execute tasks

For detailed documentation, see README.md
"""

import os
import base64
from pathlib import Path
from harbor.agents.installed.base import BaseInstalledAgent, ExecInput
from harbor.environments.base import BaseEnvironment
from harbor.models.agent.context import AgentContext


class MyAgent(BaseInstalledAgent):
    """
    Template agent for Terminal-Bench 2.0.

    This class handles the lifecycle of running your AI agent in Docker:
    1. Setup: Install dependencies and configure authentication
    2. Execute: Run your agent with the task instruction
    3. Cleanup: Collect output and metadata

    CUSTOMIZATION POINTS:
    - HOST_CONFIG_DIR: Where your agent stores its local config (API keys, etc.)
    - _install_agent_template_path: Path to your installation script template
    - setup(): Custom initialization logic
    - create_run_agent_commands(): How to invoke your agent with a task
    """

    # =========================================================================
    # CONFIGURATION - Customize these for your agent
    # =========================================================================

    # Path to your agent's local configuration directory
    # This directory will be uploaded to the container at /root/.my_agent/
    # Common examples:
    #   - ~/.claude/          (Claude Code)
    #   - ~/.config/openai/   (OpenAI tools)
    #   - ~/.aider/           (Aider)
    #   - ~/.cursor/          (Cursor)
    HOST_CONFIG_DIR = Path.home() / ".my_agent"

    # Where to upload the config inside the container
    CONTAINER_CONFIG_DIR = "/root/.my_agent"

    # =========================================================================
    # REQUIRED METHODS - Implement these for your agent
    # =========================================================================

    def __init__(self, logs_dir: Path, *args, **kwargs):
        """
        Initialize the agent with a logs directory.

        Args:
            logs_dir: Directory where Harbor will store execution logs
        """
        super().__init__(logs_dir, *args, **kwargs)
        # Add any custom initialization here
        self._agent_path = None  # Will be set during setup

    @classmethod
    def name(cls) -> str:
        """
        Return your agent's name (used in logs and reporting).

        Example: "claude-code", "gpt-4-agent", "aider"
        """
        return "my-agent"

    def version(self) -> str:
        """
        Return your agent's version string.

        Tip: You can read this from package metadata if your agent
        is installed as a Python package.
        """
        return "1.0.0"

    @property
    def _install_agent_template_path(self) -> Path:
        """
        Path to the Jinja2 template for installing your agent in the container.

        The template (install.sh.j2) should:
        - Install system dependencies (apt-get)
        - Install your agent CLI (npm, pip, etc.)
        - Set up any required environment

        See templates/install.sh.j2 for an example.
        """
        return Path(__file__).parent / "templates" / "install.sh.j2"

    @property
    def _template_variables(self) -> dict[str, str]:
        """
        Variables to pass to your install.sh.j2 template.

        Example:
            return {
                "node_version": "20",
                "agent_package": "my-agent-cli",
            }

        These can be used in the template as {{ node_version }}, {{ agent_package }}, etc.
        """
        return {}

    # =========================================================================
    # SETUP PHASE - Called once when container starts
    # =========================================================================

    async def setup(self, environment: BaseEnvironment) -> None:
        """
        Initialize the container for your agent.

        This method is called once when the Docker container starts.
        Use it to:
        1. Check if your agent is already installed (for prebuilt images)
        2. Run the installation script if needed
        3. Upload authentication files (API keys, OAuth tokens)
        4. Verify the installation worked

        Args:
            environment: Harbor's interface to the Docker container
                        - environment.exec(command): Run a shell command
                        - environment.upload_dir(source, target): Upload a directory
                        - environment.upload_file(source, target): Upload a file

        TIPS:
        - Check for existing installation to skip slow reinstalls
        - Always verify uploads succeeded before continuing
        - Print diagnostic info to help debug failures
        """

        # ---------------------------------------------------------------------
        # Step 1: Check if agent is already installed (for prebuilt images)
        # ---------------------------------------------------------------------
        # This optimization skips installation if using a prebuilt Docker image
        # that already has your agent installed.

        check_result = await environment.exec(command="which my-agent || echo 'NOT_FOUND'")
        stdout = check_result.stdout.strip()

        agent_exists = stdout.startswith("/") and "NOT_FOUND" not in stdout

        if agent_exists:
            self._agent_path = stdout
            print(f"Agent already installed at: {self._agent_path}")
        else:
            # Run the installation script from the template
            print("Installing agent...")
            await super().setup(environment)

            # Find where the agent was installed
            # Try common installation paths
            possible_paths = [
                "/usr/bin/my-agent",
                "/usr/local/bin/my-agent",
                "/root/.local/bin/my-agent",
            ]

            for path in possible_paths:
                check = await environment.exec(command=f"test -x {path} && echo 'EXISTS'")
                if "EXISTS" in check.stdout:
                    self._agent_path = path
                    print(f"Agent found at: {self._agent_path}")
                    break
            else:
                # Fallback: use 'which' to find it
                result = await environment.exec(command="which my-agent || echo 'NOT_FOUND'")
                if result.stdout.strip().startswith("/"):
                    self._agent_path = result.stdout.strip()
                else:
                    print("WARNING: Could not find agent binary, using default path")
                    self._agent_path = "/usr/local/bin/my-agent"

        # ---------------------------------------------------------------------
        # Step 2: Upload authentication/configuration files
        # ---------------------------------------------------------------------
        # Most agents need API keys, OAuth tokens, or other credentials.
        # Upload your local config directory to the container.

        if self.HOST_CONFIG_DIR.exists():
            print(f"Uploading config from {self.HOST_CONFIG_DIR}")

            await environment.upload_dir(
                source_dir=self.HOST_CONFIG_DIR,
                target_dir=self.CONTAINER_CONFIG_DIR,
            )

            # Verify the upload
            result = await environment.exec(command=f"ls -la {self.CONTAINER_CONFIG_DIR}/")
            print(f"Config directory contents:\n{result.stdout}")
        else:
            print(f"WARNING: No config found at {self.HOST_CONFIG_DIR}")
            print("Your agent may fail without proper authentication!")
            print("")
            print("To fix this, either:")
            print("  1. Run your agent locally first to create config files")
            print("  2. Manually create the config directory with required files")
            print(f"  3. Update HOST_CONFIG_DIR in this file to the correct path")

        # ---------------------------------------------------------------------
        # Step 3: Verify installation (optional but recommended)
        # ---------------------------------------------------------------------
        # Run a quick test to make sure everything is working

        verify = await environment.exec(command=f"{self._agent_path} --version 2>/dev/null || echo 'VERSION_CHECK_FAILED'")
        print(f"Agent version check: {verify.stdout.strip()}")

    # =========================================================================
    # EXECUTION PHASE - Called for each task
    # =========================================================================

    def create_run_agent_commands(self, instruction: str) -> list[ExecInput]:
        """
        Create the command(s) to run your agent with the given task.

        This method is called for each Terminal-Bench task. You receive the
        task instruction as a string and must return a list of commands
        to execute in the container.

        Args:
            instruction: The task description/instruction from Terminal-Bench
                        Example: "Create a git repository and make an initial commit"

        Returns:
            List of ExecInput objects, each representing a command to run.
            Most agents only need one command.

        TIPS:
        - Encode the instruction in base64 to avoid shell escaping issues
        - Use 'expect' for agents that need a PTY (pseudo-terminal)
        - Set appropriate timeouts (most tasks should complete in 10-15 minutes)
        - The working directory is /app by default

        COMMON PATTERNS:

        1. Simple CLI invocation:
           return [ExecInput(command=f"my-agent '{instruction}'", timeout_sec=900)]

        2. Base64 encoding (recommended for complex instructions):
           encoded = base64.b64encode(instruction.encode()).decode()
           cmd = f"echo '{encoded}' | base64 -d | my-agent"
           return [ExecInput(command=cmd, timeout_sec=900)]

        3. Using expect for interactive agents (see example below)
        """

        # Encode instruction as base64 to avoid shell escaping issues
        # This handles quotes, special characters, and multi-line instructions
        instruction_b64 = base64.b64encode(instruction.encode()).decode()

        # Get the agent path (set during setup)
        agent_path = getattr(self, '_agent_path', '/usr/local/bin/my-agent')

        # ---------------------------------------------------------------------
        # Option A: Simple command execution
        # ---------------------------------------------------------------------
        # Use this if your agent doesn't need interactive input

        # simple_command = f'''
        # INSTRUCTION=$(echo "{instruction_b64}" | base64 -d)
        # cd /app
        # {agent_path} --auto "$INSTRUCTION"
        # '''

        # ---------------------------------------------------------------------
        # Option B: Using expect for interactive agents (RECOMMENDED)
        # ---------------------------------------------------------------------
        # Many AI agents have interactive prompts. Use 'expect' to:
        # - Provide a pseudo-terminal (PTY)
        # - Auto-accept confirmation prompts
        # - Detect task completion
        # - Handle timeouts gracefully

        script_content = f'''#!/bin/bash
# Decode the task instruction
INSTRUCTION=$(echo "{instruction_b64}" | base64 -d)
echo "=== Task Instruction ==="
echo "$INSTRUCTION"
echo "========================"

cd /app

# Use expect to handle interactive prompts
cat > /tmp/run-agent.exp << 'EXPECT_EOF'
#!/usr/bin/expect -f

# Set timeout (25 minutes - adjust as needed)
set timeout 1500
log_user 1

# Get arguments passed to this script
set agent_bin [lindex $argv 0]
set instruction [lindex $argv 1]

# Track completion
set task_done 0

# Start the agent
spawn $agent_bin "$instruction"

# Main interaction loop
expect {{
    # Auto-accept "yes/no" prompts
    -re "\\[Y/n\\]|\\[y/N\\]|\\(yes/no\\)" {{
        send "y\\r"
        exp_continue
    }}

    # Auto-accept numbered choice prompts (select first option)
    -re "1\\. Yes|1\\. Continue|1\\. Accept" {{
        sleep 0.3
        send "\\r"
        exp_continue
    }}

    # Detect completion messages
    -re "Done|Completed|Finished|Success" {{
        set task_done 1
        sleep 2
        send "\\x03"
        exp_continue
    }}

    # Handle end of output
    eof {{
        catch wait result
        set exit_code [lindex $result 3]
        if {{$task_done}} {{
            exit 0
        }}
        exit $exit_code
    }}

    # Handle timeout
    timeout {{
        puts "\\n=== Timeout ==="
        if {{$task_done}} {{
            exit 0
        }}
        exit 124
    }}
}}
EXPECT_EOF

chmod +x /tmp/run-agent.exp

# Run the expect script
/tmp/run-agent.exp "{agent_path}" "$INSTRUCTION" 2>&1
EXIT_CODE=$?

echo "=== Agent exited with code: $EXIT_CODE ==="
exit $EXIT_CODE
'''

        # Encode the entire script as base64 to avoid escaping issues
        script_b64 = base64.b64encode(script_content.encode()).decode()

        return [
            ExecInput(
                command=f"echo '{script_b64}' | base64 -d > /tmp/run-agent.sh && chmod +x /tmp/run-agent.sh && /tmp/run-agent.sh",
                cwd="/",
                timeout_sec=1500,  # 25 minutes - adjust based on your agent
            ),
        ]

    # =========================================================================
    # POST-EXECUTION - Called after task completes
    # =========================================================================

    def populate_context_post_run(self, context: AgentContext) -> None:
        """
        Collect metadata after the task completes.

        This method is called after your agent finishes running. Use it to
        extract any useful metadata from the execution (output length,
        token counts, etc.).

        Args:
            context: The agent context object to populate with metadata

        The execution output is saved to:
            self.logs_dir / "command-0" / "stdout.txt"
        """
        # Initialize metadata if needed
        if context.metadata is None:
            context.metadata = {}

        # Read the output file
        output_file = self.logs_dir / "command-0" / "stdout.txt"

        if output_file.exists():
            output = output_file.read_text()
            context.metadata["output_length"] = len(output)

            # Add any other metadata you want to track
            # Examples:
            # context.metadata["lines"] = output.count("\n")
            # context.metadata["has_error"] = "error" in output.lower()
        else:
            context.metadata["output_length"] = 0


# =============================================================================
# TIPS FOR SPECIFIC AGENT TYPES
# =============================================================================
#
# CLAUDE CODE / ANTHROPIC AGENTS:
#   - Config directory: ~/.claude/ or ~/.anthropic/
#   - Uses OAuth tokens in models.json
#   - Needs PTY emulation (use expect)
#   - Add --trust flag for autonomous mode
#
# OPENAI-BASED AGENTS:
#   - Config directory: ~/.config/openai/ or uses OPENAI_API_KEY env var
#   - Can pass API key via environment variable in setup()
#   - May need to handle rate limits with retries
#
# AIDER:
#   - Config directory: ~/.aider/
#   - Uses .env file or environment variables for API keys
#   - Supports multiple model providers
#   - Use --yes flag to auto-confirm prompts
#
# CURSOR / IDE AGENTS:
#   - May require more complex setup (VS Code extensions, etc.)
#   - Consider headless operation mode if available
#
# =============================================================================
