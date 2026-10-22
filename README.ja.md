# cc-win-traps

Windows で Claude Code を自動で回すとき、**エラーを出さずに結果だけ壊れる**落とし穴を14か所、あなたの PC でわざと踏んで、起きるかどうかを表で出すスクリプトです。読むだけで、`tmp\traps` の外には何も書きません。

English / Claude Code プラグインとしての使い方: [README.md](README.md)

## 使い方

Windows PowerShell 5.1 と Python が要ります（T14 は `claude` も使います）。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\repro-traps.ps1
```

- `-SkipSlow` … 書き込み中のファイルのサイズを見る T13（数秒かかる）を飛ばす
- `-SkipClaude` … `claude` を呼ぶ T14 を飛ばす

`REPRODUCED` は、その穴があなたの PC で起きたということです。**判定は -File で呼んだときの結果で見てください**（`-Command` で呼ぶと、それ自体が T01 の穴を踏みます）。

## 14か所

| Id | 何が壊れるか | 作者の PC での結果 |
| --- | --- | --- |
| T01 | `-Command` で呼ぶと、終了コード 2 が 1 になる | `-File=2 -Command=1` |
| T02 | `-File` で `-Path a b` と渡すと、b が黙って捨てられる | `count=1`、終了コード 0 |
| T03 | `-File` で `-Path a,b` と渡すと、1つの文字列になる | `first=a,b` |
| T04 | パイプで渡した日本語が `?` になる | バイト `3f3f` |
| T05 | UTF-8 の出力を既定のコードページで読むと文字化け | 2文字が別の4文字に |
| T06 | リダイレクトしたときだけ Python が落ちる | UnicodeEncodeError、終了コード 1 |
| T07 | `python -I` は `PYTHONIOENCODING` を読まない | `-I` で 1、外すと 0 |
| T08 | BOM のない日本語入りの `.ps1` | 出力が元と違う |
| T09 | 改行が LF の `.cmd` がコメントを実行する | `cp932=broken cp65001=ok` |
| T10 | 一行で渡すと、呼ぶ側が `$i` を先に展開する | 構文エラー、終了コード 1 |
| T11 | `-LiteralPath` と `-Include` を組むと絞り込みが効かない | `.md` も返った |
| T12 | `"..."` の中のバッククォートが改行やタブになる | 改行が入った |
| T13 | 書き込み中のファイルが 0 バイトに見える（AppData の下） | 一覧 0、実際 5,000,000 |
| T14 | `--allowedTools` の後ろのプロンプトが飲み込まれる | `Input must be provided ...` |

作者の PC: Windows 11 / Windows PowerShell 5.1.26100 / Python 3.13.7 / Claude Code 2.1.304、日本語の Windows（コードページ 932）。2026-10-20〜21 に確認。

**英語版の Windows（1252 / 437）では結果が変わります。** T09 は起きませんでした。T05・T06・T09 は、その PC の既定のコードページで試すように作ってあります。

**Python 3.15（2026-10-09 公開）は UTF-8 が既定です（PEP 686）。** 3.15 以降では T06・T07 は NOT REPRODUCED になる見込みです。作者の PC は 3.13 で、3.15 の既定と同じ `-X utf8` を付けて流すと落ちませんでした。

## 直し方

症状と確かめ方、直し方は無料の記事にまとめています。

- エラーなしで壊れる14か所（note）: https://note.com/sodateru_ai/n/na7d9ee2a36fa

14か所を最初から踏まないようにした部品（書き込み先を絞る安全装置、夜の無人実行、健康診断、CLAUDE.md の型、試験一式）は「cc-win-kit」として有料で出しています（note、2026年10月31日公開）。このスクリプトは、キットが無くても単独で使えます。

- https://note.com/sodateru_ai/n/ndad0eb6feaa6

## ライセンス

MIT（[LICENSE](LICENSE)）。
