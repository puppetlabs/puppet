require 'puppet/faces/option_builder'

describe Puppet::Faces::OptionBuilder do
  let :face do Puppet::Faces.new(:option_builder_testing, '0.0.1') end

  it "should be able to construct an option without a block" do
    Puppet::Faces::OptionBuilder.build(face, "--foo").
      should be_an_instance_of Puppet::Faces::Option
  end

  describe "when using the DSL block" do
    it "should work with an empty block" do
      option = Puppet::Faces::OptionBuilder.build(face, "--foo") do
        # This block deliberately left blank.
      end

      option.should be_an_instance_of Puppet::Faces::Option
    end

    it "should support documentation declarations" do
      text = "this is the description"
      option = Puppet::Faces::OptionBuilder.build(face, "--foo") do
        desc text
      end
      option.should be_an_instance_of Puppet::Faces::Option
      option.desc.should == text
    end
  end
end
