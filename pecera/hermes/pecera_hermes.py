"""Harbor agent: Hermes Agent with the pecera harness.

Adds four things on top of Harbor's stock Hermes adapter:
  1. a task prompt that puts a work protocol and a definition of done in front of every task
  2. a SOUL.md and a small Hermes config tuned for unattended terminal work at 64k context
  3. a wall-clock budget per task, read from the task's own time limit, so Hermes gets its
     wrap-up notice before the harness cuts it off
  4. an audit pass: a second, fresh Hermes session that checks the first one's work against
     the task and fixes only what fails

Nothing here is specific to any benchmark task. Use with:
  harbor run --agent-import-path pecera_hermes:PeceraHermes --skills <dir with skill folders> ...
Agent kwargs: audit=true|false, main_fraction=0.72, toolsets=terminal,file,todo,skills,code_execution
"""

import time
import tomllib
from pathlib import Path
from typing import Annotated, Any

import yaml
from pydantic import Field

from harbor.agents.installed.hermes import Hermes, HermesOptions
from harbor.agents.options import Cli

_HERE = Path(__file__).parent
_TASK_MARK = "@@TASK@@"
_MIN_MARK = "@@MINUTES@@"


def _read(name: str) -> str:
    return (_HERE / name).read_text(encoding="utf-8")


def _task_timeout_sec(logs_dir: Path, default: float = 900.0) -> float:
    """Agent time limit of the task this trial belongs to, from Harbor's task cache."""
    try:
        task = Path(logs_dir).parent.name.rsplit("__", 1)[0]
        root = Path.home() / ".cache" / "harbor" / "tasks"
        hits = list(root.glob(f"*/{task}/task.toml")) or [
            p for p in root.glob("*/*/task.toml") if p.parent.name.startswith(task)
        ]
        if hits:
            return float(tomllib.loads(hits[0].read_text(encoding="utf-8"))["agent"]["timeout_sec"])
    except Exception:
        pass
    return default


class PeceraHermesOptions(HermesOptions):
    toolsets: Annotated[str | None, Cli("--toolsets")] = Field(
        default="terminal,file,todo,skills,code_execution",
        description="Comma-separated Hermes toolsets. The default leaves out web, browser, vision and delegation.",
    )
    audit: bool = Field(default=True, description="Run a second, fresh Hermes session that checks and repairs the first one's work.")
    main_fraction: float = Field(default=0.72, description="Share of the task's time limit given to the first session as its run budget.")


class PeceraHermes(Hermes):
    options_model = PeceraHermesOptions
    options: PeceraHermesOptions

    def __init__(self, *args: Any, **kwargs: Any):
        self._budget_sec = 600.0
        super().__init__(*args, **kwargs)
        self._audit = bool(self.options.audit)
        self._main_fraction = float(self.options.main_fraction)

    # Harbor calls this as self._build_config_yaml(...), so an instance method can replace the static one.
    def _build_config_yaml(self, model, max_turns=None, *, connection=None):  # type: ignore[override]
        cfg = yaml.safe_load(Hermes._build_config_yaml(model, max_turns, connection=connection))
        agent = cfg.setdefault("agent", {})
        agent.setdefault("max_turns", 400)
        agent["run_budget_seconds"] = int(self._budget_sec)
        cfg["toolsets"] = ["terminal", "file", "todo", "skills", "code_execution"]
        cfg["terminal"] = {"backend": "local", "timeout": 300}
        cfg["compression"] = {"enabled": True, "threshold": 0.6, "target_ratio": 0.2, "protect_last_n": 20}
        cfg["tool_output"] = {"max_bytes": 20000, "max_lines": 600, "max_line_length": 2000}
        cfg["approvals"] = {"mode": "off"}
        return yaml.dump(cfg, default_flow_style=False)

    # A Hermes install built once into the docker volume "pecera-hermes" (tbench\build-hermes-volume.ps1 and
    # hermes-runtime.ps1) and mounted read-only at the same path in every task container. /opt/pecera-hermes/home holds
    # the program, /opt/pecera-hermes/tmp-hermes a prepared data root that is copied to /tmp/hermes. Setup then takes
    # seconds. The stock install takes 6 to 10 minutes per container.
    PREBUILT_ROOT = "/opt/pecera-hermes"

    def get_version_command(self) -> str | None:  # type: ignore[override]
        # Current Hermes has no "version" subcommand, only the --version flag.
        return 'export PATH="$HOME/.local/bin:$PATH"; HERMES_HOME=/tmp/hermes hermes --version 2>/dev/null | head -1'

    async def install(self, environment) -> None:  # type: ignore[override]
        await self.ensure_system_dependencies(environment, ("curl", "git", "ripgrep", "xz"))
        root = self.PREBUILT_ROOT
        try:
            result = await self.exec_as_agent(
                environment,
                command=(
                    "set -e; "
                    f"test -x {root}/home/.local/bin/hermes; test -d {root}/tmp-hermes; "
                    'mkdir -p "$HOME/.local/bin"; '
                    f'ln -sf {root}/home/.local/bin/hermes "$HOME/.local/bin/hermes"; '
                    f"rm -rf /tmp/hermes; cp -a {root}/tmp-hermes /tmp/hermes; "
                    'export PATH="$HOME/.local/bin:$PATH"; HERMES_HOME=/tmp/hermes hermes --version'
                ),
                timeout_sec=240,
            )
            if getattr(result, "return_code", 0) == 0:
                self.logger.info("pecera: using the prebuilt Hermes install")
                return
        except Exception as e:  # mount missing, or this image cannot run the prebuilt binaries
            self.logger.info(f"pecera: prebuilt Hermes not usable here ({type(e).__name__}), installing normally")
        await self.exec_as_agent(
            environment,
            command=(
                "set -euo pipefail; "
                "curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"
                " | bash -s -- --skip-setup && "
                'export PATH="$HOME/.local/bin:$PATH" && export HERMES_HOME=/tmp/hermes && '
                'mkdir -p "$HERMES_HOME/sessions" "$HERMES_HOME/skills" "$HERMES_HOME/memories" && '
                "(hermes pm repair || true) && hermes --version"
            ),
        )
    async def _write_soul(self, environment) -> None:
        soul = _read("soul.md")
        await self.exec_as_agent(
            environment,
            command=f"mkdir -p /tmp/hermes && cat > /tmp/hermes/SOUL.md << 'PECERA_SOUL_EOF'\n{soul}\nPECERA_SOUL_EOF",
            timeout_sec=15,
        )

    async def run(self, instruction, environment, context) -> None:  # type: ignore[override]
        total = _task_timeout_sec(self.logs_dir)
        start = time.monotonic()
        await self._write_soul(environment)

        self._budget_sec = max(240.0, total * self._main_fraction)
        main = _read("prompt_main.txt").replace(_MIN_MARK, str(int(total // 60))).replace(_TASK_MARK, instruction)
        await super().run(main, environment, context)

        elapsed = time.monotonic() - start
        left = total * 0.93 - elapsed
        if not self._audit or left < 150:
            return
        try:
            await self.exec_as_agent(
                environment,
                command="cp /logs/agent/hermes.txt /logs/agent/hermes-pass1.txt 2>/dev/null || true",
                timeout_sec=10,
            )
        except Exception:
            pass
        self._budget_sec = left
        audit = _read("prompt_audit.txt").replace(_MIN_MARK, str(max(2, int(left // 60)))).replace(_TASK_MARK, instruction)
        await super().run(audit, environment, context)
