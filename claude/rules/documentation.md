# Documentation

These rules cover **inline code documentation** — comments, docstrings, and module/class headers — as well as standalone docs (READMEs, `docs/`). Where a rule below says "docs", it means both.

## Single source of truth

Code is the source of truth. Documentation should explain **why**, **how things fit together**, and **workflow** — not restate what code already provides.

- **CLI arguments**: Don't list flags/options in docs. Note that the tool's help command and show only brief example invocations.
- **Config, model, struct schemas**: Don't duplicate field names, types, defaults, or descriptions from Pydantic models, dataclasses, or similar structures. Reference the model by name and file path.
- **Counts and sizes**: Don't hardcode counts (test counts, file sizes, array dimensions) that change as code evolves. Describe things qualitatively or reference the code that determines them.
- **Specific values**: Don't embed specific default values, thresholds, or magic numbers (e.g. "every 25 seconds", "default 0.3"). Docs should explain concepts and processes at a high level; the code and its comments are the source of truth for specific values. Refer to parameter names (e.g. `cluster_name`) without stating their values.

## Comment style

- **Declarative, not historical**: Comments describe how the code behaves **now**. Never write a comment as a changelog — no "previously", "used to", "changed from X to Y", "no longer needed since…", and no references to logic that was true before the current change. Git history and PR descriptions are the record of what changed; a comment that narrates a diff is stale as soon as the next person edits the file.


