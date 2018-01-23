#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/property'

describe Puppet::Property do
  let :resource do Puppet::Type.type(:host).new :name => "foo" end

  let :subclass do
    # We need a completely fresh subclass every time, because we modify both
    # class and instance level things inside the tests.
    subclass = Class.new(Puppet::Property) do
      class << self
        attr_accessor :name
      end
      @name = :foo
    end
    subclass.initvars
    subclass
  end

  let :property do subclass.new :resource => resource end

  it "should be able to look up the modified name for a given value" do
    subclass.newvalue(:foo)
    expect(subclass.value_name("foo")).to eq(:foo)
  end

  it "should be able to look up the modified name for a given value matching a regex" do
    subclass.newvalue(%r{.})
    expect(subclass.value_name("foo")).to eq(%r{.})
  end

  it "should be able to look up a given value option" do
    subclass.newvalue(:foo, :event => :whatever)
    expect(subclass.value_option(:foo, :event)).to eq(:whatever)
  end

  it "should be able to specify required features" do
    expect(subclass).to respond_to(:required_features=)
  end

  {"one" => [:one],:one => [:one],%w{a} => [:a],[:b] => [:b],%w{one two} => [:one,:two],[:a,:b] => [:a,:b]}.each { |in_value,out_value|
    it "should always convert required features into an array of symbols (e.g. #{in_value.inspect} --> #{out_value.inspect})" do
      subclass.required_features = in_value
      expect(subclass.required_features).to eq(out_value)
    end
  }

  it "should return its name as a string when converted to a string" do
    expect(property.to_s).to eq(property.name.to_s)
  end

  describe "when returning the default event name" do
    it "should use the current 'should' value to pick the event name" do
      property.expects(:should).returns "myvalue"
      subclass.expects(:value_option).with('myvalue', :event).returns :event_name

      property.event_name
    end

    it "should return any event defined with the specified value" do
      property.expects(:should).returns :myval
      subclass.expects(:value_option).with(:myval, :event).returns :event_name

      expect(property.event_name).to eq(:event_name)
    end

    describe "and the property is 'ensure'" do
      before :each do
        property.stubs(:name).returns :ensure
        resource.expects(:type).returns :mytype
      end

      it "should use <type>_created if the 'should' value is 'present'" do
        property.expects(:should).returns :present
        expect(property.event_name).to eq(:mytype_created)
      end

      it "should use <type>_removed if the 'should' value is 'absent'" do
        property.expects(:should).returns :absent
        expect(property.event_name).to eq(:mytype_removed)
      end

      it "should use <type>_changed if the 'should' value is not 'absent' or 'present'" do
        property.expects(:should).returns :foo
        expect(property.event_name).to eq(:mytype_changed)
      end

      it "should use <type>_changed if the 'should value is nil" do
        property.expects(:should).returns nil
        expect(property.event_name).to eq(:mytype_changed)
      end
    end

    it "should use <property>_changed if the property is not 'ensure'" do
      property.stubs(:name).returns :myparam
      property.expects(:should).returns :foo
      expect(property.event_name).to eq(:myparam_changed)
    end

    it "should use <property>_changed if no 'should' value is set" do
      property.stubs(:name).returns :myparam
      property.expects(:should).returns nil
      expect(property.event_name).to eq(:myparam_changed)
    end
  end

  describe "when creating an event" do
    before :each do
      property.stubs(:should).returns "myval"
    end

    it "should use an event from the resource as the base event" do
      event = Puppet::Transaction::Event.new
      resource.expects(:event).returns event

      expect(property.event).to equal(event)
    end

    it "should have the default event name" do
      property.expects(:event_name).returns :my_event
      expect(property.event.name).to eq(:my_event)
    end

    it "should have the property's name" do
      expect(property.event.property).to eq(property.name.to_s)
    end

    it "should have the 'should' value set" do
      property.stubs(:should).returns "foo"
      expect(property.event.desired_value).to eq("foo")
    end

    it "should provide its path as the source description" do
      property.stubs(:path).returns "/my/param"
      expect(property.event.source_description).to eq("/my/param")
    end

    it "should have the 'invalidate_refreshes' value set if set on a value" do
      property.stubs(:event_name).returns :my_event
      property.stubs(:should).returns "foo"
      foo = mock()
      foo.expects(:invalidate_refreshes).returns(true)
      collection = mock()
      collection.expects(:match?).with("foo").returns(foo)
      property.class.stubs(:value_collection).returns(collection)
      expect(property.event.invalidate_refreshes).to be_truthy
    end

    it "sets the redacted field on the event when the property is sensitive" do
      property.sensitive = true
      expect(property.event.redacted).to eq true
    end
  end

  describe "when defining new values" do
    it "should define a method for each value created with a block that's not a regex" do
      subclass.newvalue(:foo) { }
      expect(property).to respond_to(:set_foo)
    end
  end

  describe "when assigning the value" do
    it "should just set the 'should' value" do
      property.value = "foo"
      expect(property.should).to eq("foo")
    end

    it "should validate each value separately" do
      property.expects(:validate).with("one")
      property.expects(:validate).with("two")

      property.value = %w{one two}
    end

    it "should munge each value separately and use any result as the actual value" do
      property.expects(:munge).with("one").returns :one
      property.expects(:munge).with("two").returns :two

      # Do this so we get the whole array back.
      subclass.array_matching = :all

      property.value = %w{one two}
      expect(property.should).to eq([:one, :two])
    end

    it "should return any set value" do
      expect(property.value = :one).to eq(:one)
    end
  end

  describe "when returning the value" do
    it "should return nil if no value is set" do
      expect(property.should).to be_nil
    end

    it "should return the first set 'should' value if :array_matching is set to :first" do
      subclass.array_matching = :first
      property.should = %w{one two}
      expect(property.should).to eq("one")
    end

    it "should return all set 'should' values as an array if :array_matching is set to :all" do
      subclass.array_matching = :all
      property.should = %w{one two}
      expect(property.should).to eq(%w{one two})
    end

    it "should default to :first array_matching" do
      expect(subclass.array_matching).to eq(:first)
    end

    it "should unmunge the returned value if :array_matching is set to :first" do
      property.class.unmunge do |v| v.to_sym end
      subclass.array_matching = :first
      property.should = %w{one two}

      expect(property.should).to eq(:one)
    end

    it "should unmunge all the returned values if :array_matching is set to :all" do
      property.class.unmunge do |v| v.to_sym end
      subclass.array_matching = :all
      property.should = %w{one two}

      expect(property.should).to eq([:one, :two])
    end
  end

  describe "when validating values" do
    it "should do nothing if no values or regexes have been defined" do
      expect { property.should = "foo" }.not_to raise_error
    end

    it "should fail if the value is not a defined value or alias and does not match a regex" do
      subclass.newvalue(:foo)

      expect { property.should = "bar" }.to raise_error(Puppet::Error, /Invalid value "bar"./)
    end

    it "should succeeed if the value is one of the defined values" do
      subclass.newvalue(:foo)

      expect { property.should = :foo }.not_to raise_error
    end

    it "should succeeed if the value is one of the defined values even if the definition uses a symbol and the validation uses a string" do
      subclass.newvalue(:foo)

      expect { property.should = "foo" }.not_to raise_error
    end

    it "should succeeed if the value is one of the defined values even if the definition uses a string and the validation uses a symbol" do
      subclass.newvalue("foo")

      expect { property.should = :foo }.not_to raise_error
    end

    it "should succeed if the value is one of the defined aliases" do
      subclass.newvalue("foo")
      subclass.aliasvalue("bar", "foo")

      expect { property.should = :bar }.not_to raise_error
    end

    it "should succeed if the value matches one of the regexes" do
      subclass.newvalue(/./)

      expect { property.should = "bar" }.not_to raise_error
    end

    it "should validate that all required features are present" do
      subclass.newvalue(:foo, :required_features => [:a, :b])

      resource.provider.expects(:satisfies?).with([:a, :b]).returns true

      property.should = :foo
    end

    it "should fail if required features are missing" do
      subclass.newvalue(:foo, :required_features => [:a, :b])

      resource.provider.expects(:satisfies?).with([:a, :b]).returns false

      expect { property.should = :foo }.to raise_error(Puppet::Error)
    end

    it "should internally raise an ArgumentError if required features are missing" do
      subclass.newvalue(:foo, :required_features => [:a, :b])

      resource.provider.expects(:satisfies?).with([:a, :b]).returns false

      expect { property.validate_features_per_value :foo }.to raise_error(ArgumentError)
    end

    it "should validate that all required features are present for regexes" do
      subclass.newvalue(/./, :required_features => [:a, :b])

      resource.provider.expects(:satisfies?).with([:a, :b]).returns true

      property.should = "foo"
    end

    it "should support specifying an individual required feature" do
      subclass.newvalue(/./, :required_features => :a)

      resource.provider.expects(:satisfies?).returns true

      property.should = "foo"
    end
  end

  describe "when munging values" do
    it "should do nothing if no values or regexes have been defined" do
      expect(property.munge("foo")).to eq("foo")
    end

    it "should return return any matching defined values" do
      subclass.newvalue(:foo)
      expect(property.munge("foo")).to eq(:foo)
    end

    it "should return any matching aliases" do
      subclass.newvalue(:foo)
      subclass.aliasvalue(:bar, :foo)
      expect(property.munge("bar")).to eq(:foo)
    end

    it "should return the value if it matches a regex" do
      subclass.newvalue(/./)
      expect(property.munge("bar")).to eq("bar")
    end

    it "should return the value if no other option is matched" do
      subclass.newvalue(:foo)
      expect(property.munge("bar")).to eq("bar")
    end
  end

  describe "when syncing the 'should' value" do
    it "should set the value" do
      subclass.newvalue(:foo)
      property.should = :foo
      property.expects(:set).with(:foo)
      property.sync
    end
  end

  describe "when setting a value" do
    it "should catch exceptions and raise Puppet::Error" do
      subclass.newvalue(:foo) { raise "eh" }
      expect { property.set(:foo) }.to raise_error(Puppet::Error)
    end

    it "fails when the provider does not handle the attribute" do
      subclass.name = "unknown"
      expect { property.set(:a_value) }.to raise_error(Puppet::Error)
    end

    it "propogates the errors about missing methods from the provider" do
      provider = resource.provider
      def provider.bad_method=(value)
        value.this_method_does_not_exist
      end

      subclass.name = :bad_method
      expect { property.set(:a_value) }.to raise_error(NoMethodError, /this_method_does_not_exist/)
    end

    describe "that was defined without a block" do
      it "should call the settor on the provider" do
        subclass.newvalue(:bar)
        resource.provider.expects(:foo=).with :bar
        property.set(:bar)
      end

       it "should generate setter named from :method argument and propagate call to the provider" do
        subclass.newvalue(:bar, :method => 'set_vv')
        resource.provider.expects(:foo=).with :bar
        property.set_vv(:bar)
      end
    end

    describe "that was defined with a block" do
      it "should call the method created for the value if the value is not a regex" do
        subclass.newvalue(:bar) {}
        property.expects(:set_bar)
        property.set(:bar)
      end

      it "should call the provided block if the value is a regex" do
        thing = mock
        subclass.newvalue(/./) { thing.test }
        thing.expects(:test)
        property.set("foo")
      end
    end
  end

  describe "when producing a change log" do
    it "should say 'defined' when the current value is 'absent'" do
      expect(property.change_to_s(:absent, "foo")).to match(/^defined/)
    end

    it "should say 'undefined' when the new value is 'absent'" do
      expect(property.change_to_s("foo", :absent)).to match(/^undefined/)
    end

    it "should say 'changed' when neither value is 'absent'" do
      expect(property.change_to_s("foo", "bar")).to match(/changed/)
    end
  end

  shared_examples_for "#insync?" do
    # We share a lot of behaviour between the all and first matching, so we
    # use a shared behaviour set to emulate that.  The outside world makes
    # sure the class, etc, point to the right content.
    [[], [12], [12, 13]].each do |input|
      it "should return true if should is empty with is => #{input.inspect}" do
        property.should = []
        expect(property).to be_insync(input)
        expect(property.insync_values?([], input)).to be true
      end
    end
  end

  describe "#insync?" do
    context "array_matching :all" do
      # `@should` is an array of scalar values, and `is` is an array of scalar values.
      before :each do
        property.class.array_matching = :all
      end

      it_should_behave_like "#insync?"

      context "if the should value is an array" do
        let(:input) { [1,2] }
        before :each do property.should = input end

        it "should match if is exactly matches" do
          val = [1, 2]
          expect(property).to be_insync val
          expect(property.insync_values?(input, val)).to be true
        end

        it "should match if it matches, but all stringified" do
          val = ["1", "2"]
          expect(property).to be_insync val
          expect(property.insync_values?(input, val)).to be true
        end

        it "should not match if some-but-not-all values are stringified" do
          val = ["1", 2]
          expect(property).to_not be_insync val
          expect(property.insync_values?(input, val)).to_not be true
          val = [1, "2"]
          expect(property).to_not be_insync val
          expect(property.insync_values?(input, val)).to_not be true
        end

        it "should not match if order is different but content the same" do
          val = [2, 1]
          expect(property).to_not be_insync val
          expect(property.insync_values?(input, val)).to_not be true
        end

        it "should not match if there are more items in should than is" do
          val = [1]
          expect(property).to_not be_insync val
          expect(property.insync_values?(input, val)).to_not be true
        end

        it "should not match if there are less items in should than is" do
          val = [1, 2, 3]
          expect(property).to_not be_insync val
          expect(property.insync_values?(input, val)).to_not be true
        end

        it "should not match if `is` is empty but `should` isn't" do
          val = []
          expect(property).to_not be_insync val
          expect(property.insync_values?(input, val)).to_not be true
        end
      end
    end

    context "array_matching :first" do
      # `@should` is an array of scalar values, and `is` is a scalar value.
      before :each do
        property.class.array_matching = :first
      end

      it_should_behave_like "#insync?"

      [[1],                     # only the value
       [1, 2],                  # matching value first
       [2, 1],                  # matching value last
       [0, 1, 2],               # matching value in the middle
      ].each do |input|
        it "should by true if one unmodified should value of #{input.inspect} matches what is" do
          val = 1
          property.should = input
          expect(property).to be_insync val
          expect(property.insync_values?(input, val)).to be true
        end

        it "should be true if one stringified should value of #{input.inspect} matches what is" do
          val = "1"
          property.should = input
          expect(property).to be_insync val
          expect(property.insync_values?(input, val)).to be true
        end
      end

      it "should not match if we expect a string but get the non-stringified value" do
        property.should = ["1"]
        expect(property).to_not be_insync 1
        expect(property.insync_values?(["1"], 1)).to_not be true
      end

      [[0], [0, 2]].each do |input|
        it "should not match if no should values match what is" do
          property.should = input
          expect(property).to_not be_insync 1
          expect(property.insync_values?(input, 1)).to_not be true
          expect(property).to_not be_insync "1" # shouldn't match either.
          expect(property.insync_values?(input, "1")).to_not be true
        end
      end
    end
  end

  describe "#property_matches?" do
    [1, "1", [1], :one].each do |input|
      it "should treat two equal objects as equal (#{input.inspect})" do
        expect(property.property_matches?(input, input)).to be_truthy
      end
    end

    it "should treat two objects as equal if the first argument is the stringified version of the second" do
      expect(property.property_matches?("1", 1)).to be_truthy
    end

    it "should NOT treat two objects as equal if the first argument is not a string, and the second argument is a string, even if it stringifies to the first" do
      expect(property.property_matches?(1, "1")).to be_falsey
    end
  end

  describe "#insync_values?" do
    it "should log an exception when insync? throws one" do
      property.expects(:insync?).raises ArgumentError
      expect(property.insync_values?("foo","bar")).to be nil
    end
  end
end
