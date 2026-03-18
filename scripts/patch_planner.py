#!/usr/bin/env python3
"""Patch planner_agent.py to guard ref.json access when dataset is missing."""
import re
import sys

path = "app/agents/planner_agent.py"
with open(path) as f:
    src = f.read()

# Match the block that unconditionally opens ref.json.
# Captures indentation so the replacement preserves the upstream code style.
pattern = (
    r'(?P<indent>[ \t]+)retrieved_ids = data\.get\("top10_references", \[\]\)\n'
    r"(?P=indent)with open\(self\.exp_config\.work_dir / f\"data/PaperBananaBench/"
    r"""\{cfg\['task_name'\]\}/ref\.json\", \"r\", encoding=\"utf-8\"\) as f:\n"""
    r"(?P=indent)(?P<extra>[ \t]+)candidate_pool = json\.load\(f\)\n"
    r'(?P=indent)id_to_item = \{item\["id"\]: item for item in candidate_pool\}\n'
    r"(?P=indent)examples = \[id_to_item\[ref_id\] for ref_id in retrieved_ids if ref_id in id_to_item\]"
)

m = re.search(pattern, src)
if not m:
    print("ERROR: patch target not found in planner_agent.py — upstream may have changed", file=sys.stderr)
    sys.exit(1)

ind = m.group("indent")
ex = m.group("extra")

ref_path_line = """_ref_path = self.exp_config.work_dir / f"data/PaperBananaBench/{cfg['task_name']}/ref.json\""""

replacement = "\n".join([
    ind + 'retrieved_ids = data.get("top10_references", [])',
    ind + ref_path_line,
    ind + "if retrieved_ids and _ref_path.exists():",
    ind + ex + 'with open(_ref_path, "r", encoding="utf-8") as f:',
    ind + ex + ex + "candidate_pool = json.load(f)",
    ind + ex + 'id_to_item = {item["id"]: item for item in candidate_pool}',
    ind + ex + "examples = [id_to_item[ref_id] for ref_id in retrieved_ids if ref_id in id_to_item]",
])

src = src[: m.start()] + replacement + src[m.end() :]

with open(path, "w") as f:
    f.write(src)

print("Patched planner_agent.py: guarded ref.json access when dataset is missing")
