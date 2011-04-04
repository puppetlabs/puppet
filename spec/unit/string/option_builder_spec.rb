require 'puppet/string/option_builder'

describe Puppet::String::OptionBuilder do
  let :string do Puppet::String.new(:option_builder_testing, '0.0.1') end

  it "should be able to construct an option without a block" do
    Puppet::String::OptionBuilder.build(string, "--foo").
      should be_an_instance_of Puppet::String::Option
  end

  describe "when using the DSL block" do
    it "should work with an empty block" do
      option = Puppet::String::OptionBuilder.build(string, "--foo") do
        # This block deliberately left blank.
      end

      option.should be_an_instance_of Puppet::String::Option
    end

    it "should support documentation declarations" do
      text = "this is the description"
      option = Puppet::String::OptionBuilder.build(string, "--foo") do
        desc text
      end
      option.should be_an_instance_of Puppet::String::Option
      option.desc.should == text
    end
  end
end
