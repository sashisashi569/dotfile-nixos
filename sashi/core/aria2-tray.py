#!/usr/bin/env python3
"""System tray controller for the local aria2c RPC daemon.

Talks to aria2c over JSON-RPC (the daemon is started by the systemd user unit
declared in aria2.nix) and exposes pause/resume/purge plus live progress in a
StatusNotifierItem tray icon. Intended to be launched from Umbriel's autostart
list; it does not itself manage the aria2c process.
"""

import os
import subprocess
import threading
import time

import aria2p
import pystray
from PIL import Image, ImageDraw

HOST = "127.0.0.1"
PORT = 6800
DOWNLOAD_DIR = os.path.join(os.path.expanduser("~"), "Downloads")
POLL_INTERVAL = 3.0

_api = None


def api():
    global _api
    if _api is None:
        _api = aria2p.API(aria2p.Client(host=HOST, port=PORT))
    return _api


def try_api():
    """Return a live API handle, or None when the daemon is unreachable."""
    global _api
    try:
        handle = api()
        handle.get_stats()
        return handle
    except Exception:
        _api = None
        return None


def make_image():
    size = 64
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((3, 3, size - 4, size - 4), fill=(28, 32, 44, 255), outline=(90, 160, 240, 255), width=4)
    draw.polygon(
        [(32, 51), (15, 31), (25, 31), (25, 13), (39, 13), (39, 31), (49, 31)],
        fill=(120, 200, 255, 255),
    )
    return image


def human_speed(bps):
    value = float(bps)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if value < 1024 or unit == "TiB":
            return f"{int(value)} {unit}/s" if unit == "B" else f"{value:.1f} {unit}/s"
        value /= 1024


def pause_all(icon, item):
    handle = try_api()
    if handle is not None:
        try:
            handle.pause_all()
        except Exception:
            pass
    icon.update_menu()


def resume_all(icon, item):
    handle = try_api()
    if handle is not None:
        try:
            handle.resume_all()
        except Exception:
            pass
    icon.update_menu()


def purge_done(icon, item):
    handle = try_api()
    if handle is not None:
        try:
            handle.purge()
        except Exception:
            pass
    icon.update_menu()


def open_downloads(icon, item):
    os.makedirs(DOWNLOAD_DIR, exist_ok=True)
    subprocess.Popen(["xdg-open", DOWNLOAD_DIR])


def quit_tray(icon, item):
    icon.stop()


def build_menu():
    handle = try_api()
    items = []
    if handle is None:
        items.append(pystray.MenuItem("aria2: 接続なし", None, enabled=False))
    else:
        try:
            downloads = handle.get_downloads()
            active = [d for d in downloads if d.is_active]
            waiting = [d for d in downloads if d.is_waiting]
            paused = [d for d in downloads if d.is_paused]
            items.append(
                pystray.MenuItem(
                    f"実行中 {len(active)} / 待機 {len(waiting)} / 停止 {len(paused)}",
                    None,
                    enabled=False,
                )
            )
            for download in active[:10]:
                try:
                    label = f"{download.name[:36]}  {download.progress_string()}  {download.download_speed_string()}"
                except Exception:
                    label = download.name[:40]
                items.append(pystray.MenuItem(label, None, enabled=False))
        except Exception:
            items.append(pystray.MenuItem("aria2: 状態取得エラー", None, enabled=False))
    items.append(pystray.Menu.SEPARATOR)
    items.append(pystray.MenuItem("すべて一時停止", pause_all))
    items.append(pystray.MenuItem("すべて再開", resume_all))
    items.append(pystray.MenuItem("完了済みを消去", purge_done))
    items.append(pystray.MenuItem("ダウンロードフォルダを開く", open_downloads))
    items.append(pystray.Menu.SEPARATOR)
    items.append(pystray.MenuItem("トレイを終了", quit_tray))
    return items


def monitor(icon):
    while True:
        handle = try_api()
        if handle is None:
            icon.title = "aria2: デーモンに接続できません"
        else:
            try:
                active = [d for d in handle.get_downloads() if d.is_active]
                speed = sum(d.download_speed for d in active)
                icon.title = f"aria2: {len(active)} 件ダウンロード中 ({human_speed(speed)})"
            except Exception:
                icon.title = "aria2"
        try:
            icon.update_menu()
        except Exception:
            pass
        time.sleep(POLL_INTERVAL)


def main():
    icon = pystray.Icon("aria2", make_image(), "aria2", pystray.Menu(build_menu))
    threading.Thread(target=monitor, args=(icon,), daemon=True).start()
    icon.run()


if __name__ == "__main__":
    main()
