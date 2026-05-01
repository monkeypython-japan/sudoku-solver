# 数独を解く
# 9x9 のテーブルに　1-9の可能性を列挙したセルを格納。テーブルは行、列、ブロックでアクセスできる。ルールに従いセルの可能リストを削減し、全てのセルの可能リストの長さが1になるまで反復

require 'set'

module Util
    def compliment(set)
        return ( Set[1,2,3,4,5,6,7,8,9] - set )
    end
    module_function :compliment
end

class Cell
    def initialize(line=9, column=9, block=9)
        @possibles = Set[1,2,3,4,5,6,7,8,9]
        @snapshot = Set[]
        @impossibles
        @line = line
        @column = column
        @block = block
    end
    attr_accessor :line, :column, :block, :impossibles
    attr_reader :possibles

    def position
        [@line, @column, @block]
    end

    def fix(num)
        if n = fixed? then
            if n != num then
                puts "Error will set contradictory num. Cell.fix @possibles: #{@possibles} num:#{num}"
                raise RuntimeError
            end
        elsif @possibles.include?(num) then
            @possibles = Set[num]
        else
            puts "Error will set impossible num. Cell.fix @possibles: #{@possibles} num:#{num}"
            raise RuntimeError
        end
    end

    def remove(n)
        if fixed?
            return
        else
            @possibles.delete(n)
        end
    end

    def fixed? #return the bumber when it was fixed (means True) else return False
        if @possibles.length == 1 then
            return @possibles.to_a[0]
        else
            return false
        end
    end

    def open?
        return !fixed?
    end

    def take_snapshot
        @snapshot = @possibles.clone
    end

    def restore_snapshot
        @possibles = @snapshot.clone
    end

    def description
        s = ""
        s << "pos:#{position} "
        if self.fixed?
           s << "Fixed:#{@possibles.to_a[0]}  "
        else
            s << "possibles:#{@possibles} impossibles:#{@impossibles}  "
        end
        return s
    end
end

