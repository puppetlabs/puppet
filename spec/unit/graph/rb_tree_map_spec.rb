#!/usr/bin/env ruby

require 'spec_helper'

require 'puppet/graph'

describe Puppet::Graph::RbTreeMap do
  describe "#push" do
    it "should allow a new element to be added" do
      subject[5] = 'foo'
      expect(subject.size).to eq(1)

      expect(subject[5]).to eq('foo')
    end

    it "should replace the old value if the key is in tree already" do
      subject[0] = 10
      subject[0] = 20

      expect(subject[0]).to eq(20)
      expect(subject.size).to eq(1)
    end

    it "should be able to add a large number of elements" do
      (1..1000).each {|i| subject[i] = i.to_s}

      expect(subject.size).to eq(1000)
    end

    it "should create a root node if the tree was empty" do
      expect(subject.instance_variable_get(:@root)).to be_nil

      subject[5] = 'foo'

      expect(subject.instance_variable_get(:@root)).to be_a(Puppet::Graph::RbTreeMap::Node)
    end
  end

  describe "#size" do
    it "should be 0 for en empty tree" do
      expect(subject.size).to eq(0)
    end

    it "should correctly report the size for a non-empty tree" do
      (1..10).each {|i| subject[i] = i.to_s}

      expect(subject.size).to eq(10)
    end
  end

  describe "#has_key?" do
    it "should be true if the tree contains the key" do
      subject[1] = 2

      expect(subject).to be_has_key(1)
    end

    it "should be true if the tree contains the key and its value is nil" do
      subject[0] = nil

      expect(subject).to be_has_key(0)
    end

    it "should be false if the tree does not contain the key" do
      subject[1] = 2

      expect(subject).not_to be_has_key(2)
    end

    it "should be false if the tree is empty" do
      expect(subject).not_to be_has_key(5)
    end
  end

  describe "#get" do
    it "should return the value at the key" do
      subject[1] = 2
      subject[3] = 4

      expect(subject.get(1)).to eq(2)
      expect(subject.get(3)).to eq(4)
    end

    it "should return nil if the tree is empty" do
      expect(subject[1]).to be_nil
    end

    it "should return nil if the key is not in the tree" do
      subject[1] = 2

      expect(subject[3]).to be_nil
    end

    it "should return nil if the value at the key is nil" do
      subject[1] = nil

      expect(subject[1]).to be_nil
    end
  end

  describe "#min_key" do
    it "should return the smallest key in the tree" do
      [4,8,12,3,6,2,-4,7].each do |i|
        subject[i] = i.to_s
      end

      expect(subject.min_key).to eq(-4)
    end

    it "should return nil if the tree is empty" do
      expect(subject.min_key).to be_nil
    end
  end

  describe "#max_key" do
    it "should return the largest key in the tree" do
      [4,8,12,3,6,2,-4,7].each do |i|
        subject[i] = i.to_s
      end

      expect(subject.max_key).to eq(12)
    end

    it "should return nil if the tree is empty" do
      expect(subject.max_key).to be_nil
    end
  end

  describe "#delete" do
    before :each do
      subject[1] = '1'
      subject[0] = '0'
      subject[2] = '2'
    end

    it "should return the value at the key deleted" do
      expect(subject.delete(0)).to eq('0')
      expect(subject.delete(1)).to eq('1')
      expect(subject.delete(2)).to eq('2')
      expect(subject.size).to eq(0)
    end

    it "should be able to delete the last node" do
      tree = described_class.new
      tree[1] = '1'

      expect(tree.delete(1)).to eq('1')
      expect(tree).to be_empty
    end

    it "should be able to delete the root node" do
      expect(subject.delete(1)).to eq('1')

      expect(subject.size).to eq(2)

      expect(subject.to_hash).to eq({
        :node => {
          :key => 2,
          :value => '2',
          :color => :black,
        },
        :left => {
          :node => {
            :key => 0,
            :value => '0',
            :color => :red,
          }
        }
      })
    end

    it "should be able to delete the left child" do
      expect(subject.delete(0)).to eq('0')

      expect(subject.size).to eq(2)

      expect(subject.to_hash).to eq({
        :node => {
          :key => 2,
          :value => '2',
          :color => :black,
        },
        :left => {
          :node => {
            :key => 1,
            :value => '1',
            :color => :red,
          }
        }
      })
    end

    it "should be able to delete the right child" do
      expect(subject.delete(2)).to eq('2')

      expect(subject.size).to eq(2)

      expect(subject.to_hash).to eq({
        :node => {
          :key => 1,
          :value => '1',
          :color => :black,
        },
        :left => {
          :node => {
            :key => 0,
            :value => '0',
            :color => :red,
          }
        }
      })
    end

    it "should be able to delete the left child if it is a subtree" do
      (3..6).each {|i| subject[i] = i.to_s}

      expect(subject.delete(1)).to eq('1')

      expect(subject.to_hash).to eq({
        :node => {
          :key => 5,
          :value => '5',
          :color => :black,
        },
        :left => {
          :node => {
            :key => 3,
            :value => '3',
            :color => :red,
          },
          :left => {
            :node => {
              :key => 2,
              :value => '2',
              :color => :black,
            },
            :left => {
              :node => {
                :key => 0,
                :value => '0',
                :color => :red,
              },
            },
          },
          :right => {
            :node => {
              :key => 4,
              :value => '4',
              :color => :black,
            },
          },
        },
        :right => {
          :node => {
            :key => 6,
            :value => '6',
            :color => :black,
          },
        },
      })
    end

    it "should be able to delete the right child if it is a subtree" do
      (3..6).each {|i| subject[i] = i.to_s}

      expect(subject.delete(5)).to eq('5')

      expect(subject.to_hash).to eq({
        :node => {
          :key => 3,
          :value => '3',
          :color => :black,
        },
        :left => {
          :node => {
            :key => 1,
            :value => '1',
            :color => :red,
          },
          :left => {
            :node => {
              :key => 0,
              :value => '0',
              :color => :black,
            },
          },
          :right => {
            :node => {
              :key => 2,
              :value => '2',
              :color => :black,
            },
          },
        },
        :right => {
          :node => {
            :key => 6,
            :value => '6',
            :color => :black,
          },
          :left => {
            :node => {
              :key => 4,
              :value => '4',
              :color => :red,
            },
          },
        },
      })
    end

    it "should return nil if the tree is empty" do
      tree = described_class.new

      expect(tree.delete(14)).to be_nil

      expect(tree.size).to eq(0)
    end

    it "should return nil if the key is not in the tree" do
      (0..4).each {|i| subject[i] = i.to_s}

      expect(subject.delete(2.5)).to be_nil
      expect(subject.size).to eq(5)
    end

    it "should return nil if the key is larger than the maximum key" do
      expect(subject.delete(100)).to be_nil
      expect(subject.size).to eq(3)
    end

    it "should return nil if the key is smaller than the minimum key" do
      expect(subject.delete(-1)).to be_nil
      expect(subject.size).to eq(3)
    end
  end

  describe "#empty?" do
    it "should return true if the tree is empty" do
      expect(subject).to be_empty
    end

    it "should return false if the tree is not empty" do
      subject[5] = 10

      expect(subject).not_to be_empty
    end
  end

  describe "#delete_min" do
    it "should delete the smallest element of the tree" do
      (1..15).each {|i| subject[i] = i.to_s}

      expect(subject.delete_min).to eq('1')
      expect(subject.size).to eq(14)
    end

    it "should return nil if the tree is empty" do
      expect(subject.delete_min).to be_nil
    end
  end

  describe "#delete_max" do
    it "should delete the largest element of the tree" do
      (1..15).each {|i| subject[i] = i.to_s}

      expect(subject.delete_max).to eq('15')
      expect(subject.size).to eq(14)
    end

    it "should return nil if the tree is empty" do
      expect(subject.delete_max).to be_nil
    end
  end

  describe "#each" do
    it "should yield each pair in the tree in order if a block is provided" do
      # Insert in reverse to demonstrate they aren't being yielded in insertion order
      (1..5).to_a.reverse.each {|i| subject[i] = i.to_s}

      nodes = []
      subject.each do |key,value|
        nodes << [key,value]
      end

      expect(nodes).to eq((1..5).map {|i| [i, i.to_s]})
    end

    it "should do nothing if the tree is empty" do
      subject.each do |key,value|
        raise "each on an empty tree incorrectly yielded #{key}, #{value}"
      end
    end
  end

  describe "#isred" do
    it "should return true if the node is red" do
      node = Puppet::Graph::RbTreeMap::Node.new(1,2)
      node.color = :red

      expect(subject.send(:isred, node)).to eq(true)
    end

    it "should return false if the node is black" do
      node = Puppet::Graph::RbTreeMap::Node.new(1,2)
      node.color = :black

      expect(subject.send(:isred, node)).to eq(false)
    end

    it "should return false if the node is nil" do
      expect(subject.send(:isred, nil)).to eq(false)
    end
  end
