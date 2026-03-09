---
name: cg-recall
description: |
  Retrieve annotations for a topic and load them into working context. Lists available
  topics when called without arguments.
  Trigger: "/cg-recall", "recall annotations", "load annotations", "show annotations"
---

# Context Guard — Recall

Retrieve annotations for a topic and load them into working context.

## When to Use

Use `/cg-recall <topic>` to load persistent annotations saved across sessions.
Use `/cg-recall` (no argument) to list all available annotation topics.

Examples:
- `/cg-recall` — list all topics for the current project
- `/cg-recall makine-corpus` — load corpus pipeline notes
- `/cg-recall tokenizer` — load tokenizer architecture notes

## Steps

### 1. Determine project key

```bash
ANNOT_BASE="$HOME/.claude/annotations"
if echo "${PWD}" | grep -qi "cedra"; then
  PROJECT_KEY="C--cedra"
else
  PROJECT_KEY=$(basename "${PWD}" | tr ' ' '-')
fi
```

### 2a. If no topic given — list available topics

```bash
ANNOT_DIR="$ANNOT_BASE/$PROJECT_KEY"
echo "Available annotation topics for $PROJECT_KEY:"
echo ""
if [ -d "$ANNOT_DIR" ]; then
  for f in "$ANNOT_DIR"/*.md; do
    [ -f "$f" ] || continue
    TOPIC=$(basename "$f" .md)
    LINES=$(wc -l < "$f" | tr -d ' ')
    echo "  - $TOPIC  (${LINES} lines)"
  done
else
  echo "  No annotations yet."
  echo "  Create with: /cg-annotate <topic> \"your note\""
fi
echo ""
echo "Load a topic with: /cg-recall <topic>"
```

### 2b. If topic given — read and display it

```bash
ANNOT_FILE="$ANNOT_BASE/$PROJECT_KEY/${TOPIC}.md"
if [ -f "$ANNOT_FILE" ]; then
  cat "$ANNOT_FILE"
  echo ""
  echo "Annotations loaded — use /cg-annotate $TOPIC \"note\" to add more."
else
  echo "No annotations found for topic: $TOPIC"
  echo "Create with: /cg-annotate $TOPIC \"your note\""
fi
```

### 3. After displaying — index for searchability (if large)

If the annotation file has more than 30 lines, use context-mode to index the content
so it can be searched with `/cg-recall` + keyword queries in future steps.

## Output Format

When listing topics:
```
Available annotation topics for C--cedra:
  - makine-corpus  (42 lines)
  - tokenizer  (28 lines)

Load a topic with: /cg-recall <topic>
```

When displaying a topic: show the full file content verbatim, then:
```
Annotations loaded — use /cg-annotate {topic} to add more.
```
