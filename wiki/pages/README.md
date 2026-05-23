<div align="center">
  <h1>🌍 Antigravity Bar (AI Package Manager)</h1>
  <h3>The Ultimate Command Center & Package Manager for Autonomous Development</h3>
  <p>
    <b>A native macOS Status Bar application that manages your Local AI ecosystem, model quotas, and JIT AI skill installations.</b>
  </p>
  <br/>
  <p>
    <img src="https://img.shields.io/badge/Architecture-Thin_Client-blue.svg" alt="Architecture">
    <img src="https://img.shields.io/badge/Status-Production_Ready-success.svg" alt="Status">
    <img src="https://img.shields.io/badge/Platform-macOS-black.svg" alt="Platform">
  </p>
</div>

<br/>

## 🎯 What is this project?

This repository houses the **Antigravity Bar**, a native Swift macOS application that acts as a "Thin Client" and Package Manager for your AI-driven development lifecycle.

### The Shift to a Decentralized Ecosystem
Previously, this repository contained hundreds of markdown skills, global workflows, and templates. This bloated the repository and created sync issues across multiple local projects.

**The New Paradigm:**
We have moved to a **Decentralized, JIT (Just-In-Time) Delivery Model**. The Antigravity Bar now features a built-in **Antigravity Bar Installer**. It pulls agentic skills, instructions, and workflows dynamically from a curated registry of external GitHub repositories (including community hubs like `awesome-cursorrules` and official vendor hubs like `anthropics/skills`).

This ensures your local `~/.gemini/antigravity/` folder is always populated with only the tools you actually need for the active project, keeping the context window pristine.

---

## ⚡ Features: Your AI Command Center

The Antigravity Bar lives in your macOS menu bar, giving you instant access to:

### 🪄 1. Antigravity Bar Installer (Multi-Repo Package Manager)
- **Dynamic Fetching:** Uses `registry.json` to scan top AI community repositories (e.g., `midudev/autoskills`, `garrytan/gstack`, `sickn33/antigravity-awesome-skills`).
- **Stack Analyzer:** Scans your active IDE project and auto-selects the correct AI skills (React, Rust, Tailwind) to download.
- **Global Installation:** Injects the downloaded markdown files directly into your local `~/.gemini/antigravity/` environment.

### 📊 2. Live System Telemetry & Quotas
- **System Monitoring:** Color-coded CPU, GPU, and RAM telemetry right in the menu bar.
- **Model Quota Tracking:** Live tracking for active AI models to ensure you never hit API limits unexpectedly.
- **Active Tasks Manager:** Monitor running background tasks and agent operations.

### 🧹 3. Environment & Cache Management
- **Quick Actions Toolbar:** One-click access to open your `.gemini` config folder, restart the UI, or wipe the agent cache.
- **Workflow Radar:** Tracks usage metrics of your AI workflows and archives unused skills automatically.

---

## 🚀 Installation & Build

The application is built natively for macOS using Swift.

```bash
# Clone the repository
git clone https://github.com/helgklaizar/AI-Ecosystem.git
cd AI-Ecosystem/status-bar

# Build the macOS App bundle
./build-app.sh

# Install to your Applications folder
cp -r "Antigravity Bar.app" /Applications/
```

## 📂 Architecture Overview

The repository is now strictly focused on the native application source code.
All actual AI skills and workflows are fetched dynamically at runtime.

| Directory | Purpose |
| :--- | :--- |
| ⚡ **`/status-bar`** | **Source Code.** The Swift source code for the native macOS AntigravityBar application. |

---
## 📄 License
MIT
