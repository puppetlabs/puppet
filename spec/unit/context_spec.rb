require 'spec_helper'

describe Puppet::Context do

  context "with the implicit test_helper.rb pushed context" do
    it "fails to lookup a value that does not exist" do
      expect { Puppet::Context.lookup("a") }.to raise_error(Puppet::Context::UndefinedBindingError)
    end

    it "calls a provided block for a default value when none is found" do
      expect(Puppet::Context.lookup("a") { "default" }).to eq("default")
    end

    it "behaves as if pushed a {} if you push nil" do
      Puppet::Context.push(nil)
      expect(Puppet::Context.lookup(:trusted_information)).to_not be_nil
      Puppet::Context.pop
    end

    it "fails if you try to pop off the top of the stack" do
      root = Puppet::Context.pop
      expect(root).to be_root
      expect { Puppet::Context.pop }.to raise_error(Puppet::Context::StackUnderflow)
      # TestHelper expects to have something to pop in its after_each_test() 
      Puppet::Context.push({})
    end

    it "protects the bindings table from casual access" do
      expect { Puppet::Context.push({}).table }.to raise_error(NoMethodError, /protected/)
      Puppet::Context.pop
    end
  end

  describe "with additional context" do
    before :each do
      Puppet::Context.push("a" => 1)
    end

    after :each do
      Puppet::Context.pop
    end

    it "holds values for later lookup" do
      expect(Puppet::Context.lookup("a")).to eq(1)
    end

    it "allows rebinding values in a nested context" do
      inner = nil
      Puppet::Context.override("a" => 2) do
        inner = Puppet::Context.lookup("a")
      end

      expect(inner).to eq(2)
    end

    it "outer bindings are available in an overridden context" do
      inner_a = nil
      inner_b = nil
      Puppet::Context.override("b" => 2) do
        inner_a = Puppet::Context.lookup("a")
        inner_b = Puppet::Context.lookup("b")
      end

      expect(inner_a).to eq(1)
      expect(inner_b).to eq(2)
    end

    it "overridden bindings do not exist outside of the override" do
      Puppet::Context.override("a" => 2) do
      end

      expect(Puppet::Context.lookup("a")).to eq(1)
    end

    it "overridden bindings do not exist outside of the override even when leaving via an error" do
      begin
        Puppet::Context.override("a" => 2) do
          raise "this should still cause the bindings to leave"
        end
      rescue
      end

      expect(Puppet::Context.lookup("a")).to eq(1)
    end
  end
end
