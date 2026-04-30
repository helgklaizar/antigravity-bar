# GEMINI.md: Project Context & Strategic Guidelines

## Project: [Project Name]
- **Core Stack**: [e.g., MLX, React, Metal]
- **Strategic Goal**: [e.g., Build the fastest local inference engine]

## 🧠 Strategic Memory (Keep During Compact)
- [Key architectural decisions and benchmark targets]
- [Global AI tools/models currently in use for this project]

## 🧭 Operational Principles (Internal Core Guidelines)

**1. Сначала думай, потом пиши (Think Before Coding)**
- Явно формулируй предположения. При неоднозначности или путанице — спроси, а не угадывай.
- Если есть более простое решение задачи, сначала предложи его.

**2. Простота превыше всего (Simplicity First - No Overengineering)**
- Пиши минимально возможный код без speculative-багов и абстракций "на будущее".
- Никакой излишней гибкости/конфигурируемости, если это не запрошено.

**3. Хирургическая точность (Surgical Changes)**
- Трогай только то, что необходимо для текущей задачи.
- Не "улучшай" соседний код, стилистику или комментарии без прямой команды.
- Убирай за собой (функции/импорты), если они осиротели из-за *твоих* текущих правок, но не трогай старый мертвый код вокруг.

**4. Goal-Driven Execution & Security**
- Обрабатывай задачи циклами с проверками: "Добавить фичу X" → "Написать проверку" → "Код".
- **Безопасность**: Работай с `.env` и секретами осторожно, но обеспечивай быстрый процесс настроек.
- **Архитектура**: Соблюдай принятую в проекте иерархию, но предлагай рефакторинг, если он может улучшить scalability.

## 🔄 Development Workflow & Swarm Isolation
Строгий цикл разработки для ИИ:
1. **Brainstorm / Think**: Проанализируй задачу, предложи варианты решения (без кода).
2. **Clarify**: Задай уточняющие вопросы, если требования размыты.
3. **Plan**: Составь `implementation_plan.md` с архитектурными решениями.
4. **Isolate (Swarm)**: Если задача объемная, используй `git worktree add ../feature-branch feature-branch`. Работай изолированно, синхронизируйся через `SWARM_STATE.md`.
5. **Implement**: Напиши код (просто, без оверинжиниринга).
6. **Review (Mandatory)**: 
   - Вызови `/global_workflows/qa-pattern-reviewer.md` для проверки архитектуры.
   - Вызови `/global_workflows/qa-security-reviewer.md` для аудита безопасности.
7. **Finalize**: Заверши задачу и сделай Merge.

## 📖 Project Learnings (Compound Memory)
*В этот раздел ИИ ДОЛЖЕН записывать свои ошибки и специфичные для проекта инсайты. Эта секция накапливается со временем, чтобы ИИ не повторял одних и тех же ошибок. Начинается пустой.*

- [Добавь сюда правило, если ИИ ошибся с путями, импортами или логикой в рамках ЭТОГО проекта]

## 🏛 Layout & Structure
- [High-level overview]
