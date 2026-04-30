# 📖 ECOSYSTEM GUIDE: Essential Stack & Installation

Welcome to the **AI Ecosystem Guide**. This document defines the curated list of skills and workflows that are actually useful for our development stack. We keep our environment clean by ONLY downloading what we actively use.

---

## 🎯 Global Tech Stack Support

This ecosystem is built as a **Universal Supermarket**. It contains best-practice instructions and workflows for ALL major development environments, not just one specific stack. Whether a developer is building a Rust backend, a Python ML model, or a Next.js frontend, the relevant tools are available here.

---

## 📦 What to Download (The Curated List)

Instead of cluttering the system with thousands of unused skills, we only use the following high-value tools. **If a tool is not on this list, do not install it by default.**

### 1. Essential Global Workflows (`~/.gemini/antigravity/global_workflows/`)
Эти воркфлоу определяют макро-операции ИИ:
- `global_workflows/agent-orchestration/acceptance-orchestrator.md` — End-to-end task validation before completion.
- `global_workflows/ci-cd/github-workflow-automation.md` — Syncing projects and managing GitHub.
- `global_workflows/code-review/pr-writer.md` — Automates Pull Request creation and code review.
- `global_workflows/qa-testing/qa-orchestrator.md` — Autonomous QA node for code quality.
- `global_workflows/ci-cd/build-local.md` — Fast local builds, especially for desktop (Tauri/Swift) apps.
- `global_workflows/planning-design/session-recap.md` — (`/recap`) Saves session context to `SWARM_STATE.md` to prevent AI amnesia.
- `global_workflows/ai-automation/background-researcher.md` — Фоновый ИИ-исследователь для глубокого анализа документации и конкурентов (Deep Research).
- `global_workflows/ai-automation/website-cloner.md` — Автоматизированный реверс-инжиниринг и клонирование верстки веб-сайтов.

### 2. High-Priority Skills (`~/.gemini/antigravity/skills/`)
These give the AI specialized knowledge for our specific stack:
- `skills/frontend/swiftui-guidelines.md` & `skills/backend/macos-native-dev.md` — For building perfect native Mac apps.
- `skills/backend/python-fastapi-development.md` — Backend standards and patterns.
- `skills/frontend/nextjs-app-router.md` & `skills/frontend/frontend_best_practices.md` — For high-end UI creation.
- `skills/design-ui/ui-taste-design.md` — Enforces premium, non-generic design principles.
- `skills/automation-tools/bash-scripting.md` — For safe, defensive shell operations.

### 3. Core Templates & Swarm Orchestration (`~/.gemini/antigravity/templates/`)
These govern project-level AI operations, context sharing, and multi-agent concurrency:
- `SWARM_STATE.md` — Mandatory handover document when switching between AI agents (e.g., Backend -> Frontend).
- `SECRETS_MAP.md` — Explains where to find environment variables locally (No hardcoding!).
- `GEMINI.md` — Base configuration template for initializing new repos.

#### Parallel Swarm Execution (Git Worktrees)
When coordinating multiple tasks on the same project simultaneously, we use **Git Worktrees** to prevent merge conflicts and file locking.
- **Pattern:** `git worktree add ../feature-branch feature-branch`
- **Antigravity Execution:** Antigravity operates as a linear agent per session. To execute parallel work, you must open separate chat sessions (one for `/PROJECT`, one for `/feature-branch`). They coordinate via GitHub Issues or `SWARM_STATE.md` before merging back.

---

## 🏗️ The 3-Layer Ecosystem Architecture (Separation of Concerns)

Our ecosystem strictly follows a 3-layer architecture to prevent hallucinations and avoid overengineering:

1. **System Prompts (`GEMINI.md`, `RULES.md`)**: *The Rulebook*. These files define the agent's persona, global rules (e.g., "Simplicity First", "Use Russian"), and formatting. They DO NOT contain complex logic or bash scripts. They teach the AI *how* to act, not *what* to execute.
2. **Skills & Workflows (`global_workflows/`)**: *The Orchestrators*. These markdown files are routing steps. They tell the AI: "Run script A, check result, then run script B." They coordinate tools but do not execute logic internally.
3. **Tools (Local Scripts & Bash)**: *The Executors*. The actual work (fetching URLs, parsing logs, making API calls) is done by small, dedicated `.py` or `.sh` scripts. We use native terminal execution instead of bloated MCP servers (because we already have local filesystem access). Tools are "dumb couriers" that return JSON or text.

**CRITICAL:** Do NOT create `.gemini/skills/` folders inside individual project repositories (e.g., `PROD/my-app/.gemini/`). 
All AI assets MUST be stored centrally in `~/.gemini/antigravity/`. This prevents version drift, avoids context fragmentation ("blind spots"), and ensures the IDE's Status Bar tools work seamlessly across all your projects.

## 🧠 Experience Bank (Reasoning Memory & Knowledge Items)

Вместо того чтобы писать сотни сухих правил в `GEMINI.md`, мы используем продвинутую систему **Reasoning Memory** (база знаний `~/.gemini/antigravity/knowledge/`).
Наша память основана на концепции *Experience-driven scaling*: агент учится не только на успешных паттернах, но и на ошибках.
Когда агент сталкивается со сложной задачей или допускает ошибку, он создает Knowledge Item (KI), в котором фиксирует **Траекторию Рассуждений**:
1. Что мы пытались сделать.
2. Какие подходы **провалились** и почему (ошибки, тупики).
3. Какая цепочка рассуждений привела к **успехy**.

Приступая к новой задаче, ИИ запрашивает эту базу, чтобы избежать повторения известных ошибок (Memory-Aware Test-Time Scaling).

## ⚙️ How to Clean Your System

If your `~/.gemini/antigravity/skills/` folder has thousands of files, **it's time for a purge.**
You can ask your AI to delete everything except the core files listed above by saying:
> *"Please clean up my local skills and workflows, leaving only the essential stack from `ECOSYSTEM_GUIDE.md`."*

---

## 🚀 How to Install for a New Project

When setting up a new repository, do NOT copy the entire ecosystem.
1. Run the Onboarding script (`AI_ONBOARDING.md`).
2. The AI will read this Guide.
3. The AI will pull **only** the relevant workflows and skills based on the specific project's needs (e.g., pulling Swift skills only for a macOS project).
