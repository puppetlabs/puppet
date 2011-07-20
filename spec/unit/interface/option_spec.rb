require 'puppet/interface'
require 'puppet/interface/option'

describe Puppet::Interface::Option do
  let :face do Puppet::Interface.new(:option_testing, '0.0.1') end

  describe "#optparse_to_name" do
    ["", "=BAR", " BAR", "=bar", " bar"].each do |postfix|
      { "--foo" => :foo, "-f" => :f }.each do |base, expect|
        input = base + postfix
        it "should map #{input.inspect} to #{expect.inspect}" do
          option = Puppet::Interface::Option.new(face, input)
          option.name.should == expect
        end
      end
    end

    [:foo, 12, nil, {}, []].each do |input|
      it "should fail sensible when given #{input.inspect}" do
        expect { Puppet::Interface::Option.new(face, input) }.
          should raise_error ArgumentError, /is not valid for an option argument/
      end
    end

    ["-foo", "-foo=BAR", "-foo BAR"].each do |input|
      it "should fail with a single dash for long option #{input.inspect}" do
        expect { Puppet::Interface::Option.new(face, input) }.
          should raise_error ArgumentError, /long options need two dashes \(--\)/
      end
    end
  end

  it "requires a face when created" do
    expect { Puppet::Interface::Option.new }.
      should raise_error ArgumentError, /wrong number of arguments/
  end

  it "also requires some declaration arguments when created" do
    expect { Puppet::Interface::Option.new(face) }.
      should raise_error ArgumentError, /No option declarations found/
  end

  it "should infer the name from an optparse string" do
    option = Puppet::Interface::Option.new(face, "--foo")
    option.name.should == :foo
  end

  it "should infer the name when multiple optparse string are given" do
    option = Puppet::Interface::Option.new(face, "--foo", "-f")
    option.name.should == :foo
  end

  it "should prefer the first long option name over a short option name" do
    option = Puppet::Interface::Option.new(face, "-f", "--foo")
    option.name.should == :foo
  end

  it "should create an instance when given a face and name" do
    Puppet::Interface::Option.new(face, "--foo").
      should be_instance_of Puppet::Interface::Option
  end

  describe "#to_s" do
    it "should transform a symbol into a string" do
      option = Puppet::Interface::Option.new(face, "--foo")
      option.name.should == :foo
      option.to_s.should == "foo"
    end

    it "should use - rather than _ to separate words in strings but not symbols" do
      option = Puppet::Interface::Option.new(face, "--foo-bar")
      option.name.should == :foo_bar
      option.to_s.should == "foo-bar"
    end
  end

  %w{before after}.each do |side|
    describe "#{side} hooks" do
      subject { Puppet::Interface::Option.new(face, "--foo") }
      let :proc do Proc.new do :from_proc end end

      it { should respond_to "#{side}_action" }
      it { should respond_to "#{side}_action=" }

      it "should set the #{side}_action hook" do
        subject.send("#{side}_action").should be_nil
        subject.send("#{side}_action=", proc)
        subject.send("#{side}_action").should be_an_instance_of UnboundMethod
      end

      data = [1, "foo", :foo, Object.new, method(:hash), method(:hash).unbind]
      data.each do |input|
        it "should fail if a #{input.class} is added to the #{side} hooks" do
          expect { subject.send("#{side}_action=", input) }.
            to raise_error ArgumentError, /not a proc/
        end
      end
    end
  end

  context "defaults" do
    subject { Puppet::Interface::Option.new(face, "--foo") }

    it "should work sanely if member variables are used for state" do
      subject.default = proc { @foo ||= 0; @foo += 1 }
      subject.default.should == 1
      subject.default.should == 2
      subject.default.should == 3
    end

    context "with no default" do
      it { should_not be_has_default }
      its :default do should be_nil end

      it "should set a proc as default" do
        expect { subject.default = proc { 12 } }.should_not raise_error
      end

      [1, {}, [], Object.new, "foo"].each do |input|
        it "should reject anything but a proc (#{input.class})" do
          expect { subject.default = input }.to raise_error ArgumentError, /not a proc/
        end
      end
    end

    context "with a default" do
      before :each do subject.default = proc { [:foo] } end

      it { should be_has_default }
      its :default do should == [:foo] end

      it "should invoke the block every time" do
        subject.default.object_id.should_not == subject.default.object_id
        subject.default.should == subject.default
      end

      it "should allow replacing the default proc" do
        subject.default.should == [:foo]
        subject.default = proc { :bar }
        subject.default.should == :bar
      end
    end
  end
end
