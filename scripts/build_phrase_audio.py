"""Generate the bundled voice clips from assets/data/phrases.json. Run this on YOUR machine.

Darija (male): the SpeechT5 Darija Hugging Face Space, via gradio_client, input = Latin-script Darija.
English / French (male): edge-tts (optional, `pip install edge-tts`).

Each clip is normalised (ffmpeg silenceremove + loudnorm, mono mp3) and written to
  assets/audio/darija/male/<phraseId>.mp3, assets/audio/en/male/..., assets/audio/fr/male/...

Usage:
  pip install gradio_client edge-tts
  python scripts/build_phrase_audio.py --space <owner/space-name> [--api-name /predict] [--lang ar en fr]
Needs ffmpeg on PATH. Nothing secret is stored: pass a token with --token or the HF_TOKEN variable if the Space is private.
Only re-generates missing clips unless --force is given.
"""
import argparse
import asyncio
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = {"ar": "darija", "en": "en", "fr": "fr"}
EDGE_VOICE = {"en": "en-US-GuyNeural", "fr": "fr-FR-HenriNeural"}  # male


def normalise(src: Path, dst: Path):
    dst.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(src),
         "-af", "silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
                "silenceremove=start_periods=1:start_threshold=-50dB,areverse,loudnorm=I=-16:TP=-1.5:LRA=11",
         "-ac", "1", "-codec:a", "libmp3lame", "-q:a", "4", str(dst)],
        check=True)


def darija_clip(client, api_name, text, dst_tmp: Path):
    result = client.predict(text, api_name=api_name)
    path = result[0] if isinstance(result, (list, tuple)) else result
    shutil.copy(path, dst_tmp)


async def edge_clip(voice, text, dst_tmp: Path):
    import edge_tts
    await edge_tts.Communicate(text, voice).save(str(dst_tmp))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--space", help="Hugging Face Space id, e.g. owner/name (Darija TTS)")
    ap.add_argument("--api-name", default="/predict")
    ap.add_argument("--lang", nargs="+", default=["ar", "en", "fr"], choices=["ar", "en", "fr"])
    ap.add_argument("--token", default=os.environ.get("HF_TOKEN"))
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()

    if not shutil.which("ffmpeg"):
        sys.exit("ffmpeg not found on PATH")
    phrases = json.loads((ROOT / "assets/data/phrases.json").read_text(encoding="utf-8"))

    client = None
    if "ar" in a.lang:
        if not a.space:
            sys.exit("--space is required for Darija")
        from gradio_client import Client
        client = Client(a.space, hf_token=a.token) if a.token else Client(a.space)

    with tempfile.TemporaryDirectory() as tmp:
        for lang in a.lang:
            for pid, p in phrases.items():
                dst = ROOT / "assets/audio" / OUT[lang] / "male" / f"{pid}.mp3"
                if dst.exists() and not a.force:
                    continue
                raw = Path(tmp) / "raw.audio"
                try:
                    if lang == "ar":
                        darija_clip(client, a.api_name, p["latin"], raw)
                    else:
                        asyncio.run(edge_clip(EDGE_VOICE[lang], p[lang], raw))
                    normalise(raw, dst)
                    print("ok  ", lang, pid)
                except Exception as e:  # keep going: missing clips fall back to visible text
                    print("FAIL", lang, pid, e, file=sys.stderr)


if __name__ == "__main__":
    main()
