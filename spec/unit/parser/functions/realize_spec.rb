require 'spec_helper'
require 'matchers/resource'
require 'puppet_spec/compiler'

describe "the realize function" do
  include Matchers::Resource
  include PuppetSpec::Compiler

  it "realizes a single, referenced resource" do
    catalog = compile_to_catalog(<<-EOM)
      @notify { testing: }
      realize(Notify[testing])
    EOM

    expect(catalog).to have_resource("Notify[testing]")
  end

  it "realizes multiple resources" do
    catalog = compile_to_catalog(<<-EOM)
      @notify { testing: }
      @notify { other: }
      realize(Notify[testing], Notify[other])
    EOM

    expect(catalog).to have_resource("Notify[testing]")
    expect(catalog).to have_resource("Notify[other]")
  end

  it "realizes resources provided in arrays" do
    catalog = compile_to_catalog(<<-EOM)
      @notify { testing: }
      @notify { other: }
      realize([Notify[testing], [Notify[other]]])
    EOM

    expect(catalog).to have_resource("Notify[testing]")
    expect(catalog).to have_resource("Notify[other]")
  end

  it "fails when the resource does not exist" do
    expect do
      compile_to_catalog(<<-EOM)
        realize(Notify[missing])
      EOM
    end.to raise_error(Puppet::Error, /Failed to realize/)
  end

  it "fails when no parameters given" do
    expect do
      compile_to_catalog(<<-EOM)
        realize()
      EOM
    end.to raise_error(Puppet::Error, /Wrong number of arguments/)
  end

  it "silently does nothing when an empty array of resources is given" do
    compile_to_catalog(<<-EOM)
      realize([])
    EOM
  end
end
