---
description: Create a new project from the Base context engineering template
argument-hint: [project-name]
---

Use the `create-project` agent to scaffold a new project from the Base template.

The agent will:
1. Ask for project details (name, description, stack, constraints)
2. Run `scripts/init.py` to copy and configure the template
3. Fill `docs/PROJECT.md`, `docs/ARCHITECTURE.md`, `docs/WORKFLOW.md` with the provided info
4. Run `scripts/health.py` to validate MCP infrastructure
5. Initialize git repository
6. Report results with next steps

If a project name was provided as argument, pass it to the agent.