end

describe Puppet::Graph::RbTreeMap::Node do
  let(:tree) { Puppet::Graph::RbTreeMap.new }
  let(:subject) { tree.instance_variable_get(:@root) }

  before :each do
    (1..3).each {|i| tree[i] = i.to_s}
  end

  describe "#red?" do
    it "should return true if the node is red" do
      subject.color = :red

      expect(subject).to be_red
    end

    it "should return false if the node is black" do
      subject.color = :black

      expect(subject).not_to be_red
    end
  end

  describe "#colorflip" do
    it "should switch the color of the node and its children" do
      expect(subject.color).to eq(:black)
      expect(subject.left.color).to eq(:black)
      expect(subject.right.color).to eq(:black)

      subject.colorflip

      expect(subject.color).to eq(:red)
      expect(subject.left.color).to eq(:red)
      expect(subject.right.color).to eq(:red)
    end
  end

  describe "#rotate_left" do
    it "should rotate the tree once to the left" do
      (4..7).each {|i| tree[i] = i.to_s}

      root = tree.instance_variable_get(:@root)

      root.rotate_left

      expect(tree.to_hash).to eq({
        :node => {
          :key => 6,
          :value => '6',
          :color => :black,
        },
        :left => {
          :node => {
            :key => 4,
            :value => '4',
            :color => :red,
          },
          :left => {
            :node => {
              :key => 2,
              :value => '2',
              :color => :black,
            },
            :left => {
              :node => {
                :key => 1,
                :value => '1',
                :color => :black,
              },
            },
            :right => {
              :node => {
                :key => 3,
                :value => '3',
                :color => :black,
              },
            },
          },
          :right => {
            :node => {
              :key => 5,
              :value => '5',
              :color => :black,
            },
          },
        },
        :right => {
          :node => {
            :key => 7,
            :value => '7',
            :color => :black,
          },
        },
      })
    end
  end

  describe "#rotate_right" do
    it "should rotate the tree once to the right" do
      (4..7).each {|i| tree[i] = i.to_s}

      root = tree.instance_variable_get(:@root)

      root.rotate_right

      expect(tree.to_hash).to eq({
        :node => {
          :key => 2,
          :value => '2',
          :color => :black,
        },
        :left => {
          :node => {
            :key => 1,
            :value => '1',
            :color => :black,
          },
        },
        :right => {
          :node => {
            :key => 4,
            :value => '4',
            :color => :red,
          },
          :left => {
            :node => {
              :key => 3,
              :value => '3',
              :color => :black,
            },
          },
          :right => {
            :node => {
              :key => 6,
              :value => '6',
              :color => :black,
            },
            :left => {
              :node => {
                :key => 5,
                :value => '5',
                :color => :black,
              },
            },
            :right => {
              :node => {
                :key => 7,
                :value => '7',
                :color => :black,
              },
            },
          },
        },
      })
    end
  end
end
