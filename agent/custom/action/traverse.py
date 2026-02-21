"""
通用多目标遍历执行器

custom_action_param 示例：
{
    "template":         "target.png",
    "threshold":        0.8,
    "roi":              [0, 200, 1080, 700],
    "action_sequence":  ["TaskA", "TaskB"],
    "after_all":        "TaskC",
    "stop_condition": {
        "type":   "ocr",
        "target": "料理屋",
        "roi":    [0, 0, 500, 100]
    }
}

Pipeline 调用方式：
{
    "开始遍历": {
        "recognition": "DirectHit",
        "action": "Custom",
        "custom_action": "TraverseAndExecute",
        "custom_action_param": { ... }
    }
}
"""

import json

from maa.agent.agent_server import AgentServer
from maa.context import Context
from maa.custom_action import CustomAction


@AgentServer.custom_action("TraverseAndExecute")
class TraverseAndExecute(CustomAction):

    # task_name → {"matches": [...], "index": int}
    # 用 task_name 做 key，同一个类可被多个 pipeline 节点复用
    _states: dict = {}

    def run(
        self,
        context: Context,
        argv: CustomAction.RunArg,
    ) -> CustomAction.RunResult:

        # ── 1. 解析参数 ────────────────────────────────────────────
        param: dict = json.loads(argv.custom_action_param) if argv.custom_action_param else {}
        task_name: str = argv.task_name

        template: str         = param.get("template", "")
        threshold: float      = param.get("threshold", 0.8)
        roi                   = param.get("roi")               # [x,y,w,h] 或 None
        action_sequence: list = param.get("action_sequence", [])
        after_all: str        = param.get("after_all", "")
        stop_cond             = param.get("stop_condition")

        # ── 2. 截图（本轮复用）────────────────────────────────────
        image = context.tasker.controller.post_screencap().wait().get()

        # ── 3. 检查终止条件 ────────────────────────────────────────
        if stop_cond and self._check_stop(context, image, stop_cond):
            self._states.pop(task_name, None)
            context.override_pipeline({task_name: {"next": []}})
            return CustomAction.RunResult(success=True)

        # ── 4. 新一轮开始：重新识别所有目标 ───────────────────────
        state = self._states.get(task_name)
        if state is None or state["index"] >= len(state["matches"]):
            matches = self._find_all(context, image, template, threshold, roi)
            self._states[task_name] = {"matches": matches, "index": 0}
            state = self._states[task_name]

            if not matches:
                # 识别不到目标，结束任务
                self._states.pop(task_name, None)
                context.override_pipeline({task_name: {"next": []}})
                return CustomAction.RunResult(success=True)

        # ── 5. 当前轮遍历完：执行 after_all，然后开启下一轮 ────────
        if state["index"] >= len(state["matches"]):
            state["index"] = 0
            next_tasks = ([after_all] if after_all else []) + [task_name]
            context.override_pipeline({task_name: {"next": next_tasks}})
            return CustomAction.RunResult(success=True)

        # ── 6. 点击当前目标 ────────────────────────────────────────
        hit = state["matches"][state["index"]]
        x, y, w, h = hit.box
        cx, cy = x + w // 2, y + h // 2
        context.tasker.controller.post_click(cx, cy).wait()
        state["index"] += 1

        # ── 7. 执行动作序列，结束后回到自身继续下一个 ──────────────
        context.override_pipeline({
            task_name: {"next": action_sequence + [task_name]}
        })
        return CustomAction.RunResult(success=True)

    # ── 内部方法 ──────────────────────────────────────────────────

    def _find_all(
        self,
        context: Context,
        image,
        template: str,
        threshold: float,
        roi,
    ) -> list:
        """调用框架内置 TemplateMatch 获取所有匹配结果，无需 cv2。"""
        reco_param: dict = {
            "template":  [template],
            "threshold": threshold,
            "order_by":  "Score",
            "count":     50,
        }
        if roi:
            reco_param["roi"] = roi

        reco_id = context.run_recognition_direct(
            "TemplateMatch",
            json.dumps(reco_param),
            image,
        )
        if not reco_id:
            return []

        detail = context.tasker.get_recognition_detail(reco_id)
        if not detail or not detail.hit:
            return []

        return detail.all_results

    def _check_stop(
        self,
        context: Context,
        image,
        condition: dict,
    ) -> bool:
        """检查终止条件，支持 ocr 和 template 两种类型。"""
        ctype  = condition.get("type", "ocr")
        target = condition.get("target", "")
        roi    = condition.get("roi")

        if ctype == "ocr":
            reco_param: dict = {"expected": [target]}
            if roi:
                reco_param["roi"] = roi
            reco_id = context.run_recognition_direct(
                "OCR", json.dumps(reco_param), image
            )

        elif ctype == "template":
            reco_param = {
                "template":  [target],
                "threshold": condition.get("threshold", 0.8),
            }
            if roi:
                reco_param["roi"] = roi
            reco_id = context.run_recognition_direct(
                "TemplateMatch", json.dumps(reco_param), image
            )

        else:
            return False

        if not reco_id:
            return False
        detail = context.tasker.get_recognition_detail(reco_id)
        return bool(detail and detail.hit)
