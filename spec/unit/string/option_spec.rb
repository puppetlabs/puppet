require 'puppet/string/option'

describe Puppet::String::Option do
  let :string do Puppet::String.new(:option_testing, '0.0.1') end

  describe "#optparse_to_name" do
    ["", "=BAR", " BAR", "=bar", " bar"].each do |postfix|
      { "--foo" => :foo, "-f" => :f,}.each do |base, expect|
        input = base + postfix
        it "should map #{input.inspect} to #{expect.inspect}" do
          option = Puppet::String::Option.new(string, input)
          option.name.should == expect
        end
      end
    end

    [:foo, 12, nil, {}, []].each do |input|
      it "should fail sensible when given #{input.inspect}" do
        expect { Puppet::String::Option.new(string, input) }.
          should raise_error ArgumentError, /is not valid for an option argument/
      end
    end

    ["-foo", "-foo=BAR", "-foo BAR"].each do |input|
      it "should fail with a single dash for long option #{input.inspect}" do
        expect { Puppet::String::Option.new(string, input) }.
          should raise_error ArgumentError, /long options need two dashes \(--\)/
      end
    end
  end

  it "requires a string when created" do
    expect { Puppet::String::Option.new }.
      should raise_error ArgumentError, /wrong number of arguments/
  end

  it "also requires some declaration arguments when created" do
    expect { Puppet::String::Option.new(string) }.
      should raise_error ArgumentError, /No option declarations found/
  end

  it "should infer the name from an optparse string" do
    option = Puppet::String::Option.new(string, "--foo")
    option.name.should == :foo
  end

  it "should infer the name when multiple optparse strings are given" do
    option = Puppet::String::Option.new(string, "--foo", "-f")
    option.name.should == :foo
  end

  it "should prefer the first long option name over a short option name" do
    option = Puppet::String::Option.new(string, "-f", "--foo")
    option.name.should == :foo
  end

  it "should create an instance when given a string and name" do
    Puppet::String::Option.new(string, "--foo").
      should be_instance_of Puppet::String::Option
  end

  describe "#to_s" do
    it "should transform a symbol into a string" do
      option = Puppet::String::Option.new(string, "--foo")
      option.name.should == :foo
      option.to_s.should == "foo"
    end

    it "should use - rather than _ to separate words in strings but not symbols" do
      option = Puppet::String::Option.new(string, "--foo-bar")
      option.name.should == :foo_bar
      option.to_s.should == "foo-bar"
    end
  end
end
