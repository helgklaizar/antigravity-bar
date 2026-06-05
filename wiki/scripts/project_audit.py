#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import json
import subprocess

def run_cmd(args, cwd):
    try:
        result = subprocess.run(args, capture_output=True, text=True, cwd=cwd, timeout=5)
        return result.stdout.strip(), result.returncode
    except Exception:
        return "", -1

def audit_project(path):
    issues = []
    
    # 1. Проверка чистоты Git
    status_out, code = run_cmd(["git", "status", "--porcelain"], cwd=path)
    if code == 0 and status_out:
        issues.append("Не закоммиченные изменения (Git dirty)")
        
    # 2. Проверка невыгруженных коммитов
    setup_path = os.path.join(path, ".setup.json")
    ignore_unpushed = False
    if os.path.exists(setup_path):
        try:
            with open(setup_path, "r", encoding="utf-8") as f:
                setup_data = json.load(f)
                if setup_data.get("git", {}).get("ignore_unpushed", False):
                    ignore_unpushed = True
        except Exception:
            pass

    if not ignore_unpushed:
        branch_out, code = run_cmd(["git", "status", "-sb"], cwd=path)
        if code == 0 and "ahead" in branch_out:
            issues.append("Есть невыгруженные коммиты (unpushed)")
        
    # 3. Проверка соответствия чек-листу экосистемы (GEMINI.md и wiki/)
    if not os.path.exists(os.path.join(path, "GEMINI.md")):
        issues.append("Отсутствует GEMINI.md в корне")
        
    wiki_dir = os.path.join(path, "wiki")
    if not os.path.exists(wiki_dir):
        issues.append("Отсутствует папка базы знаний wiki/")
    else:
        if not os.path.exists(os.path.join(wiki_dir, "index.md")):
            issues.append("Отсутствует wiki/index.md")
        if not os.path.exists(os.path.join(wiki_dir, "log.md")):
            issues.append("Отсутствует wiki/log.md")
            
    # 4. Проверка зависимостей Node.js
    if os.path.exists(os.path.join(path, "package.json")):
        if not os.path.exists(os.path.join(path, "node_modules")):
            issues.append("Отсутствует папка зависимостей node_modules")
            
    return issues

def main():
    projects_root = os.path.expanduser("~/Projects")
    subdirs_to_scan = ["prod", "clients", "mvp"]
    
    problematic_projects = []
    
    for subdir in subdirs_to_scan:
        subdir_path = os.path.join(projects_root, subdir)
        if not os.path.exists(subdir_path):
            continue
            
        for name in os.listdir(subdir_path):
            project_path = os.path.join(subdir_path, name)
            if not os.path.isdir(project_path) or name == "Archive":
                continue
                
            # Проверяем, является ли репозиторием Git
            if os.path.exists(os.path.join(project_path, ".git")):
                issues = audit_project(project_path)
                if issues:
                    problematic_projects.append({
                        "name": name,
                        "path": project_path,
                        "issues": issues
                    })
                    
    # Путь для записи отчета
    app_data_dir = os.path.expanduser("~/.gemini/antigravity")
    os.makedirs(app_data_dir, exist_ok=True)
    report_path = os.path.join(app_data_dir, "project_audit.json")
    
    report_data = {
        "problematic_projects": problematic_projects
    }
    
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report_data, f, ensure_ascii=False, indent=2)
        
    print(f"Аудит завершен. Найдено проблемных проектов: {len(problematic_projects)}. Отчет записан в {report_path}")

if __name__ == "__main__":
    main()
