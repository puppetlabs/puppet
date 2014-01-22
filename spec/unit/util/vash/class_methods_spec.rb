require 'spec_helper'
require 'puppet/util/vash/class_methods'

describe Puppet::Util::Vash::ClassMethods do
  ClassMethods =  Puppet::Util::Vash::ClassMethods

  subject do
    Class.new do
      extend ClassMethods
      def self.to_s; 'TestClass'; end
    end
  end
  it { should respond_to :[] }

  describe "#[]" do

    let!(:obj) { mock('<Vash>') }
    let!(:subject) do
      Class.new do
        extend ClassMethods
        def self.to_s; 'TestClass'; end
      end
    end
    before(:each) do
      subject.expects(:new).once.with().returns(obj)
    end

    context "with no arguments" do
      it "should not raise errors" do
        expect { subject[] }.to_not raise_error
      end
      it "should return object created with new()" do
        subject[].should be obj
      end
    end

    context "#['a','A','b','B']" do
      let(:input) {['a', 'A', 'b', 'B']}
      it "should not raise errors, provided #replace_with_flat_array exists" do
        obj.stubs(:replace_with_flat_array)
        expect { subject[*input] }.to_not raise_error
      end
      it "should return hash = new() with hash.replace_with_flat_array called once" do
        obj.expects(:replace_with_flat_array).once.with(input)
        subject[*input].should be obj
      end
    end

    context "#[ [['a','A'], ['b','B']] ]" do
      let(:input) { [ ['a','A'], ['b','B'] ] }
      it "should not raise errors, provided #replace_with_item_array exists" do
        obj.stubs(:replace_with_item_array)
        expect { subject[input] }.to_not raise_error
      end
      it "should return obj = new() with obj.replace_with_item_array called once" do
        obj.expects(:replace_with_item_array).once.with(input)
        subject[input].should be obj
      end
    end

    context "#[ {'a'=>'A','b'=>'B'} ]" do
      let(:input) { {'a'=>'A','b'=>'B'} }
      it "should not raise errors, provided #repalce exists" do
        obj.stubs(:replace)
        expect { subject[input] }.to_not raise_error
      end
      it "should return obj = new() with obj.replace called once" do
        obj.expects(:replace).once.with(input)
        subject[input].should be obj
      end
    end

    context "#[:symbol]" do
      let(:input) { :symbol }
      it "should not raise errors by its own, provided #replace exists" do
        obj.stubs(:replace)
        Hash.stubs(:[]).with(input)
        expect { subject[input]}.to_not raise_error
      end
      it "Hash should raise ArgumentError with message 'odd number of arguments'" do
        obj.stubs(:replace)
        expect { subject[input] }.
          to raise_error ArgumentError, /odd number of arguments/
      end
      it "should return obj=new() with obj.replace(Hash[:symbol]) called once" do
        Hash.stubs(:[]).with(input)
        obj.expects(:replace).once.with(Hash[input])
        subject[input].should be obj
      end
    end
  end
end
