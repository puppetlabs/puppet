require 'spec_helper'
require 'puppet_spec/compiler'

describe "Parameter passing" do
  include PuppetSpec::Compiler

  before :each do
    # DataBinding will be consulted before falling back to a default value,
    # but we aren't testing that here
    Puppet::DataBinding.indirection.stubs(:find)
  end

  def expect_the_message_to_be(message, node = Puppet::Node.new('the node'))
    catalog = compile_to_catalog(yield, node)
    expect(catalog.resource('Notify', 'something')[:message]).to eq(message)
  end

  def expect_puppet_error(message, node = Puppet::Node.new('the node'))
    expect { compile_to_catalog(yield, node) }.to raise_error(Puppet::Error, message)
  end

  it "overrides the default when a value is given" do
    expect_the_message_to_be('2') do <<-MANIFEST
      define a($x='1') { notify { 'something': message => $x }}
      a {'a': x => '2'}
      MANIFEST
    end
  end

  it "shadows an inherited variable with the default value when undef is passed" do
    expect_the_message_to_be('default') do <<-MANIFEST
      class a { $x = 'inherited' }
      class b($x='default') inherits a { notify { 'something': message => $x }}
      class { 'b': x => undef}
      MANIFEST
    end
  end

  it "uses a default value that comes from an inherited class when the parameter is undef" do
    expect_the_message_to_be('inherited') do <<-MANIFEST
      class a { $x = 'inherited' }
      class b($y=$x) inherits a { notify { 'something': message => $y }}
      class { 'b': y => undef}
      MANIFEST
    end
  end

  it "uses a default value that references another variable when the parameter is passed as undef" do
    expect_the_message_to_be('a') do <<-MANIFEST
        define a($a = $title) { notify { 'something': message => $a }}
        a {'a': a => undef}
      MANIFEST
    end
  end

  it "uses the default when 'undef' is given'" do
    expect_the_message_to_be('1') do <<-MANIFEST
        define a($x='1') { notify { 'something': message => $x }}
        a {'a': x => undef}
      MANIFEST
    end
  end

  it "uses the default when no parameter is provided" do
    expect_the_message_to_be('1') do <<-MANIFEST
        define a($x='1') { notify { 'something': message => $x }}
        a {'a': }
      MANIFEST
    end
  end

  it "uses a value of undef when the default is undef and no parameter is provided" do
    expect_the_message_to_be(true) do <<-MANIFEST
        define a($x=undef) { notify { 'something': message => $x == undef}}
        a {'a': }
    MANIFEST
    end
  end

  it "errors when no parameter is provided and there is no default" do
    expect_puppet_error(/A\[a\]: expects a value for parameter 'x'/) do <<-MANIFEST
        define a($x) { notify { 'something': message => $x }}
        a {'a': }
    MANIFEST
    end
  end

  it "uses a given undef and do not require a default expression" do
    expect_the_message_to_be(true) do <<-MANIFEST
        define a(Optional[Integer] $x) { notify { 'something': message => $x == undef}}
        a {'a': x => undef }
    MANIFEST
    end
  end
end
