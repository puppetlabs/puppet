require 'spec_helper'

describe Puppet::Context do
  before :each do
    Puppet::Context.push
  end

  after :each do
    Puppet::Context.pop
  end

  it "holds values for later lookup" do
    Puppet::Context.bind("a", 1)

    expect(Puppet::Context.lookup("a")).to eq(1)
  end

  it "does not allow a value to be re-set" do
    Puppet::Context.bind("a", 1)

    expect { Puppet::Context.bind("a", 1) }.to raise_error(Puppet::Context::ValueAlreadyBoundError)
  end

  it "fails to lookup a value that does not exist" do
    expect { Puppet::Context.lookup("a") }.to raise_error(Puppet::Context::UndefinedBindingError)
  end

  it "calls a provided block for a default value when none is found" do
    expect(Puppet::Context.lookup("a") { "default" }).to eq("default")
  end

  it "allows rebinding values in a nested context" do
    Puppet::Context.bind("a", 1)

    inner = nil
    Puppet::Context.override("a" => 2) do
      inner = Puppet::Context.lookup("a")
    end

    expect(inner).to eq(2)
  end

  it "outer bindings are available in an overridden context" do
    Puppet::Context.bind("a", 1)

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
    Puppet::Context.bind("a", 1)

    Puppet::Context.override("a" => 2) do
    end

    expect(Puppet::Context.lookup("a")).to eq(1)
  end

  it "overridden bindings do not exist outside of the override even when leaving via an error" do
    Puppet::Context.bind("a", 1)

    begin
      Puppet::Context.override("a" => 2) do
        raise "this should still cause the bindings to leave"
      end
    rescue
    end

    expect(Puppet::Context.lookup("a")).to eq(1)
  end
end