class CellList
    @@cache = {}

    def initialize(name, cells)
        @cells = Array.new(cells) #Make shallow copy
        @name = name
        @@cache[name]=self
    end

    attr_reader :name, :cells

    def self.cellList(name)
        #check cashe
        if @@cache.key?(name) then
            return @@cache[name]
        else
            return nil
        end
    end

    def remove(n)
        @cells.each do |cell|
            cell.remove(n)
        end
    end

    def fix_with_array(nums)
        if nums.length != 9 then
            raise RuntimeError
        else
            nums.each_index do |i|
                @cells[i].fix(nums[i]) if nums[i] != 0 # 0 means not-fixed number
            end
        end
    end


    def fixed_nums
        fixed = Set.new()
        @cells.each do |c|
            if num = c.fixed? then
                fixed.add(num)
            end
        end
        return fixed
    end

    def open_count  # count up open cell
        c = 0
        @cells.each do |cell|
            c += 1 if not cell.fixed?
        end
        return c
    end

    def open_fixed_list
        ol = []
        fl = []
        @cells.each do |c|
            if c.fixed? then
                fl.push(c)
            else
                ol.push(c)
            end
        end
        return ol, fl
    end

    #
    # Create new CellList with Set operation
    #
    def new_with_add(cell_list)
        new_name = "#{@name}_PLUS_#{cell_list.name}"
        new_cells = @cells + cell_list.cells
        return CellList.new(new_name, new_cells)
    end

    def new_with_subtract(cell_list)
        new_name = "#{@name}_MINUS_#{cell_list.name}"
        new_cells = @cells - cell_list.cells
        return CellList.new(new_name, new_cells)
    end

    def new_with_cross(cell_list)
        new_name = "#{@name}_CROSS_#{cell_list.name}"
        new_cells = @cells.intersection(cell_list.cells)
        return CellList.new(new_name, new_cells)
    end

    #
    #  Level 0 method
    #
    def check # check if this celllist has uniq possible and make the celllist keeping rule.
        @cells.each do |c|
            # check if the cell has uniq possible
            my_possibles = c.possibles
            other_possibles = Set.new()
            @cells.each do |cc|
                other_possibles.merge(cc.possibles) if cc != c
            end
            my_possibles.each do |num|
                if !other_possibles.include?(num) then
                    c.fix(num)
                    break
                end
            end
            # if the cell was fixed then remove the num form other cells's possibles
            if n = c.fixed? then
                remove(n)
            end
        end
    end

    #
    #  Level 1 method
    #
    def cell_count_include_impossible(n)
        c=0
        @cells.each do |cell|
            c +=1 if cell.open? and cell.impossibles.include?(n)
        end
        return c
    end

    def found_uniq_possible_numbers
        # この Celllist で可能な Cell が唯一となる数を求める。
        # この Celllist でオープンな Cell の数　on を求める
        # 候補 n (Celllist内でfix された数は除外)を impossibles に含む Cell の数を数える
        # この数が on-1 となるものが求める可能なCellが唯一となる数 un
        # あれば un なければ 0 を返す
        #　   => un を可能リストに含む　Cell の値を　n とする
        un = Set.new()
        fns = fixed_nums
        open_count = 9 - fns.length
        target_count = open_count - 1
        candidates = Set[1,2,3,4,5,6,7,8,9] - fns
        candidates.each do |n|
            ccinc = cell_count_include_impossible(n)
            if ccinc == target_count then
                un.add(n)
            end
        end
        return un
    end

    def cells_with_possible(n)
        cl = []
        @cells.each do |c|
            cl.push(c) if c.possibles.include?(n)
        end
        return cl
    end

    def find_and_fix_uniq_possible_cell
        uniq_nums = found_uniq_possible_numbers
        uniq_nums.each do |n|
            possible_cells = cells_with_possible(n)
            if possible_cells.length == 1 then
                possible_cells[0].fix(n)
            else
                puts "CellList::find_and_fix_uniq_possible n:#{n} Possible cell が一つでない？"
                raise RuntimeError
            end
        end
    end

    #
    # Leval 2 method
    #
    def make_set_has_same_possibles
        possibles_count_dict = {}  #{ possibles => cell_count ...}
        @cells.each do |cell|
            next if cell.fixed?
            if possibles_count_dict.has_key?(cell.possibles) then
                possibles_count_dict[cell.possibles] += 1
            else
                possibles_count_dict[cell.possibles] = 1
            end
        end
        return possibles_count_dict #Hash of possibles => cell_count
    end

    def fixed_chairs(dict)
        fixed_chairs = Set.new()
        dict.each_pair do |possibles, count|
            fixed_chairs.add(possibles) if possibles.length == count
        end
        return fixed_chairs #Set of possibles
    end

    def fix_with_fixed_chair(fixed_chairs)
        return if fixed_chairs.length == 0
        @cells.each do |cell|
            next if cell.fixed?
            fixed_chairs.each do |chair|
                if cell.possibles != chair
                    cell.possibles.subtract(chair)
                    case cell.possibles.count
                    when 1
                        cell.fix(cell.possibles.to_a[0])
                    when 0
                        puts "CellList::fix_with_fixed_chair 可能性が空　 chare:#{chair}"
                        raise RuntimeError
                    else
                        # do nothing
                    end
                end
            end
        end
    end

    def find_and_fix_with_fixed_chair
        fix_with_fixed_chair(fixed_chairs(make_set_has_same_possibles))
    end

    #
    # Level 3 method
    #
    def find_nums_not_includes_in_any_possibles(candidate_set)
        founds = Set.new()
        candidate_set.each do |n|
            is_included = false
            @cells.each do |c|
                next if c.fixed?
                if c.possibles.include?(n) then
                    is_included = true
                    break
                end
            end
            founds.add(n) if !is_included
        end
        return founds
    end

    def remove_possibles(nums_set)
        return if nums_set.length == 0
        @cells.each do |cell|
            next if cell.fixed?
            cell.possibles.subtract( nums_set )
        end
    end

    def self.description
        puts @@cache.keys
    end

    def description
        s = ""
        s << @name + "\n"
        @cells.each do |cell|
            s << cell.description
        end
        return s
    end
end

