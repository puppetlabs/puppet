require 'spec_helper'
require 'puppet/interface'

describe Puppet::Interface::Option do
  let :face do Puppet::Interface.new(:option_testing, '0.0.1') end

  describe "#optparse_to_name" do
    ["", "=BAR", " BAR", "=bar", " bar"].each do |postfix|
      { "--foo" => :foo, "-f" => :f }.each do |base, expect|
        input = base + postfix
        it "should map #{input.inspect} to #{expect.inspect}" do
          option = Puppet::Interface::Option.new(face, input)
          expect(option.name).to eq(expect)
        end
      end
    end

    [:foo, 12, nil, {}, []].each do |input|
      it "should fail sensible when given #{input.inspect}" do
        expect {
          Puppet::Interface::Option.new(face, input)
        }.to raise_error ArgumentError, /is not valid for an option argument/
      end
    end

    ["-foo", "-foo=BAR", "-foo BAR"].each do |input|
      it "should fail with a single dash for long option #{input.inspect}" do
        expect {
          Puppet::Interface::Option.new(face, input)
        }.to raise_error ArgumentError, /long options need two dashes \(--\)/
      end
    end
  end

  it "requires a face when created" do
    expect {
      Puppet::Interface::Option.new
    }.to raise_error ArgumentError, /wrong number of arguments/
  end

  it "also requires some declaration arguments when created" do
    expect {
      Puppet::Interface::Option.new(face)
    }.to raise_error ArgumentError, /No option declarations found/
  end

  it "should infer the name from an optparse string" do
    option = Puppet::Interface::Option.new(face, "--foo")
    expect(option.name).to eq(:foo)
  end

  it "should infer the name when multiple optparse string are given" do
    option = Puppet::Interface::Option.new(face, "--foo", "-f")
    expect(option.name).to eq(:foo)
  end

  it "should prefer the first long option name over a short option name" do
    option = Puppet::Interface::Option.new(face, "-f", "--foo")
    expect(option.name).to eq(:foo)
  end

  it "should create an instance when given a face and name" do
    expect(Puppet::Interface::Option.new(face, "--foo")).
      to be_instance_of Puppet::Interface::Option
  end

  Puppet.settings.each do |name, value|
    it "should fail when option #{name.inspect} already exists in puppet core" do
      expect do
        Puppet::Interface::Option.new(face, "--#{name}")
      end.to raise_error ArgumentError, /already defined/
    end
  end

  describe "#to_s" do
    it "should transform a symbol into a string" do
      option = Puppet::Interface::Option.new(face, "--foo")
      expect(option.name).to eq(:foo)
      expect(option.to_s).to eq("foo")
    end

    it "should use - rather than _ to separate words in strings but not symbols" do
      option = Puppet::Interface::Option.new(face, "--foo-bar")
      expect(option.name).to eq(:foo_bar)
      expect(option.to_s).to eq("foo-bar")
    end
  end

  %w{before after}.each do |side|
    describe "#{side} hooks" do
      subject { Puppet::Interface::Option.new(face, "--foo") }
      let :proc do Proc.new do :from_proc end end

      it { is_expected.to respond_to "#{side}_action" }
      it { is_expected.to respond_to "#{side}_action=" }

      it "should set the #{side}_action hook" do
        expect(subject.send("#{side}_action")).to be_nil
        subject.send("#{side}_action=", proc)
        expect(subject.send("#{side}_action")).to be_an_instance_of UnboundMethod
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
      expect(subject.default).to eq(1)
      expect(subject.default).to eq(2)
      expect(subject.default).to eq(3)
    end

    context "with no default" do
      it { is_expected.not_to be_has_default }
      its :default do should be_nil end

      it "should set a proc as default" do
        expect { subject.default = proc { 12 } }.to_not raise_error
      end

      [1, {}, [], Object.new, "foo"].each do |input|
        it "should reject anything but a proc (#{input.class})" do
          expect { subject.default = input }.to raise_error ArgumentError, /not a proc/
        end
      end
    end

    context "with a default" do
      before :each do subject.default = proc { [:foo] } end

      it { is_expected.to be_has_default }
      its :default do should == [:foo] end

      it "should invoke the block every time" do
        expect(subject.default.object_id).not_to eq(subject.default.object_id)
        expect(subject.default).to eq(subject.default)
      end

      it "should allow replacing the default proc" do
        expect(subject.default).to eq([:foo])
        subject.default = proc { :bar }
        expect(subject.default).to eq(:bar)
      end
    end
  end
end
