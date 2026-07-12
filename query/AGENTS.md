# Agent Guidelines

## Code Style

- Keep changes small, direct, and limited to the requested behavior.
- Prefer simple functional code with focused functions and minimal mutable state.
- Avoid one-off abstractions; inline logic used in only one place.
- Use camelCase for identifiers.
- Prefer short, clear names. Use single-word function and variable names when readable.
- Avoid boolean names with `is` or negations; prefer adjectives like `valid`, `empty`, `live`, and `idle`.
- Prefer descriptive names over comments. Add comments only for non-obvious behavior.

## Workflow

- Write or update focused tests before implementation when behavior changes.
- Follow existing package patterns and public API shape.
- Keep generated files in sync when the project build regenerates them.
- Do not introduce dependencies unless they are necessary for the current task.
