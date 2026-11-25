#!/usr/bin/env python3
"""
音楽ファイルのタグを読み取り、次の命名規則でリネームするスクリプト:
  <トラック番号(2桁ゼロ埋め)> - <アーティスト> - <トラック名>.<拡張子>

使い方:
  python3 rename_music_by_tags.py [ディレクトリ] [--dry-run] [--recursive]

  ディレクトリ   : 対象ディレクトリ（省略時はカレントディレクトリ）
  --dry-run      : 実際にはリネームせず、変更内容だけを表示する
  --recursive    : サブディレクトリも再帰的に処理する
"""

import argparse
import sys
import unicodedata
from pathlib import Path

from mutagen import File as MutagenFile

# 対応する拡張子
AUDIO_EXTENSIONS = {".mp3", ".flac", ".m4a", ".mp4", ".ogg", ".oga", ".opus", ".wma", ".wav", ".aac"}

# ファイル名に使えない文字を置換するテーブル（Windows/主要OS互換のため）
INVALID_CHARS_TABLE = str.maketrans({
    "/": "／",
    "\\": "＼",
    ":": "：",
    "*": "＊",
    "?": "？",
    '"': "”",
    "<": "＜",
    ">": "＞",
    "|": "｜",
})


def sanitize(name: str) -> str:
    """ファイル名として不正な文字を全角に置換し、前後の空白を除去する"""
    name = name.translate(INVALID_CHARS_TABLE)
    name = unicodedata.normalize("NFC", name)
    return name.strip()


def get_first(value):
    """mutagenのタグ値（多くはリスト）から先頭要素を取り出す"""
    if value is None:
        return None
    if isinstance(value, (list, tuple)):
        return str(value[0]) if value else None
    return str(value)


def extract_tags(path: Path):
    """トラック番号・アーティスト・タイトルを取得する。取得できない項目はNoneを返す"""
    audio = MutagenFile(path, easy=True)
    if audio is None or audio.tags is None:
        return None, None, None

    tags = audio.tags

    track = get_first(tags.get("tracknumber"))
    artist = get_first(tags.get("artist"))
    title = get_first(tags.get("title"))

    if track:
        # "3/12" のような形式から先頭の数値だけを取り出す
        track = track.split("/")[0].strip()
        digits = "".join(ch for ch in track if ch.isdigit())
        track = digits if digits else None

    return track, artist, title


def build_new_name(track, artist, title, suffix: str) -> str:
    track_str = f"{int(track):02d}" if track else "00"
    artist_str = sanitize(artist) if artist else "Unknown Artist"
    title_str = sanitize(title) if title else "Unknown Title"
    return f"{track_str} - {artist_str} - {title_str}{suffix}"


def iter_audio_files(directory: Path, recursive: bool):
    pattern = "**/*" if recursive else "*"
    for path in sorted(directory.glob(pattern)):
        if path.is_file() and path.suffix.lower() in AUDIO_EXTENSIONS:
            yield path


def unique_target(target: Path) -> Path:
    """同名ファイルが既に存在する場合は連番を付与して衝突を回避する"""
    if not target.exists():
        return target
    stem, suffix = target.stem, target.suffix
    n = 2
    while True:
        candidate = target.with_name(f"{stem} ({n}){suffix}")
        if not candidate.exists():
            return candidate
        n += 1


def main():
    parser = argparse.ArgumentParser(description="音楽ファイルをタグ情報でリネームする")
    parser.add_argument("directory", nargs="?", default=".", help="対象ディレクトリ（省略時はカレントディレクトリ）")
    parser.add_argument("--dry-run", action="store_true", help="実際にはリネームせず変更内容のみ表示する")
    parser.add_argument("--recursive", action="store_true", help="サブディレクトリも再帰的に処理する")
    args = parser.parse_args()

    directory = Path(args.directory).expanduser().resolve()
    if not directory.is_dir():
        print(f"エラー: ディレクトリが見つかりません: {directory}", file=sys.stderr)
        sys.exit(1)

    files = list(iter_audio_files(directory, args.recursive))
    if not files:
        print("対象となる音楽ファイルが見つかりませんでした。")
        return

    renamed = 0
    skipped = 0

    for path in files:
        try:
            track, artist, title = extract_tags(path)
        except Exception as e:
            print(f"[エラー] タグ読み取り失敗: {path.name} ({e})")
            skipped += 1
            continue

        if not artist and not title:
            print(f"[スキップ] タグ情報が見つかりません: {path.name}")
            skipped += 1
            continue

        new_name = build_new_name(track, artist, title, path.suffix)
        new_path = path.with_name(new_name)

        if new_path == path:
            print(f"[変更なし] {path.name}")
            continue

        new_path = unique_target(new_path)

        if args.dry_run:
            print(f"[プレビュー] {path.name}  ->  {new_path.name}")
        else:
            path.rename(new_path)
            print(f"[リネーム] {path.name}  ->  {new_path.name}")
            renamed += 1

    print(f"\n完了: {renamed}件リネーム, {skipped}件スキップ, 合計{len(files)}件")


if __name__ == "__main__":
    main()
