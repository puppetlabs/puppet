require 'spec_helper'

describe Puppet::Context do
  let(:context) { Puppet::Context.new({ :testing => "value" }) }

  context "with the implicit test_helper.rb pushed context" do
    it "fails to lookup a value that does not exist" do
      expect { context.lookup("a") }.to raise_error(Puppet::Context::UndefinedBindingError)
    end

    it "calls a provided block for a default value when none is found" do
      expect(context.lookup("a") { "default" }).to eq("default")
    end

    it "behaves as if pushed a {} if you push nil" do
      context.push(nil)
      expect(context.lookup(:testing)).to eq("value")
      context.pop
    end

    it "fails if you try to pop off the top of the stack" do
      expect { context.pop }.to raise_error(Puppet::Context::StackUnderflow)
    end
  end

  describe "with additional context" do
    before :each do
      context.push("a" => 1)
    end

    it "holds values for later lookup" do
      expect(context.lookup("a")).to eq(1)
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

  context 'support lazy entries' do
    it 'by evaluating a bound proc' do
      result = nil
      context.override(:a => lambda {|| 'yay'}) do
        result = context.lookup(:a)
      end
      expect(result).to eq('yay')
    end

    it 'by memoizing the bound value' do
      result1 = nil
      result2 = nil
      original = 'yay'
      context.override(:a => lambda {|| tmp = original; original = 'no'; tmp}) do
        result1 = context.lookup(:a)
        result2 = context.lookup(:a)
      end
      expect(result1).to eq('yay')
      expect(original).to eq('no')
      expect(result2).to eq('yay')
    end
  end
end
