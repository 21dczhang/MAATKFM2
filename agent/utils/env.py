"""
环境管理工具：
- 虚拟环境自动创建与切换（开发模式 / Linux 下生效）
- 依赖安装（本地 whl 优先，失败后回退到镜像源）
- 读取 interface.json 版本号判断是否为开发模式
"""

import json
import subprocess
import sys
from pathlib import Path

from .logger import logger

# ── 路径常量 ──────────────────────────────────────────────────────
_UTILS_DIR = Path(__file__).parent          # agent/utils/
_AGENT_DIR = _UTILS_DIR.parent             # agent/


def _find_project_dir() -> Path:
    """
    从 agent/ 向上查找包含 requirements.txt 的目录作为项目根。
    支持 agent/ 在项目根下，或在 assets/ 旁边等各种布局。
    最多向上找 3 层，找不到就用 agent/ 的父目录。
    """
    candidate = _AGENT_DIR
    for _ in range(4):
        if (candidate / "requirements.txt").exists():
            return candidate
        candidate = candidate.parent
    return _AGENT_DIR.parent


def _find_interface(project_dir: Path) -> Path:
    """
    按优先级查找 interface.json：
    1. project_dir/assets/interface.json
    2. project_dir/interface.json
    3. agent/ 旁边的 assets/interface.json
    """
    candidates = [
        project_dir / "assets" / "interface.json",
        project_dir / "interface.json",
        _AGENT_DIR.parent / "assets" / "interface.json",
    ]
    for p in candidates:
        if p.exists():
            return p
    return candidates[0]  # 默认，即使不存在


_PROJECT_DIR = _find_project_dir()
_VENV_DIR    = _PROJECT_DIR / ".venv"    # .venv 建在项目根，不污染系统 Python
_DEPS_DIR    = _AGENT_DIR / "deps"       # 打包后本地 whl 目录
_REQ_FILE    = _PROJECT_DIR / "requirements.txt"
_INTERFACE   = _find_interface(_PROJECT_DIR)


# ── 版本读取 ──────────────────────────────────────────────────────

def read_interface_version() -> str:
    """读取 interface.json 中的 version 字段，读取失败返回空字符串。"""
    try:
        with open(_INTERFACE, encoding="utf-8") as f:
            data = json.load(f)
        return data.get("version", "")
    except Exception as e:
        logger.warning(f"读取 interface.json 失败: {e}")
        return ""


# ── 虚拟环境管理 ──────────────────────────────────────────────────

def ensure_venv_and_relaunch_if_needed() -> None:
    """
    确保在 .venv 虚拟环境中运行。
    若当前不在虚拟环境中，则自动创建 .venv 并以子进程重新启动。

    .venv 建在项目根目录（requirements.txt 同级），不污染系统 Python。
    触发条件：Linux 系统 或 interface.json version == "DEBUG"
    """
    # 已经在虚拟环境中，直接返回
    if sys.prefix != sys.base_prefix:
        logger.debug(f"已在虚拟环境中: {sys.prefix}")
        return

    # 创建 .venv（若不存在）
    if not _VENV_DIR.exists():
        logger.info(f"创建虚拟环境: {_VENV_DIR}")
        subprocess.check_call([sys.executable, "-m", "venv", str(_VENV_DIR)])

    # 找到 venv 内的 python
    if sys.platform.startswith("win"):
        venv_python = _VENV_DIR / "Scripts" / "python.exe"
    else:
        venv_python = _VENV_DIR / "bin" / "python3"
        if not venv_python.exists():
            venv_python = _VENV_DIR / "bin" / "python"

    if not venv_python.exists():
        logger.error(f"找不到虚拟环境 Python: {venv_python}")
        sys.exit(1)

    # 用 venv 的 python 重新启动，传递所有原始参数（包括 socket_id）
    logger.info("切换到虚拟环境重新启动...")
    result = subprocess.run([str(venv_python)] + sys.argv)
    sys.exit(result.returncode)


# ── 依赖安装 ──────────────────────────────────────────────────────

def install_requirements() -> bool:
    """
    按优先级安装依赖：
    1. agent/deps/ 目录中的本地 whl（离线优先，打包发布时使用）
    2. 清华镜像源（在线安装）
    3. pip 全局配置（用户自定义源兜底）

    依赖安装到当前 Python 环境（开发模式下即 .venv，不污染系统）。
    """
    if not _REQ_FILE.exists():
        logger.warning(f"找不到 requirements.txt: {_REQ_FILE}")
        return False

    python = sys.executable
    req    = str(_REQ_FILE)

    # 策略 1：本地 whl（打包发布场景）
    if _DEPS_DIR.exists() and any(_DEPS_DIR.glob("*.whl")):
        logger.info("使用本地 whl 安装依赖...")
        ret = subprocess.run([
            python, "-m", "pip", "install",
            "-r", req,
            "--find-links", str(_DEPS_DIR),
            "--no-index",
            "--no-warn-script-location",
        ])
        if ret.returncode == 0:
            logger.info("本地依赖安装成功")
            return True
        logger.warning("本地 whl 安装失败，回退到镜像源")

    # 策略 2：清华 + 中科大镜像源
    logger.info("使用清华镜像源安装依赖...")
    cmd = [
        python, "-m", "pip", "install",
        "-r", req,
        "-i", "https://pypi.tuna.tsinghua.edu.cn/simple",
        "--extra-index-url", "https://mirrors.ustc.edu.cn/pypi/simple",
        "--no-warn-script-location",
    ]
    if sys.platform.startswith("linux"):
        cmd.append("--break-system-packages")

    if subprocess.run(cmd).returncode == 0:
        logger.info("镜像源依赖安装成功")
        return True

    # 策略 3：pip 全局配置兜底
    logger.warning("镜像源失败，使用 pip 全局配置兜底...")
    cmd2 = [python, "-m", "pip", "install", "-r", req, "--no-warn-script-location"]
    if sys.platform.startswith("linux"):
        cmd2.append("--break-system-packages")

    if subprocess.run(cmd2).returncode == 0:
        logger.info("依赖安装成功")
        return True

    logger.error("依赖安装全部失败，请手动执行: pip install -r requirements.txt")
    return False
