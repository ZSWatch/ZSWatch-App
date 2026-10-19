#!/usr/bin/env python3
"""Generate owned media for physical iOS AMS checks; never access user media."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import wave

HTML = '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ZSWatch owned media acceptance</title>\n<style>body{font:20px system-ui;margin:30px}button{font:inherit;padding:15px;margin:8px}</style>\n<h1>ZSWatch owned media acceptance</h1><p>Generated tones used only for the watch media check.</p><p id="status">Track 1 · paused</p>\n<button onclick="start()">Start owned audio</button><button onclick="pause(\'ui-pause\')">Pause owned audio</button><button onclick="next(\'ui-next\')">Next owned track</button>\n<script>\nlet track=1;const audio=new Audio(\'track1.wav\');audio.loop=true;\nconst report=(kind)=>fetch(\'event?kind=\'+encodeURIComponent(kind)+\'&track=\'+track+\'&paused=\'+audio.paused+\'&position=\'+audio.currentTime.toFixed(2)).catch(()=>{});\nfunction update(){document.getElementById(\'status\').textContent=\'Track \'+track+\' · \'+(audio.paused?\'paused\':\'playing\');if(\'mediaSession\' in navigator){navigator.mediaSession.metadata=new MediaMetadata({title:\'ZSWatch HIL Track \'+track,artist:\'Companion acceptance\',album:\'Owned generated fixture\'});navigator.mediaSession.playbackState=audio.paused?\'paused\':\'playing\';}}\nasync function start(kind=\'ui-play\'){await audio.play();update();report(kind);}\nfunction pause(kind){audio.pause();update();report(kind);}\nasync function next(kind){track=track===1?2:1;audio.src=\'track\'+track+\'.wav\';await audio.play();update();report(kind);}\nif(\'mediaSession\' in navigator){navigator.mediaSession.setActionHandler(\'play\',()=>start(\'remote-play\'));navigator.mediaSession.setActionHandler(\'pause\',()=>pause(\'remote-pause\'));navigator.mediaSession.setActionHandler(\'nexttrack\',()=>next(\'remote-next\'));navigator.mediaSession.setActionHandler(\'previoustrack\',()=>next(\'remote-previous\'));}\naudio.addEventListener(\'play\',update);audio.addEventListener(\'pause\',update);\n</script>'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="New fixture directory")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / "index.html").write_text(HTML, encoding="utf-8")
    for number, frequency in [(1, 440), (2, 660)]:
        with wave.open(str(args.output / f"track{number}.wav"), "wb") as audio:
            audio.setparams((1, 2, 8000, 0, "NONE", "not compressed"))
            # Quiet generated tones; no speech, external downloads or microphone.
            samples = (int(600 * math.sin(2 * math.pi * frequency * n / 8000))
                       for n in range(120 * 8000))
            audio.writeframes(b"".join(struct.pack("<h", sample) for sample in samples))
    receipts = [{"name": p.name, "bytes": p.stat().st_size,
                 "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
                for p in sorted(args.output.iterdir())]
    (args.output / "manifest.json").write_text(json.dumps(receipts, indent=2)+"\n")
    print(json.dumps({"directory": str(args.output.resolve()), "files": receipts}))

if __name__ == "__main__":
    main()
