import os
import re
import shutil

antigravity_dir = os.path.expanduser("~/.gemini/antigravity")
brain_dir = os.path.join(antigravity_dir, "brain")

def archive_unused(base_dir, archive_target):
    if not os.path.exists(base_dir):
        return
    os.makedirs(archive_target, exist_ok=True)
    
    files_to_check = []
    for root, dirs, files in os.walk(base_dir):
        if "archive" in root:
            continue
        for f in files:
            if f.endswith(".md"):
                files_to_check.append(os.path.join(root, f))
                
    log_contents = []
    if os.path.exists(brain_dir):
        for d in os.listdir(brain_dir):
            log_path = os.path.join(brain_dir, d, ".system_generated", "logs", "overview.txt")
            if os.path.exists(log_path):
                with open(log_path, 'r', encoding='utf-8') as f:
                    log_contents.append(f.read())
                    
    for file_path in files_to_check:
        name = os.path.splitext(os.path.basename(file_path))[0]
        used = False
        pattern = re.compile(r"(?:@\[)?/" + re.escape(name) + r"(?:\])?\b")
        for content in log_contents:
            if pattern.search(content):
                used = True
                break
                
        if not used:
            dest = os.path.join(archive_target, os.path.basename(file_path))
            print(f"Archiving unused {name} -> {dest}")
            shutil.move(file_path, dest)

print("Archiving Workflows...")
archive_unused(
    os.path.join(antigravity_dir, "global_workflows"),
    os.path.join(antigravity_dir, "workflows_archive")
)

print("\nArchiving Skills...")
archive_unused(
    os.path.join(antigravity_dir, "skills"),
    os.path.join(antigravity_dir, "skills_archive")
)

print("Done.")
