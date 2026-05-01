# sudoku-solver

数独パズルを画像から読み取り、自動的に解くツールです。

- **`sudoku_reader.py`** — 数独の画像を読み取り、各セルの数字を OCR で認識する（Python）
- **`sudoku-ruby.rb`** — 数独のパズルを論理的推論で解く（Ruby）

2つのプログラムはパイプで連結して使うことができます。

---

## 必要なライブラリのインストール

### Python（sudoku_reader.py）

```bash
pip install Pillow opencv-python numpy pyocr
```

OCR エンジンとして **Tesseract** が必要です。

```bash
# macOS (Homebrew)
brew install tesseract

# Ubuntu / Debian
sudo apt install tesseract-ocr
```

### Ruby（sudoku-ruby.rb）

標準ライブラリのみ使用しています。追加のインストールは不要です。

---

## 使い方

### sudoku_reader.py — 画像から数字を読み取る

```bash
python3 sudoku_reader.py <画像ファイル>
```

数独の画像を読み取り、認識した数字を **9文字×9行** の形式で標準出力に出力します。
空白マスは `0` で表されます。

```
000902000
040000050
002000300
200000007
000456000
600000009
007000800
030000040
000207000
```

**オプション**

| オプション | 説明 |
|-----------|------|
| `-v` / `--verbose` | 認識結果をグリッド形式で標準エラー出力に表示する |
| `-d` / `--debug` | デバッグ用の中間画像を `result/` ディレクトリに保存する |
| `-j` / `--json` | `param.json` からパラメータを読み込む |

```bash
# グリッド表示付きで実行
python3 sudoku_reader.py -v sudoku_test.png
```

---

### sudoku-ruby.rb — パズルを解く

パズルを **9文字×9行** の文字列として標準入力から渡すか、ファイルに直接書いた組み込みパズルで実行します。

#### 標準入力から渡す場合

```bash
ruby sudoku-ruby.rb <<'EOF'
200050001
007100030
040000800
000300070
100000009
050008000
003000040
080004200
600090005
EOF
```

#### 端末から直接起動する場合（組み込みパズルを使用）

```bash
ruby sudoku-ruby.rb
```

スクリプト末尾にハードコードされたパズル（朝日新聞 6つ星）を使って解きます。

**出力例**

```
Open cell:0
    0   1   2   3   4   5   6   7   8
  o---+---+---o---+---+---o---+---+---o
0 | 2 | 3 | 9 | 8 | 5 | 7 | 4 | 6 | 1 |
  ...
Solved!
```

---

### パイプラインで統合する

`sudoku_reader.py` の出力をそのまま `sudoku-ruby.rb` に渡すことができます。

```bash
python3 sudoku_reader.py <画像ファイル> | ruby sudoku-ruby.rb
```

**実行例**

```bash
python3 sudoku_reader.py sudoku_test.png | ruby sudoku-ruby.rb
```

画像の読み取りから解答の表示まで、1つのコマンドで完結します。

---

## サンプル画像

| ファイル | 出所 | 説明 |
|---------|------|------|
| `sudoku_test.png` | 自動生成 | 朝日新聞6つ星パズル（組み込みパズルと同一問題） |
| `sample1.png` | Wikimedia Commons | 解法解説用サンプル（26ヒント） |
| `sample2.png` | Wikimedia Commons | 解法解説用サンプル（28ヒント） |
| `sample3.png` | Wikimedia Commons | 解法解説用サンプル（33ヒント） |

`sample1.png`〜`sample3.png` は [Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:Sudoku) より取得した画像です。いずれもパイプラインで正しく解けることを確認済みです。

```bash
python3 sudoku_reader.py sample1.png | ruby sudoku-ruby.rb
python3 sudoku_reader.py sample2.png | ruby sudoku-ruby.rb
python3 sudoku_reader.py sample3.png | ruby sudoku-ruby.rb
```

---

## 謝辞

`sudoku_reader.py` のオリジナルコードは [kkJobSrc](https://github.com/kkJobSrc/sudoku_reader) 氏が公開されたものをベースにしています。画像認識・OCR による数独読み取りの実装を提供してくださったことに、心より感謝申し上げます。
