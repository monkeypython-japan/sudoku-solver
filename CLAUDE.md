# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Workflow

- **すべての変更はブランチを作成してから行う。** `main` への直接コミットは禁止。
- ブランチ上で変更を実施したら、ユーザーがテストを行う。
- テスト完了後、Claude がコミットして `main` へマージする。

## Runtime

This project runs in a Jupyter notebook with the iRuby kernel (`RubySudoku.ipynb`). There are no standalone Ruby files, build steps, or test suite — execute cells sequentially in Jupyter.

To start Jupyter: `jupyter notebook` or `jupyter lab`

## Architecture

All code lives in a single notebook. Classes are defined in early cells and must be re-executed whenever changed.

### Core classes

**`Cell`** — one cell in the 9×9 grid. Tracks `@possibles` (a `Set` of candidate digits 1–9) and `@impossibles`. Key invariant: when `possibles.length == 1`, the cell is fixed (`fixed?` returns the digit, not a boolean).

**`CellList`** — a named, ordered array of 9 cells representing a row, column, or 3×3 block. Uses a class-level `@@cache` keyed by name (`"L0"`–`"L8"`, `"C0"`–`"C8"`, `"B0"`–`"B8"`). Provides set-algebra constructors (`new_with_add`, `new_with_subtract`, `new_with_cross`) that produce new cached `CellList` objects — these accumulate in `@@cache` across solves.

**`Table`** — owns the 9×9 `@table` array and a flat `@list`. Delegates to `CellList` for row/column/block access. `CellList.@@cache` is class-level state, so creating a new `Table` does **not** clear it — the cache must be considered when re-running solves.

**`TableLoader`** — parses an array of 9 strings (e.g. `"200050001"`) where `0` means unknown, into a matrix for `Table#fix_with_matrix`.

**`Util`** — module with `compliment(set)` returning `Set[1..9] - set`.

### Solving algorithm (`Table#solve`)

`solve` iterates the following levels until no progress is made (`count_of_open_cell` stops decreasing):

| Level | Method | Strategy |
|-------|--------|-----------|
| 0 | `check` / `CellList#check` | Constraint propagation: remove fixed digits from peers; fix a digit if only one cell in a group can hold it |
| 1 | `find_and_fix_uniq_possible` | Uses `impossibles` to find a digit that only one cell in a group can accommodate |
| 2 | `find_and_fix_with_fixed_chair` | Naked subsets: if N cells share exactly N candidates, eliminate those from the rest of the group |
| 3 | `fix_with_cross_block` | Block–line interaction: if a digit in a block is confined to one row/column, remove it from that row/column outside the block |

`renew_impossibles` (called after `check`) sets each open cell's `@impossibles` to the complement of its `@possibles`.

### Puzzle input format

Each puzzle is defined as 9 strings of 9 digits. `0` = unknown. Difficulty variants (初級/中級/最高級/朝日新聞) are stored as `raw` cells (not executed by default) and can be activated by changing a cell to `ruby`.
