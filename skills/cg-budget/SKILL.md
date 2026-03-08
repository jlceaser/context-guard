---
name: cg-budget
description: |
  Context budget zones and degradation detection for Context Guard.
  Trigger: "budget zone", "context budget", "am I degrading",
  "check context health", "zone status", "/cg-budget"
version: 0.2.0
user-invocable: true
---

# Context Guard — Budget Zones & Degradation Detection

## Budget Zones

Adapt behavior based on estimated context consumption.

### 1. Estimate Current Zone

```bash
source "$HOME/.claude/hooks/compact-guard-lib.sh" 2>/dev/null
ZONE=$(cg_estimate_zone)
SESSION=$(cg_session_number)
SNAP_COUNT=$(cg_snapshot_count)
echo "Zone: $ZONE | Session: #$SESSION | Snapshots: $SNAP_COUNT"
```

### 2. Apply Zone Rules

| Zone | Context | Behavior |
|------|---------|----------|
| GREEN | < 60% | Full exploration. Read files, broad searches, no constraints. |
| YELLOW | 60-75% | Be selective. Prefer Grep over Read. Batch operations. Avoid re-reading files. |
| ORANGE | 75-85% | Conserve. Line ranges only. Delegate to subagents. Consider `/cg-snapshot`. |
| RED | > 85% | Wrap up. Complete only active task. Run `/cg-snapshot`. Suggest new session. |

### 3. Zone-Specific Actions

**GREEN:** Work freely. Front-load research and exploration.

**YELLOW:**
- Use Grep with targeted patterns instead of Read for large files
- Summarize findings instead of quoting full content
- Avoid re-reading files already seen in this session
- Delegate broad exploration to subagents

**ORANGE:**
- Read only specific line ranges (offset + limit)
- Use Grep exclusively for finding information
- Give concise responses — skip explanations unless asked
- Do NOT start new exploratory tasks
- Run `/cg-snapshot` to save state preemptively

**RED:**
- Stop all exploratory work immediately
- Complete only the immediately active atomic operation
- Run `/cg-snapshot` to capture full state
- Inform user: "Context budget yaklaşıyor — mevcut durumu kaydettim. Yeni oturumda devam etmek verimliliği artırır."
- If code changes in progress, suggest committing current state

## Degradation Self-Check

When suspecting context degradation, run this mental checklist:

| Check | Question | If NO → |
|-------|----------|---------|
| 1 | Projenin ana hedefini hatırlıyor muyum? | Stage 1+ |
| 2 | Bu oturumda hangi dosyaları değiştirdim? | Stage 2+ |
| 3 | Şu an düzenlediğim fonksiyonu tekrar okumadan tarif edebilir miyim? | Stage 2+ |
| 4 | Daha önce denediğim bir adımı tekrarlıyor muyum? | Stage 3 |
| 5 | Referans verdiğim API'ler/fonksiyonlar gerçekten var mı? | Stage 3 |

### Degradation Stages

**Stage 1 (Mild, ~60%):** Detayları unutma, tekrar sorma.
→ Kritik dosyayı tekrar oku, plan özetle.

**Stage 2 (Moderate, ~75%):** Kararlarla çelişme, import eksikleri.
→ Durum özeti yaz, sadece aktif dosyaları oku, araştırmayı subagent'a delege et.

**Stage 3 (Severe, ~85%):** API hallucination, aynı fix'i tekrarlama.
→ **Kodlamayı durdur.** `/cg-snapshot` çalıştır. Kullanıcıya bildir.

**Stage 4 (Critical, ~90%+):** Tutarsız reasoning, anlamsız kod.
→ **Hiçbir kod değişikliği yapma.** State kaydet, oturumu kapat.

## Prevention

- Budget zone'ları proaktif kullan — degradation'ı bekleme
- Araştırmayı subagent'lara delege et (context tasarrufu)
- Sık sık commit at — küçük commit = güvenli state
- Karmaşık görevlerde önceden `/cg-snapshot` al
