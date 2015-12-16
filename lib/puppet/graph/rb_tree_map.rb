# Algorithms and Containers project is Copyright (c) 2009 Kanwei Li
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# A RbTreeMap is a map that is stored in sorted order based on the order of its keys. This ordering is
# determined by applying the function <=> to compare the keys. No duplicate values for keys are allowed,
# so duplicate values are overwritten.
#
# A major advantage of RBTreeMap over a Hash is the fact that keys are stored in order and can thus be
# iterated over in order. This is useful for many datasets.
#
# The implementation is adapted from Robert Sedgewick's Left Leaning Red-Black Tree implementation,
# which can be found at https://www.cs.princeton.edu/~rs/talks/LLRB/Java/RedBlackBST.java
#
# Most methods have O(log n) complexity.

class Puppet::Graph::RbTreeMap
  include Enumerable

  attr_reader :size

  alias_method :length, :size

  # Create and initialize a new empty TreeMap.
  def initialize
    @root = nil
    @size = 0
  end

  # Insert an item with an associated key into the TreeMap, and returns the item inserted
  #
  # Complexity: O(log n)
  #
  # map = Containers::TreeMap.new
  # map.push("MA", "Massachusetts") #=> "Massachusetts"
  # map.get("MA") #=> "Massachusetts"
  def push(key, value)
    @root = insert(@root, key, value)
    @root.color = :black
    value
  end
  alias_method :[]=, :push

  # Return true if key is found in the TreeMap, false otherwise
  #
  # Complexity: O(log n)
  #
  #   map = Containers::TreeMap.new
  #   map.push("MA", "Massachusetts")
  #   map.push("GA", "Georgia")
  #   map.has_key?("GA") #=> true
  #   map.has_key?("DE") #=> false
  def has_key?(key)
    !get_recursive(@root, key).nil?
  end

  # Return the item associated with the key, or nil if none found.
  #
  # Complexity: O(log n)
  #
  #   map = Containers::TreeMap.new
  #   map.push("MA", "Massachusetts")
  #   map.push("GA", "Georgia")
  #   map.get("GA") #=> "Georgia"
  def get(key)
    node = get_recursive(@root, key)
    node ? node.value : nil
    node.value if node
  end
  alias_method :[], :get

  # Return the smallest key in the map.
  #
  # Complexity: O(log n)
  #
  #   map = Containers::TreeMap.new
  #   map.push("MA", "Massachusetts")
  #   map.push("GA", "Georgia")
  #   map.min_key #=> "GA"
  def min_key
    @root.nil? ? nil : min_recursive(@root).key
  end

  # Return the largest key in the map.
  #
  # Complexity: O(log n)
  #
  #   map = Containers::TreeMap.new
  #   map.push("MA", "Massachusetts")
  #   map.push("GA", "Georgia")
  #   map.max_key #=> "MA"
  def max_key
    @root.nil? ? nil : max_recursive(@root).key
  end

  # Deletes the item and key if it's found, and returns the item. Returns nil
  # if key is not present.
  #
  # Complexity: O(log n)
  #
  #   map = Containers::TreeMap.new
  #   map.push("MA", "Massachusetts")
  #   map.push("GA", "Georgia")
  #   map.delete("MA") #=> "Massachusetts"
  def delete(key)
    result = nil
    if @root
      return unless has_key? key
      @root, result = delete_recursive(@root, key)
      @root.color = :black if @root
      @size -= 1
    end
    result
  end

  # Returns true if the tree is empty, false otherwise
  def empty?
    @root.nil?
  end

  # Deletes the item with the smallest key and returns the item. Returns nil
  # if key is not present.
  #
  # Complexity: O(log n)
  #
  #   map = Containers::TreeMap.new
  #   map.push("MA", "Massachusetts")
  #   map.push("GA", "Georgia")
  #   map.delete_min #=> "Massachusetts"
  #   map.size #=> 1
  def delete_min
    result = nil
    if @root
      @root, result = delete_min_recursive(@root)
      @root.color = :black if @root
      @size -= 1
    end
    result
  end

  # Deletes the item with the largest key and returns the item. Returns nil
  # if key is not present.
  #
  # Complexity: O(log n)
  #
  #   map = Containers::TreeMap.new
  #   map.push("MA", "Massachusetts")
  #   map.push("GA", "Georgia")
  #   map.delete_max #=> "Georgia"
  #   map.size #=> 1
  def delete_max
    result = nil
    if @root
      @root, result = delete_max_recursive(@root)
      @root.color = :black if @root
      @size -= 1
    end
    result
  end

  # Yields [key, value] pairs in order by key.
  def each(&blk)
    recursive_yield(@root, &blk)
  end

  def first
    return nil unless @root
    node = min_recursive(@root)
    [node.key, node.value]
  end

  def last
    return nil unless @root
    node = max_recursive(@root)
    [node.key, node.value]
  end

  def to_hash
    @root ? @root.to_hash : {}
  end

  class Node # :nodoc: all
    attr_accessor :color, :key, :value, :left, :right
    def initialize(key, value)
      @key = key
      @value = value
      @color = :red
      @left = nil
      @right = nil
    end

    def to_hash
      h = {
        :node => {
          :key => @key,
          :value => @value,
          :color => @color,
        }
      }
      h.merge!(:left => left.to_hash) if @left
      h.merge!(:right => right.to_hash) if @right
      h
    end

    def red?
      @color == :red
    end

    def colorflip
      @color       = @color == :red       ? :black : :red
      @left.color  = @left.color == :red  ? :black : :red
      @right.color = @right.color == :red ? :black : :red
    end

    def rotate_left
      r = @right
      r_key, r_value = r.key, r.value
      b = r.left
      r.left = @left
      @left = r
      @right = r.right
      r.right = b
      r.color, r.key, r.value = :red, @key, @value
      @key, @value = r_key, r_value
      self
    end

    def rotate_right
      l = @left
      l_key, l_value = l.key, l.value
      b = l.right
      l.right = @right
      @right = l
      @left = l.left
      l.left = b
      l.color, l.key, l.value = :red, @key, @value
      @key, @value = l_key, l_value
      self
    end

    def move_red_left
      colorflip
      if (@right.left && @right.left.red?)
        @right.rotate_right
        rotate_left
        colorflip
      end
      self
    end

    def move_red_right
      colorflip
      if (@left.left && @left.left.red?)
        rotate_right
        colorflip
      end
      self
    end

    def fixup
      rotate_left if @right && @right.red?
      rotate_right if (@left && @left.red?) && (@left.left && @left.left.red?)
      colorflip if (@left && @left.red?) && (@right && @right.red?)

      self
    end
  end

  private

  def recursive_yield(node, &blk)
    return unless node
    recursive_yield(node.left, &blk)
    yield node.key, node.value
    recursive_yield(node.right, &blk)
  end

  def delete_recursive(node, key)
    if (key <=> node.key) == -1
      node.move_red_left if ( !isred(node.left) && !isred(node.left.left) )
      node.left, result = delete_recursive(node.left, key)
    else
      node.rotate_right if isred(node.left)
      if ( ( (key <=> node.key) == 0) && node.right.nil? )
        return nil, node.value
      end
      if ( !isred(node.right) && !isred(node.right.left) )
        node.move_red_right
      end
      if (key <=> node.key) == 0
        result = node.value
        min_child = min_recursive(node.right)
        node.value = min_child.value
        node.key = min_child.key
        node.right = delete_min_recursive(node.right).first
      else
        node.right, result = delete_recursive(node.right, key)
      end
    end
    return node.fixup, result
  end

  def delete_min_recursive(node)
    if node.left.nil?
      return nil, node.value
    end
    if ( !isred(node.left) && !isred(node.left.left) )
      node.move_red_left
    end
    node.left, result = delete_min_recursive(node.left)

    return node.fixup, result
  end

  def delete_max_recursive(node)
    if (isred(node.left))
      node = node.rotate_right
    end
    return nil, node.value if node.right.nil?
    if ( !isred(node.right) && !isred(node.right.left) )
      node.move_red_right
    end
    node.right, result = delete_max_recursive(node.right)

    return node.fixup, result
  end

  def get_recursive(node, key)
    return nil if node.nil?
    case key <=> node.key
    when  0 then return node
    when -1 then return get_recursive(node.left, key)
    when  1 then return get_recursive(node.right, key)
    end
  end

  def min_recursive(node)
    return node if node.left.nil?

    min_recursive(node.left)
  end

  def max_recursive(node)
    return node if node.right.nil?

    max_recursive(node.right)
  end

  def insert(node, key, value)
    unless node
      @size += 1
      return Node.new(key, value)
    end

    case key <=> node.key
    when  0 then node.value = value
    when -1 then node.left = insert(node.left, key, value)
    when  1 then node.right = insert(node.right, key, value)
    end

    node.rotate_left if (node.right && node.right.red?)
    node.rotate_right if (node.left && node.left.red? && node.left.left && node.left.left.red?)
    node.colorflip if (node.left && node.left.red? && node.right && node.right.red?)
    node
  end

  def isred(node)
    return false if node.nil?

    node.color == :red
  end
end
