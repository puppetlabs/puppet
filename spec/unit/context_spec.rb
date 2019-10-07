require 'spec_helper'

describe Puppet::Context do
  let(:context) { Puppet::Context.new({ :testing => "value" }) }

  describe "with additional context" do
    before :each do
      context.push("a" => 1)
    end

    it "allows rebinding values in a nested context" do
      inner = nil
      context.override("a" => 2) do
        inner = context.lookup("a")
      end

      expect(inner).to eq(2)
    end

    it "outer bindings are available in an overridden context" do
      inner_a = nil
      inner_b = nil
      context.override("b" => 2) do
        inner_a = context.lookup("a")
        inner_b = context.lookup("b")
      end

      expect(inner_a).to eq(1)
      expect(inner_b).to eq(2)
    end

    it "overridden bindings do not exist outside of the override" do
      context.override("a" => 2) do
      end

      expect(context.lookup("a")).to eq(1)
    end

    it "overridden bindings do not exist outside of the override even when leaving via an error" do
      begin
        context.override("a" => 2) do
          raise "this should still cause the bindings to leave"
        end
      rescue
      end

      expect(context.lookup("a")).to eq(1)
    end
  end

  context "a rollback" do
    it "returns to the mark" do
      context.push("a" => 1)
      context.mark("start")
      context.push("a" => 2)
      context.push("a" => 3)
      context.pop

      context.rollback("start")

      expect(context.lookup("a")).to eq(1)
    end

    it "rolls back to the mark across a scoped override" do
      context.push("a" => 1)
      context.mark("start")
      context.override("a" => 3) do

        context.rollback("start")

        expect(context.lookup("a")).to eq(1)
      end
      expect(context.lookup("a")).to eq(1)
    end

    it "fails to rollback to an unknown mark" do
      expect do
        context.rollback("unknown")
      end.to raise_error(Puppet::Context::UnknownRollbackMarkError)
    end

    it "does not allow the same mark to be set twice" do
      context.mark("duplicate")
      expect do
        context.mark("duplicate")
      end.to raise_error(Puppet::Context::DuplicateRollbackMarkError)
    end
  end

  context "with multiple threads" do
    it "a value pushed in another thread is not seen in the original thread" do
      context.push(a: 1)
      t = Thread.new do
        context.push(a: 2, b: 5)
      end
      t.join

      expect(context.lookup(:a)).to eq(1)
      expect{ context.lookup(:b) }.to raise_error(Puppet::Context::UndefinedBindingError)
    end

    it "pops on a different thread do not interfere" do
      context.push(a: 1)
      t = Thread.new do
        context.pop
      end
      t.join

      # Raises exception if the binding we pushed has already been popped
      context.pop
    end

    it "a mark in one thread is not seen in another thread" do
      t = Thread.new do
        context.push(b: 2)
        context.mark('point b')
      end
      t.join

      expect { context.rollback('point b') }.to raise_error(Puppet::Context::UnknownRollbackMarkError)
    end
  end
end


describe Puppet::Context::EmptyStack do
  let(:empty_stack) { Puppet::Context::EmptyStack.new }

  it "raises undefined binding on lookup" do
    expect { empty_stack.lookup("a") }.to raise_error(Puppet::Context::UndefinedBindingError)
  end

  it "calls a provided block for a default value when none is found" do
    expect(empty_stack.lookup("a") { "default" }).to eq("default")
  end

  it "raises an error when trying to pop" do
    expect { empty_stack.pop }.to raise_error(Puppet::Context::StackUnderflow)
  end

  it "returns a stack when something is pushed" do
    stack = empty_stack.push(a: 1)
    expect(stack).to be_a(Puppet::Context::Stack)
  end

  it "returns a new stack with no bindings when pushed nil" do
    stack = empty_stack.push(nil)
    expect(stack).not_to be(empty_stack)
    expect(stack.pop).to be(empty_stack)
  end
end

describe Puppet::Context::Stack do
  let(:empty_stack) { Puppet::Context::EmptyStack.new }

  context "a stack with depth of 1" do
    let(:stack) { empty_stack.push(a: 1) }

    it "returns the empty stack when popped" do
      expect(stack.pop).to be(empty_stack)
    end

    it "calls a provided block for a default value when none is found" do
      expect(stack.lookup("a") { "default" }).to eq("default")
    end

    it "returns a new but equivalent stack when pushed nil" do
      stackier = stack.push(nil)
      expect(stackier).not_to be(stack)
      expect(stackier.pop).to be(stack)
      expect(stackier.bindings).to eq(stack.bindings)
    end
  end

  context "a stack with more than 1 element" do
    let(:level_one) { empty_stack.push(a: 1, c: 4) }
    let(:level_two) { level_one.push(b: 2, c: 3) }

    it "falls back to lower levels on lookup" do
      expect(level_two.lookup(:c)).to eq(3)
      expect(level_two.lookup(:a)).to eq(1)
      expect{ level_two.lookup(:d) }.to raise_error(Puppet::Context::UndefinedBindingError)
    end

    it "the parent is immutable" do
      expect(level_one.lookup(:c)).to eq(4)
      expect{ level_one.lookup(:b) }.to raise_error(Puppet::Context::UndefinedBindingError)
    end
  end

  context 'supports lazy entries' do
    it 'by evaluating a bound proc' do
      stack = empty_stack.push(a: lambda { || 'yay' })
      expect(stack.lookup(:a)).to eq('yay')
    end

    it 'by memoizing the bound value' do
      original = 'yay'
      stack = empty_stack.push(:a => lambda {|| tmp = original; original = 'no'; tmp})
      expect(stack.lookup(:a)).to eq('yay')
      expect(original).to eq('no')
      expect(stack.lookup(:a)).to eq('yay')
    end

    it 'the bound value is memoized only at the top level of the stack' do
      # I'm just characterizing the current behavior here

      original = 'yay'
      stack = empty_stack.push(:a => lambda {|| tmp = original; original = 'no'; tmp})
      stack_two = stack.push({})
      expect(stack.lookup(:a)).to eq('yay')
      expect(original).to eq('no')
      expect(stack.lookup(:a)).to eq('yay')
      expect(stack_two.lookup(:a)).to eq('no')
    end
  end
end
