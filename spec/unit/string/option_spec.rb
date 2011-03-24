require 'puppet/string/option'

describe Puppet::String::Option do
  let :string do Puppet::String.new(:option_testing, '0.0.1') end

  it "requires a string when created" do
    expect { Puppet::String::Option.new }.
      should raise_error ArgumentError, /wrong number of arguments/
  end

  it "also requires a name when created" do
    expect { Puppet::String::Option.new(string) }.
      should raise_error ArgumentError, /wrong number of arguments/
  end

  it "should create an instance when given a string and name" do
    Puppet::String::Option.new(string, :foo).
      should be_instance_of Puppet::String::Option
  end

  describe "#to_s" do
    it "should transform a symbol into a string" do
      Puppet::String::Option.new(string, :foo).to_s.should == "foo"
    end

    it "should use - rather than _ to separate words" do
      Puppet::String::Option.new(string, :foo_bar).to_s.should == "foo-bar"
    end
  end

  describe "#type" do
    Puppet::String::Option::Types.each do |type|
      it "should accept #{type.inspect}" do
        Puppet::String::Option.new(string, :foo, :type => type).
          should be_an_instance_of Puppet::String::Option
      end

      it "should accept #{type.inspect} when given as a string" do
        Puppet::String::Option.new(string, :foo, :type => type.to_s).
          should be_an_instance_of Puppet::String::Option
      end
    end

    [:foo, nil, true, false, 12, '12', 'whatever', ::String, URI].each do |input|
      it "should reject #{input.inspect}" do
        expect { Puppet::String::Option.new(string, :foo, :type => input) }.
          should raise_error ArgumentError, /not a valid type/
      end
    end
  end


  # name         short  value          type
  # ca-location         CA_LOCATION    string
  # debug        d      ----           boolean
  # verbose      v      ----           boolean
  # terminus            TERMINUS       string
  # format              FORMAT         symbol
  # mode         r      RUNMODE        limited set of symbols
  # server              URL            URL
end
