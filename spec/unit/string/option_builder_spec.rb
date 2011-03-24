require 'puppet/string/option_builder'

describe Puppet::String::OptionBuilder do
  let :string do Puppet::String.new(:option_builder_testing, '0.0.1') end

  it "should be able to construct an option without a block" do
    Puppet::String::OptionBuilder.build(string, :foo).
      should be_an_instance_of Puppet::String::Option
  end

  it "should set attributes during construction" do
    # Walk all types, since at least one of them should be non-default...
    Puppet::String::Option::Types.each do |type|
      option = Puppet::String::OptionBuilder.build(string, :foo, :type => type)
      option.should be_an_instance_of Puppet::String::Option
      option.type.should == type
    end
  end

  describe "when using the DSL block" do
    it "should work with an empty block" do
      option = Puppet::String::OptionBuilder.build(string, :foo) do
        # This block deliberately left blank.
      end

      option.should be_an_instance_of Puppet::String::Option
    end

    describe "#type" do
      Puppet::String::Option::Types.each do |valid|
        it "should accept #{valid.inspect}" do
          option = Puppet::String::OptionBuilder.build(string, :foo) do
            type valid
          end
          option.should be_an_instance_of Puppet::String::Option
        end

        it "should accept #{valid.inspect} as a string" do
          option = Puppet::String::OptionBuilder.build(string, :foo) do
            type valid.to_s
          end
          option.should be_an_instance_of Puppet::String::Option
        end

        [:foo, nil, true, false, 12, '12', 'whatever', ::String, URI].each do |input|
          it "should reject #{input.inspect}" do
            expect {
              Puppet::String::OptionBuilder.build(string, :foo) do
                type input
              end
            }.should raise_error ArgumentError, /not a valid type/
          end
        end
      end
    end
  end
end
