require 'puppet/faces/option'

describe Puppet::Faces::Option do
  let :face do Puppet::Faces.new(:option_testing, '0.0.1') end

  describe "#optparse_to_name" do
    ["", "=BAR", " BAR", "=bar", " bar"].each do |postfix|
      { "--foo" => :foo, "-f" => :f }.each do |base, expect|
        input = base + postfix
        it "should map #{input.inspect} to #{expect.inspect}" do
          option = Puppet::Faces::Option.new(face, input)
          option.name.should == expect
        end
      end
    end

    [:foo, 12, nil, {}, []].each do |input|
      it "should fail sensible when given #{input.inspect}" do
        expect { Puppet::Faces::Option.new(face, input) }.
          should raise_error ArgumentError, /is not valid for an option argument/
      end
    end

    ["-foo", "-foo=BAR", "-foo BAR"].each do |input|
      it "should fail with a single dash for long option #{input.inspect}" do
        expect { Puppet::Faces::Option.new(face, input) }.
          should raise_error ArgumentError, /long options need two dashes \(--\)/
      end
    end
  end

  it "requires a face when created" do
    expect { Puppet::Faces::Option.new }.
      should raise_error ArgumentError, /wrong number of arguments/
  end

  it "also requires some declaration arguments when created" do
    expect { Puppet::Faces::Option.new(face) }.
      should raise_error ArgumentError, /No option declarations found/
  end

  it "should infer the name from an optparse string" do
    option = Puppet::Faces::Option.new(face, "--foo")
    option.name.should == :foo
  end

  it "should infer the name when multiple optparse string are given" do
    option = Puppet::Faces::Option.new(face, "--foo", "-f")
    option.name.should == :foo
  end

  it "should prefer the first long option name over a short option name" do
    option = Puppet::Faces::Option.new(face, "-f", "--foo")
    option.name.should == :foo
  end

  it "should create an instance when given a face and name" do
    Puppet::Faces::Option.new(face, "--foo").
      should be_instance_of Puppet::Faces::Option
  end

  describe "#to_s" do
    it "should transform a symbol into a string" do
      option = Puppet::Faces::Option.new(face, "--foo")
      option.name.should == :foo
      option.to_s.should == "foo"
    end

    it "should use - rather than _ to separate words in strings but not symbols" do
      option = Puppet::Faces::Option.new(face, "--foo-bar")
      option.name.should == :foo_bar
      option.to_s.should == "foo-bar"
    end
  end
end
