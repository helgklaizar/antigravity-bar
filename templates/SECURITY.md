# Security Guidelines for AI

## 1. Secrets & Credentials
- **NEVER** output raw API keys, passwords, or tokens in the chat or commit messages.
- Always assume environment variables contain sensitive data.
- Read from `.env` files locally but NEVER hardcode their contents into source files.

## 2. Git Safety
- Always verify that `.gitignore` contains entries for `.env`, `*.pem`, `*.key`, and any other secrets before running `git add`.
- Do not commit `.ai/brain/` if it contains project-specific sensitive thoughts, unless instructed otherwise.

## 3. Web & API Security
- Sanitize all user inputs before passing them to databases or rendering them in UI.
- Use parameterized queries or ORMs. No raw SQL concatenation.
- Ensure CORS is correctly configured. Do not use wildcard `*` for origins in production.
- Implement proper Authentication and Authorization checks on all protected API routes.
