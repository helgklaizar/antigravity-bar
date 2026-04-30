<div align="center">
  <h1>🌍 Antigravity AI Ecosystem</h1>
  <h3>The Ultimate Command Center for Autonomous Development</h3>
  <p>
    <b>Deploy the latest skills, workflows, and configurations fine-tuned for maximum productivity in agentic mode.</b>
  </p>
  <br/>
  <p>
    <img src="https://img.shields.io/badge/Architecture-Flat_Global_Topology-blue.svg" alt="Architecture">
    <img src="https://img.shields.io/badge/Status-Production_Ready-success.svg" alt="Status">
    <img src="https://img.shields.io/badge/Platform-Cross--Platform-black.svg" alt="Platform">
  </p>
</div>

<br/>

## 🎯 What is this project?

This repository is the **Global Master Database** that powers your entire AI-driven development lifecycle. It upgrades your standard AI assistant into a fully autonomous, hyper-optimized **Swarm**.

### The Problem It Solves
Most AI setups are fragmented: hidden `.gemini` folders scattered across dozens of projects, leading to outdated prompts, forgotten rules, and constant "hallucinations". Developers waste hours doing manual prompt engineering instead of coding.

### The Solution: The 3-Layer Ecosystem Architecture
We solve this by centralizing the "brain" and strictly separating concerns. The AI-Ecosystem provides a unified, highly-curated repository located at `~/.gemini/antigravity/` built on three pillars:

1. **System Prompts (The Rulebook):** Global personas and absolute rules. No complex bash logic here.
2. **Skills & Workflows (The Orchestrators):** Markdown routing steps that coordinate tasks and tools without executing heavy logic internally.
3. **Tools (The Executors):** Native local bash and python scripts (e.g., `generate_news_feed.py`) that act as "dumb couriers" returning structured data.

This 3-layer architecture ensures zero context bloat, eliminates hallucinations, and allows the AI to use native terminal execution securely instead of relying on heavy MCP servers.

- **Deploy the Best Tools:** Instantly pull the most cutting-edge workflows, prompt updates, and skills specifically tailored for Antigravity.
- **Agentic Mode Ready:** Fine-tuned to allow your AI to execute massive, end-to-end tasks autonomously without getting stuck.
- **Experience Bank (Reasoning Memory):** The AI doesn't just remember static rules—it actively logs its "failure trajectories" into Knowledge Items, ensuring mistakes are never repeated across your entire ecosystem.

---

## 👥 Who is it for & How does it help?

- **Solo Developers & Indie Hackers**: Helps you code 10x faster by providing pre-written, highly optimized workflows. Need to build a native Mac app? Just use the existing macOS skills. No need to teach the AI *how* to code—it already knows the best practices.
- **Development Teams**: Provides a unified standard. Every developer on your team will have the exact same AI guardrails, ensuring that code quality, security protocols, and testing standards remain perfectly consistent across all commits.
- **AI Orchestrators**: This is fundamentally an API for AI. It gives the AI the structured blueprints it needs to execute massive tasks (like full codebase refactors or E2E UI testing) autonomously, without waiting for human input.

---

## ⚡ AntigravityBar: Your AI Command Center

Forget digging through terminals. The **AntigravityBar** is a native, ultra-lightweight macOS status bar app that bridges this GitHub ecosystem directly to your machine. It's the ultimate remote control for your AI.

![Antigravity Bar Menu](status-bar/assets/screenshots/dashboard.png)

### Why you'll love it:
- **Live System Telemetry:** Professional, color-coded monitoring for CPU, GPU, and RAM, right where you need it. Now features clear visual distinction between System RAM and local application cache.
- **Dynamic Skill Fetching:** Fetches skills on-demand from a remote registry to keep your local environment pristine, with one-click cache clearing.
- **Workflow Radar:** Automatically tracks usage metrics of your AI workflows, allowing you to easily archive unused skills directly from the UI.
- **Context-Aware Autopilot:** It dynamically watches your IDE and automatically injects the correct `PROFILE.md` so your AI never hallucinates context across different projects.
- **Real-Time Quota Tracking:** Never guess your API limits again. Live tracking for Gemini 3.1 Pro, Claude Sonnet, and local models.

---

## 📂 Ecosystem Structure

To ensure zero bloat and maximum performance, the ecosystem is strictly divided by responsibility. 

> 📖 **Explore the Capabilities:** For a full, curated list of all active skills and macro-workflows, read the **[Ecosystem Guide](ECOSYSTEM_GUIDE.md)**.

| Directory | Purpose | Examples |
| :--- | :--- | :--- |
| 🌍 **`/global_workflows`** | **Macro Operations.** High-level orchestrations triggered via `/slash-commands`. They tell the AI *what* process to run. | `/qa-orchestrator`, `/pr-writer`, `/session-recap` |
| 🧠 **`/skills`** | **Micro Instructions.** Stack-specific rules that teach the AI *how* to write code for your specific language. | `React`, `Swift`, `Python`, `Rust` best practices |
| 📋 **`/templates`** | **System Files.** Standardized blueprints used to format project execution and share context. | `GEMINI.md`, `SWARM_STATE.md`, `SECRETS_MAP.md` |
| ⚡ **`/status-bar`** | **Source Code.** The Swift source code for the native macOS AntigravityBar application. | App UI, System Telemetry logic |

---

## 🚀 First-Time Onboarding

Ready to supercharge your IDE? There are two ways to set up your perfectly tailored environment:

### Flow A: AI-Driven Onboarding (Recommended)
1. Open your **Antigravity IDE**.
2. Drop this repository link into the AI chat: `https://github.com/helgklaizar/AI-Ecosystem`
3. The Agent will autonomously find the `AI_ONBOARDING.md` file, read the instructions, install the Status Bar, and interactively compile your local settings based on your stack.

### Flow B: Visual Setup
1. Compile and launch the **Antigravity Bar** from the `status-bar/` folder.
2. Follow the sleek setup wizard.
3. Select your tech stack. The Status Bar will pull **ONLY** the necessary assets from this Global Database into your `~/.gemini/antigravity/` folder to keep your IDE blazing fast.

---

## 🧠 Documentation & Standards

- 📖 **[The Ecosystem Guide](ECOSYSTEM_GUIDE.md)** — The curated list of essential stacks and architectural rules.
- 🚀 **[The Onboarding Script](AI_ONBOARDING.md)** — Core AI instructions for generating dynamic configurations.

---
## 📄 License
MIT
