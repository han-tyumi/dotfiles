# Model selection for coding agents

How the coding-agent model list (omp `enabledModels`, role bindings, fallback
chains) is kept small: every row must win a lane, and lanes are earned by
measurement, not by benchmarks or list price.

## The factors, in the order they bite

1. **Measured cost per solved task.** List price is a poor proxy. A model at
   3x the per-million price can cost less per ticket if it fails less and
   finishes sooner; conversely a "cheap" model that loops or truncates is the
   expensive one. Score with real tasks, hidden tests, and the session log's
   cost accounting — not vibes.
2. **Prompt caching.** The biggest single efficiency factor for agentic
   sessions, because every turn replays a large prompt. A cache-less model
   re-pays full input price per turn; a cached Anthropic-class model reads its
   history for ~0.1x. In measurement, cache-less "cheap" open models cost 5-9x
   a cached Claude-class model per ticket despite lower sticker prices. Verify
   caching empirically (two identical large prompts, inspect usage fields) —
   catalog cache *pricing* does not prove cache *behavior*.
3. **Context window.** Sets headroom before compaction; compaction is lossy,
   so a 160k row is a different tool from a 1M row regardless of quality.
4. **Max output ceiling.** An 8k output cap disqualifies a model from agentic
   lanes entirely — tool-call turns plus reasoning eat it before the work does.
   Models that can spend their whole budget on reasoning tokens and return
   empty content need headroom measured too.
5. **Modalities.** Image input only where the vision lane needs it; a free
   multimodal row makes paid single-purpose vision rows redundant.
6. **Provider quirks.** Some endpoints reject fields the harness always sends
   (e.g. a `thinking` key on models that don't implement it) — a row that only
   works after `/thinking off` is not a real option in daily use.

## Process

- Keep a dated evidence log (one section per eval: date, harness, sample,
  verdict). On a work machine it lives inside that machine's private overlay —
  not published here — because it cites internal tickets, gateways, and spend.
- When pruning the picker, check every consumer first: roles, presets,
  fallback chains, and any per-model thresholds are all coupled — remove them
  in the same commit.
- Don't trust raw usage counts: transcript echoes and audit sessions inflate
  them by orders of magnitude. Counts of *assistant turns actually generated*
  per model, per day, outside eval temp-dirs, are the usable signal.
- A fallback row is supposed to look unused — it's insurance against the
  primary lane dying, not a daily driver.
- Keep dominance honest: if model X solves at the same rate as model Y for 5x
  the cost with a smaller window, X stays only with an explicit rationale
  (diversity, pending measurement) recorded in the log.