class Table
    def initialize
        @table=[]
        @list =[]
        for l in 0..8 do
            line=[]
            for c in 0..8 do
                line.push(Cell.new(l,c))
            end
            @table.push(line)
            @list.concat(line) # make linear list
        end
    end

    def line(l)
        #CellList を返す
        name = "L"+l.to_s
        if cl = CellList.cellList(name) then
            return cl
        else
            return CellList.new(name,Array.new(@table[l]))
        end
    end

    def column(c)
        #CellList を返す
        name = "C"+c.to_s
        if cl = CellList.cellList(name) then
            return cl
        else
            cs = []
            for l in 0..8 do
                cs.push( @table[l][c] )
            end
            return CellList.new(name, cs)
        end
    end

    def block(b)
        #CellList を返す
        name = "B"+b.to_s
        if cl = CellList.cellList(name) then
            return cl
        else
            cs = []
            d = b.div(3)
            m = b.modulo(3)
            d3 = d*3
            m3 = m*3
            lr = d3..d3+2
            cr = m3..m3+2
            for l in lr do
                for c in cr do
                    cell = @table[l][c]
                    cell.block = b
                    cs.push(cell)
                end
            end
            return CellList.new(name, cs)
        end
    end

    def fix_with_matrix(mat)
        (0..8).each do |i|
            line(i).fix_with_array(mat[i])
        end
    end


    def open_cells
        oc = []
        @list.each {|c| oc.push(c) if !c.fixed?}
        return oc
    end

    def count_of_open_cell
        return open_cells.length
    end

    def check_once
        (0..8).each do |i|
            line(i).check
            column(i).check
            block(i).check
        end
    end

    #
    # Level 0 method
    #
    def check
        last_oc = 0
        until (current = count_of_open_cell) == last_oc
            last_oc = current
            check_once
        end
        renew_impossibles
        return current
    end

    def renew_impossibles
        @list.each do |cell|
            if !cell.fixed? then
                cell.impossibles = Util.compliment(cell.possibles)
            end
        end
    end

    #
    # Level 1 method
    #
    def find_and_fix_uniq_possible
        (0..8).each do |n|
            line(n).find_and_fix_uniq_possible_cell
            column(n).find_and_fix_uniq_possible_cell
            block(n).find_and_fix_uniq_possible_cell
        end
    end

    #
    # Level 2 method
    #
    def find_and_fix_with_fixed_chair
        (0..8).each do |n|
            line(n).find_and_fix_with_fixed_chair
            column(n).find_and_fix_with_fixed_chair
            block(n).find_and_fix_with_fixed_chair
        end
    end

    #
    # Level 3 method
    #
    def fix_with_cross_block
        @list.each do |cell|
            next if cell.fixed?
            l,c,b = cell.position; line = line(l); column = column(c); block = block(b)
            block_minus_line = block.new_with_subtract(line)
            block_minus_column = block.new_with_subtract(column)
            #
            uniqes_in_block = block_minus_line.find_nums_not_includes_in_any_possibles(cell.possibles)
            rest_cells = line.new_with_subtract(block)
            rest_cells.remove_possibles(uniqes_in_block)
            #
            uniqes_in_block = block_minus_column.find_nums_not_includes_in_any_possibles(cell.possibles)
            rest_cells = column.new_with_subtract(block)
            rest_cells.remove_possibles(uniqes_in_block)
        end
    end

    def solve
        check
        last_count = 81
        current_count = count_of_open_cell
        until current_count == last_count or current_count == 0
            find_and_fix_uniq_possible
            check
            find_and_fix_with_fixed_chair
            check
            fix_with_cross_block
            check
            last_count = current_count
            current_count = count_of_open_cell
            print "Table::solve last_count:#{last_count} current_count:#{current_count}\n"
        end
        return current_count
    end

    def combination
        comb = 1
        open_cells.each do |c|
            comb *= c.possibles.length
        end
        return comb
    end

    def description
        s = ""
        s << "Open cell:#{count_of_open_cell}"
        (0..8).each {|i| s << line(i).description + "\n"}
    end

    def display
        out = ""
        nl = "\n"
        num_line = "    0   1   2   3   4   5   6   7   8 "
        sep_line_0 = "  +---+---+---+---+---+---+---+---+---+"
        sep_line_1 = "  o---+---+---o---+---+---o---+---+---o"
        #
        out << "Open cell:#{count_of_open_cell}"+nl
        out << (num_line +nl+sep_line_1+nl)
        ln = 0
        @table.each do |line|
            out << "#{ln} "; ln += 1
            line.each do |cell|
                if num = cell.fixed? then
                    out << "| #{num} "
                else
                    out << "|   "
                end
            end
            out << "|" + nl
            if ln.modulo(3)==0 then
                out << (sep_line_1 + nl)
            else
                out << (sep_line_0 + nl)
            end
        end
        return out
    end
end

class TableLoader
  def initialize
  end

  def convert_line(str) # input "00120004"
    if str.length != 9 then
      puts "Input length isn't 8 #{str}"
      raise RuntimeError
    end
    cl = str.chars
    nl = []
    cl.each {|c| nl.push(c.to_i)}
    return nl
  end

  def read(str_matrix) #input ["10003600","00120004"..] Array of 8 strings
    mat = []
    str_matrix.each {|s| mat.push(convert_line(s))}
    return mat #output [[1,0,0,0,3,6,0,0],[0,0,1,2,0,0,0,4],...]
  end
end

# パイプ経由（stdin）でパズルを受け取るか、組み込みパズルを使う
if $stdin.isatty
  # 端末から直接起動: 組み込みパズル（朝日新聞 6つ星）を使用
  stable = [
    "200050001",
    "007100030",
    "040000800",
    "000300070",
    "100000009",
    "050008000",
    "003000040",
    "080004200",
    "600090005"
  ]
else
  # パイプ入力: sudoku_reader.py の出力（9文字×9行）を読み込む
  stable = $stdin.read.split("\n").map(&:strip).reject(&:empty?).first(9)
  if stable.length != 9 || stable.any? { |s| s.length != 9 }
    $stderr.puts "エラー: 9文字×9行の入力が必要です"
    exit 1
  end
end

input_table = TableLoader.new.read(stable)
table = Table.new
table.fix_with_matrix(input_table)
print table.display

r = table.solve
if r == 0 then
    print "Solved!\n"
else
    print "Not solved.\n"
end
print "Rest combination:#{table.combination}\n"
print table.display
