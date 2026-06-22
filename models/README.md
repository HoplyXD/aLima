# On-device AI model (optional)

Drop a **GGUF** model file here named **`model.gguf`** to enable the in-game on-device
AI buyer banter (no server, no API key, fully offline). Or point
`alima/local_ai/model_path` (Project Settings) at a different path.

## One-time setup

1. **Install the NobodyWho addon** — https://github.com/nobodywho-ooo/nobodywho
   (Godot AssetLib, or download the release for your OS into `addons/nobodywho/`),
   then enable it in **Project → Project Settings → Plugins**.
2. **Download a small instruct GGUF model** and save it here as `model.gguf`. Good
   lightweight picks (run on most PCs, ~0.8–1.5 GB):
   - `Qwen2.5-1.5B-Instruct` (Q4_K_M) — recommended balance.
   - `Llama-3.2-1B-Instruct` (Q4_K_M) — smallest/fastest.
   (Search Hugging Face for the `*-GGUF` repo of either.)
3. Run the game → open a haggle → the indicator reads **"AI banter: on-device"**.

## Notes

- **Desktop + Android.** The NobodyWho Godot build ships arm64 Android libs, so a release
  Android export can run the model too (use a small one). Other platforms fall back to the
  offline bot.
- Bigger models = better replies but more RAM/slower. Start small.
- No internet, no key, no cost — it runs inside the game.
- If your installed NobodyWho version uses different node/method names, the only spot to
  adjust is `scripts/economy/local_ai.gd` (the `say` / `response_finished` / `model_node`
  calls); it's written defensively and just falls back if they don't match.

The `.gguf` file is **git-ignored** (too big to commit) — each machine downloads its own.
