---
name: cg-annotate
description: |
  Append a persistent dated note to a project-scoped topic file that survives context
  compaction and session restarts.
  Trigger: "/cg-annotate", "annotate", "save note", "save annotation"
---

# Context Guard — Annotate

Add a persistent annotation to a topic file that survives across sessions.

## When to Use

Use `/cg-annotate <topic> "note text"` to save important findings, decisions, or state
that should be recalled in future sessions — even after context compaction.

Examples:
- `/cg-annotate makine-corpus "TDK min_chars raised to 50 after curator bypass"`
- `/cg-annotate tokenizer "i/ı distinction fixed in case folding layer"`
- `/cg-annotate build "vcpkg baseline updated to 2026-03-09"`

## Steps

### 1. Determine project key

```bash
ANNOT_BASE="$HOME/.claude/annotations"
if echo "${PWD}" | grep -qi "cedra"; then
  PROJECT_KEY="C--cedra"
else
  PROJECT_KEY=$(basename "${PWD}" | tr ' ' '-')
fi
echo "Project key: $PROJECT_KEY"
```

### 2. Determine topic

The topic is the first argument (e.g., "makine-corpus", "tokenizer", "build").
If not provided, ask the user: "Which topic? (e.g., makine-corpus, tokenizer, build)"

### 3. Ensure annotation file exists

```bash
ANNOT_FILE="$ANNOT_BASE/$PROJECT_KEY/${TOPIC}.md"
mkdir -p "$(dirname "$ANNOT_FILE")"
if [ ! -f "$ANNOT_FILE" ]; then
  printf '# Annotations: %s\n' "${TOPIC}" > "$ANNOT_FILE"
  printf '<!-- Context Guard v0.3.0 | project: %s -->\n' "${PWD}" >> "$ANNOT_FILE"
fi
```

### 4. Append the annotation

```bash
DATE=$(date +%Y-%m-%d)
printf '\n## %s\n' "$DATE" >> "$ANNOT_FILE"
printf -- '- %s\n' "$NOTE" >> "$ANNOT_FILE"
```

### 5. Confirm

```bash
echo "Annotation saved → $ANNOT_FILE"
echo "  Topic: $TOPIC"
echo "  Note: $NOTE"
```

## Output Format

```
Annotation saved → ~/.claude/annotations/{project}/{topic}.md
  Topic: {topic}
  Note: {note text}
```

If the user provides a multi-bullet note (e.g., multiple facts), write each as a
separate `- ` bullet in the same `## DATE` section.

After saving, confirm with the path and note text so the user can verify.
