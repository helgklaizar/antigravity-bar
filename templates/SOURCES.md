

> [!IMPORTANT]
> **Universal Skills Integration:** Most rules and MCPs from external sources have been downloaded and universalized in our `skills/` directory. Check local skills before fetching from the internet.
# 🧭 AI Ecosystem Actionable Index

**AGENT INSTRUCTION:** This is your primary database. If the user requests a new skill, agent, workflow, or capability that you do not currently possess, you MUST consult this list. Search the categories below, extract the necessary files, and inject them into the user's project.

---

## 📚 Источники и Адаптация (Sources & Adaptations)

Мы не изобретаем велосипед, а берем лучшие open-source паттерны и адаптируем их под идеологию **Antigravity IDE**:

- **[TheRealSeanDonahoe/agents-md](https://github.com/TheRealSeanDonahoe/agents-md)**:
  - *Что взяли*: Концепцию **Compound Memory** (Секция 11: Project Learnings).
  - *Как адаптировали*: Вместо использования файла `AGENTS.md`, мы интегрировали этот паттерн напрямую в наш фирменный стандарт `GEMINI.md`. Теперь ИИ накапливает проектный опыт без создания конфликтующих файлов.
- **[Piebald-AI/system-prompts](https://github.com/Piebald-AI/claude-code-system-prompts)**:
  - *Что взяли*: Лучшие системные промпты от инженеров AI лабораторий.
  - *Как адаптировали*: Вытащили оттуда роли `Verification Specialist`, `Explore Agent` и `Plan Mode`, переписали их под наши стандарты и разместили в папках `skills/` и `global_workflows/`.
- **[openai/symphony] & [automazeio/ccpm]**:
  - *Что взяли*: Изоляцию ИИ-агентов.
  - *Как адаптировали*: Внедрили концепцию работы через изолированные `git worktree` и закрепили это в `SWARM_STATE.md` для безопасной параллельной работы (Сварм).
- **[karpathy/autoresearch] & [JCodesMore/ai-website-cloner-template]**:
  - *Что взяли*: Идеи автономных сложных скриптов.
  - *Как адаптировали*: Написали собственные `/slash-commands` (`background-researcher` и `website-cloner`), которые интегрируются прямо в окно чата IDE.

---

## 🛠 1. Skills and MCP Servers (Where to get Skills)
*If the user needs to connect a database, GitHub, Slack, web search, or specific CLI utilities.*

### MCP Servers (Model Context Protocol)
- **🔗 [punkpeye/awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers)** (85k+ Stars)
- **🔗 [ComposioHQ/awesome-ai-skills](https://github.com/ComposioHQ/awesome-ai-skills)**
- **🎯 What to take:** `npx` or Docker installation commands.
- **📥 Where to put it:** Add to the global Antigravity IDE MCP settings.

### Antigravity & Local Skills
- **🔗 [sickn33/antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills)** (34k+ Stars)
- **🔗 [mgechev/skills-best-practices](https://github.com/mgechev/skills-best-practices)** — Best practices for writing professional-grade skills and maintaining lean contexts.
- **🎯 What to take:** Markdown files (`*.md`) from the `/skills/` folder.
- **📥 Where to put it:** Save locally in `~/.gemini/antigravity/skills/`.

---

## 🤖 2. Agents (Where to get Agents)
*If the user asks to add a QA tester, DevOps engineer, or other specialized AI colleague.*

### Sub-Agents & Personas
- **🔗 [huggingface/smolagents](https://github.com/huggingface/smolagents)**
- **🎯 What to take:** System prompt text (agent persona).
- **📥 Where to put it:** Create a new `.md` file in `~/.gemini/antigravity/agents/`.

---

## 🔄 3. Workflows and Rules (Where to get Workflows & Rules)
*If the user needs coding standards for React, Rust, Python, Next.js, or general pipelines.*

### IDE Rules & Snippets
- **🎯 What to take:** Raw Markdown text.
- **📥 Where to put it:** Append to the `GEMINI.md` file in the project root.

---

## 📝 4. Prompts (Where to get Prompts)
*If the user asks for a complex roleplay prompt or a specific LLM request.*

### Global Prompt Libraries
- **🔗 [f/prompts.chat](https://github.com/f/prompts.chat)** (160k+ Stars)
- **🎯 What to take:** Role model text (e.g., "Act as a Linux Terminal").
- **📥 Where to put it:** Use directly in chat or save to `~/.gemini/antigravity/workflows/`.

---

## 🏛️ 5. Emerging AI Standards & "Illuminati" Workflows
*Industry standards for AI context mapping and workflows inspired by top researchers (e.g., Andrej Karpathy).*

### "README for AI" Standards
- **🔗 GEMINI.md Standard (Our Internal Standard):** Our proprietary project context mapping standard. Integrates Compound Memory and strictly defines vendor-agnostic rules.
- **🔗 DESIGN.md Pattern:** Introduced by tools like Google Stitch. It provides a structured Markdown file containing design tokens and visual do's/don'ts specifically for LLMs.
- **🎯 What to take:** The Markdown structure and YAML frontmatter conventions for AI.
- **📥 Where to put it:** Into our `~/.gemini/antigravity/templates/` folder as base patterns.

### The "Karpathy" Approach (Software 2.0 / Flat Context)
Andrej Karpathy (former Tesla AI / OpenAI) advocates for ultra-clean, flat C-style code and high-signal, low-noise context for LLMs.
- **🔗 [karpathy/llm.c](https://github.com/karpathy/llm.c)** — A masterclass in writing minimal, dependency-free code that LLMs can digest entirely in one shot.
- **🔗 [karpathy/minGPT](https://github.com/karpathy/minbpe)** — Clean, instructional implementations.
- **🎯 What to take:** The principle of "Dry Context" (no OOP bloat, flat topologies, pure C/Python patterns). This perfectly aligns with our `Flat Global Architecture Rule`.
- **📥 Where to put it:** Embed these principles directly into our `GEMINI.md` architectural rules.
