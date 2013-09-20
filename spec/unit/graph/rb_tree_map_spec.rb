#!/usr/bin/env ruby

require 'spec_helper'

require 'puppet/graph'

describe Puppet::Graph::RbTreeMap do
  describe "#push" do
    it "should allow a new element to be added" do
      subject[5] = 'foo'
      subject.size.should == 1

      subject[5].should == 'foo'
    end

    it "should replace the old value if the key is in tree already" do
      subject[0] = 10
      subject[0] = 20

      subject[0].should == 20
      subject.size.should == 1
    end

    it "should be able to add a large number of elements" do
      (1..1000).each {|i| subject[i] = i.to_s}

      subject.size.should == 1000
    end

    it "should create a root node if the tree was empty" do
      subject.instance_variable_get(:@root).should be_nil

      subject[5] = 'foo'

      subject.instance_variable_get(:@root).should be_a(Puppet::Graph::RbTreeMap::Node)
    end
  end

  describe "#size" do
    it "should be 0 for en empty tree" do
      subject.size.should == 0
    end

    it "should correctly report the size for a non-empty tree" do
      (1..10).each {|i| subject[i] = i.to_s}

      subject.size.should == 10
    end
  end

  describe "#has_key?" do
    it "should be true if the tree contains the key" do
      subject[1] = 2

      subject.should be_has_key(1)
    end

    it "should be true if the tree contains the key and its value is nil" do
      subject[0] = nil

      subject.should be_has_key(0)
    end

    it "should be false if the tree does not contain the key" do
      subject[1] = 2

      subject.should_not be_has_key(2)
    end

    it "should be false if the tree is empty" do
      subject.should_not be_has_key(5)
    end
  end

  describe "#get" do
    it "should return the value at the key" do
      subject[1] = 2
      subject[3] = 4

      subject.get(1).should == 2
      subject.get(3).should == 4
    end

    it "should return nil if the tree is empty" do
      subject[1].should be_nil
    end

    it "should return nil if the key is not in the tree" do
      subject[1] = 2

      subject[3].should be_nil
    end

    it "should return nil if the value at the key is nil" do
      subject[1] = nil

      subject[1].should be_nil
    end
  end

  describe "#min_key" do
    it "should return the smallest key in the tree" do
      [4,8,12,3,6,2,-4,7].each do |i|
        subject[i] = i.to_s
      end

      subject.min_key.should == -4
    end

    it "should return nil if the tree is empty" do
      subject.min_key.should be_nil
    end
  end

  describe "#max_key" do
    it "should return the largest key in the tree" do
      [4,8,12,3,6,2,-4,7].each do |i|
        subject[i] = i.to_s
      end

      subject.max_key.should == 12
    end

    it "should return nil if the tree is empty" do
      subject.max_key.should be_nil
    end
  end

  describe "#delete" do
    before :each do
      subject[1] = '1'
      subject[0] = '0'
      subject[2] = '2'
    end

    it "should return the value at the key deleted" do
      subject.delete(0).should == '0'
      subject.delete(1).should == '1'
      subject.delete(2).should == '2'
      subject.size.should == 0
    end

    it "should be able to delete the last node" do
      tree = described_class.new
      tree[1] = '1'

      tree.delete(1).should == '1'
      tree.should be_empty
    end

    it "should be able to delete the root node" do
      subject.delete(1).should == '1'

      subject.size.should == 2

      subject.to_hash.should == {
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
      }
    end

    it "should be able to delete the left child" do
      subject.delete(0).should == '0'

      subject.size.should == 2

      subject.to_hash.should == {
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
      }
    end

    it "should be able to delete the right child" do
      subject.delete(2).should == '2'

      subject.size.should == 2

      subject.to_hash.should == {
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
      }
    end

    it "should be able to delete the left child if it is a subtree" do
      (3..6).each {|i| subject[i] = i.to_s}

      subject.delete(1).should == '1'

      subject.to_hash.should == {
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
      }
    end

    it "should be able to delete the right child if it is a subtree" do
      (3..6).each {|i| subject[i] = i.to_s}

      subject.delete(5).should == '5'

      subject.to_hash.should == {
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
      }
    end

    it "should return nil if the tree is empty" do
      tree = described_class.new

      tree.delete(14).should be_nil

      tree.size.should == 0
    end

    it "should return nil if the key is not in the tree" do
      (0..4).each {|i| subject[i] = i.to_s}

      subject.delete(2.5).should be_nil
      subject.size.should == 5
    end

    it "should return nil if the key is larger than the maximum key" do
      subject.delete(100).should be_nil
      subject.size.should == 3
    end

    it "should return nil if the key is smaller than the minimum key" do
      subject.delete(-1).should be_nil
      subject.size.should == 3
    end
  end

  describe "#empty?" do
    it "should return true if the tree is empty" do
      subject.should be_empty
    end

    it "should return false if the tree is not empty" do
      subject[5] = 10

      subject.should_not be_empty
    end
  end

  describe "#delete_min" do
    it "should delete the smallest element of the tree" do
      (1..15).each {|i| subject[i] = i.to_s}

      subject.delete_min.should == '1'
      subject.size.should == 14
    end

    it "should return nil if the tree is empty" do
      subject.delete_min.should be_nil
    end
  end

  describe "#delete_max" do
    it "should delete the largest element of the tree" do
      (1..15).each {|i| subject[i] = i.to_s}

      subject.delete_max.should == '15'
      subject.size.should == 14
    end

    it "should return nil if the tree is empty" do
      subject.delete_max.should be_nil
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

      nodes.should == (1..5).map {|i| [i, i.to_s]}
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

      subject.send(:isred, node).should == true
    end

    it "should return false if the node is black" do
      node = Puppet::Graph::RbTreeMap::Node.new(1,2)
      node.color = :black

      subject.send(:isred, node).should == false
    end

    it "should return false if the node is nil" do
      subject.send(:isred, nil).should == false
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

      subject.should be_red
    end

    it "should return false if the node is black" do
      subject.color = :black

      subject.should_not be_red
    end
  end

  describe "#colorflip" do
    it "should switch the color of the node and its children" do
      subject.color.should == :black
      subject.left.color.should == :black
      subject.right.color.should == :black

      subject.colorflip

      subject.color.should == :red
      subject.left.color.should == :red
      subject.right.color.should == :red
    end
  end

  describe "#rotate_left" do
    it "should rotate the tree once to the left" do
      (4..7).each {|i| tree[i] = i.to_s}

      root = tree.instance_variable_get(:@root)

      root.rotate_left

      tree.to_hash.should == {
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
      }
    end
  end

  describe "#rotate_right" do
    it "should rotate the tree once to the right" do
      (4..7).each {|i| tree[i] = i.to_s}

      root = tree.instance_variable_get(:@root)

      root.rotate_right

      tree.to_hash.should == {
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
      }
    end
  end
end
