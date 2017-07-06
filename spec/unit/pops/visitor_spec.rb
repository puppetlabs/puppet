#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::Visitor do
  describe "A visitor and a visitable in a configuration with min and max args set to 0" do
    class DuckProcessor
      def initialize
        @friend_visitor = Puppet::Pops::Visitor.new(self, "friend", 0, 0)
      end

      def hi(o, *args)
        @friend_visitor.visit(o, *args)
      end

      def friend_Duck(o)
        "Hi #{o.class}"
      end

      def friend_Numeric(o)
        "Howdy #{o.class}"
      end
    end

    class Duck
      include Puppet::Pops::Visitable
    end

    it "should select the expected method when there are no arguments" do
      duck = Duck.new
      duck_processor = DuckProcessor.new
      expect(duck_processor.hi(duck)).to eq("Hi Duck")
    end

    it "should fail if there are too many arguments" do
      duck = Duck.new
      duck_processor = DuckProcessor.new
      expect { duck_processor.hi(duck, "how are you?") }.to raise_error(/^Visitor Error: Too many.*/)
    end

    it "should select method for superclass" do
      duck_processor = DuckProcessor.new
      expect(duck_processor.hi(42)).to match(/Howdy (?:Fixnum|Integer)/)
    end

    it "should select method for superclass" do
      duck_processor = DuckProcessor.new
      expect(duck_processor.hi(42.0)).to eq("Howdy Float")
    end

    it "should fail if class not handled" do
      duck_processor = DuckProcessor.new
      expect { duck_processor.hi("wassup?") }.to raise_error(/Visitor Error: the configured.*/)
    end
  end

  describe "A visitor and a visitable in a configuration with min =1, and max args set to 2" do
    class DuckProcessor2
      def initialize
        @friend_visitor = Puppet::Pops::Visitor.new(self, "friend", 1, 2)
      end

      def hi(o, *args)
        @friend_visitor.visit(o, *args)
      end

      def friend_Duck(o, drink, eat="grain")
        "Hi #{o.class}, drink=#{drink}, eat=#{eat}"
      end
    end

    class Duck
      include Puppet::Pops::Visitable
    end

    it "should select the expected method when there are is one arguments" do
      duck = Duck.new
      duck_processor = DuckProcessor2.new
      expect(duck_processor.hi(duck, "water")).to eq("Hi Duck, drink=water, eat=grain")
    end

    it "should fail if there are too many arguments" do
      duck = Duck.new
      duck_processor = DuckProcessor2.new
      expect { duck_processor.hi(duck, "scotch", "soda", "peanuts") }.to raise_error(/^Visitor Error: Too many.*/)
    end

    it "should fail if there are too few arguments" do
      duck = Duck.new
      duck_processor = DuckProcessor2.new
      expect { duck_processor.hi(duck) }.to raise_error(/^Visitor Error: Too few.*/)
    end
  end
end
