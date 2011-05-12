require 'puppet/interface/option_builder'

describe Puppet::Interface::OptionBuilder do
  let :face do Puppet::Interface.new(:option_builder_testing, '0.0.1') end

  it "should be able to construct an option without a block" do
    Puppet::Interface::OptionBuilder.build(face, "--foo").
      should be_an_instance_of Puppet::Interface::Option
  end

  it "should work with an empty block" do
    option = Puppet::Interface::OptionBuilder.build(face, "--foo") do
      # This block deliberately left blank.
    end

    option.should be_an_instance_of Puppet::Interface::Option
  end

  [:description, :summary].each do |doc|
    it "should support #{doc} declarations" do
      text = "this is the #{doc}"
      option = Puppet::Interface::OptionBuilder.build(face, "--foo") do
        self.send doc, text
      end
      option.should be_an_instance_of Puppet::Interface::Option
      option.send(doc).should == text
    end
  end

  context "before_action hook" do
    it "should support a before_action hook" do
      option = Puppet::Interface::OptionBuilder.build(face, "--foo") do
        before_action do |a,b,c| :whatever end
      end
      option.before_action.should be_an_instance_of UnboundMethod
    end

    it "should fail if the hook block takes too few arguments" do
      expect do
        Puppet::Interface::OptionBuilder.build(face, "--foo") do
          before_action do |one, two| true end
        end
      end.to raise_error ArgumentError, /takes three arguments/
    end

    it "should fail if the hook block takes too many arguments" do
      expect do
        Puppet::Interface::OptionBuilder.build(face, "--foo") do
          before_action do |one, two, three, four| true end
        end
      end.to raise_error ArgumentError, /takes three arguments/
    end

    it "should fail if the hook block takes a variable number of arguments" do
      expect do
        Puppet::Interface::OptionBuilder.build(face, "--foo") do
          before_action do |*blah| true end
        end
      end.to raise_error ArgumentError, /takes three arguments/
    end

    it "should support simple required declarations" do
      opt = Puppet::Interface::OptionBuilder.build(face, "--foo") do
        required
      end
      opt.should be_required
    end

    it "should support arguments to the required property" do
      opt = Puppet::Interface::OptionBuilder.build(face, "--foo") do
        required(false)
      end
      opt.should_not be_required
    end

  end
end
