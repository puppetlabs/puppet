require 'spec_helper'

require 'puppet/property/list'

list_class = Puppet::Property::List

describe list_class do

  it "should be a subclass of Property" do
    expect(list_class.superclass).to eq(Puppet::Property)
  end

  describe "as an instance" do
    before do
      # Wow that's a messy interface to the resource.
      list_class.initvars
      @resource = double('resource', :[]= => nil, :property => nil)
      @property = list_class.new(:resource => @resource)
    end

    it "should have a , as default delimiter" do
      expect(@property.delimiter).to eq(",")
    end

    it "should have a :membership as default membership" do
      expect(@property.membership).to eq(:membership)
    end

    it "should return the same value passed into should_to_s" do
      @property.should_to_s("foo") == "foo"
    end

    it "should return the passed in array values joined with the delimiter from is_to_s" do
      expect(@property.is_to_s(["foo","bar"])).to eq("foo,bar")
    end

    it "should be able to correctly convert ':absent' to a quoted string" do
      expect(@property.is_to_s(:absent)).to eq("'absent'")
    end

    describe "when adding should to current" do
      it "should add the arrays when current is an array" do
        expect(@property.add_should_with_current(["foo"], ["bar"])).to eq(["foo", "bar"])
      end

      it "should return should if current is not an array" do
        expect(@property.add_should_with_current(["foo"], :absent)).to eq(["foo"])
      end

      it "should return only the uniq elements" do
        expect(@property.add_should_with_current(["foo", "bar"], ["foo", "baz"])).to eq(["foo", "bar", "baz"])
      end
    end

    describe "when calling inclusive?" do
      it "should use the membership method to look up on the @resource" do
        expect(@property).to receive(:membership).and_return(:membership)
        expect(@resource).to receive(:[]).with(:membership)
        @property.inclusive?
      end

      it "should return true when @resource[membership] == inclusive" do
        allow(@property).to receive(:membership).and_return(:membership)
        allow(@resource).to receive(:[]).with(:membership).and_return(:inclusive)
        expect(@property.inclusive?).to eq(true)
      end

      it "should return false when @resource[membership] != inclusive" do
        allow(@property).to receive(:membership).and_return(:membership)
        allow(@resource).to receive(:[]).with(:membership).and_return(:minimum)
        expect(@property.inclusive?).to eq(false)
      end
    end

    describe "when calling should" do
      it "should return nil if @should is nil" do
        expect(@property.should).to eq(nil)
      end

      it "should return the sorted values of @should as a string if inclusive" do
        @property.should = ["foo", "bar"]
        expect(@property).to receive(:inclusive?).and_return(true)
        expect(@property.should).to eq("bar,foo")
      end

      it "should return the uniq sorted values of @should + retrieve as a string if !inclusive" do
        @property.should = ["foo", "bar"]
        expect(@property).to receive(:inclusive?).and_return(false)
        expect(@property).to receive(:retrieve).and_return(["foo","baz"])
        expect(@property.should).to eq("bar,baz,foo")
      end
    end

    describe "when calling retrieve" do
      let(:provider) { @provider }
      before do
        @provider = double("provider")
        allow(@property).to receive(:provider).and_return(provider)
      end

      it "should send 'name' to the provider" do
        expect(@provider).to receive(:send).with(:group)
        expect(@property).to receive(:name).and_return(:group)
        @property.retrieve
      end

      it "should return an array with the provider returned info" do
        allow(@provider).to receive(:send).with(:group).and_return("foo,bar,baz")
        allow(@property).to receive(:name).and_return(:group)
        @property.retrieve == ["foo", "bar", "baz"]
      end

      it "should return :absent when the provider returns :absent" do
        allow(@provider).to receive(:send).with(:group).and_return(:absent)
        allow(@property).to receive(:name).and_return(:group)
        @property.retrieve == :absent
      end

      context "and provider is nil" do
        let(:provider) { nil }
        it "should return :absent" do
          @property.retrieve == :absent
        end
      end
    end

    describe "when calling safe_insync?" do
      it "should return true unless @should is defined and not nil" do
        expect(@property).to be_safe_insync("foo")
      end

      it "should return true unless the passed in values is not nil" do
        @property.should = "foo"
        expect(@property).to be_safe_insync(nil)
      end

      it "should call prepare_is_for_comparison with value passed in and should" do
        @property.should = "foo"
        expect(@property).to receive(:prepare_is_for_comparison).with("bar")
        expect(@property).to receive(:should)
        @property.safe_insync?("bar")
      end

      it "should return true if 'is' value is array of comma delimited should values" do
        @property.should = "bar,foo"
        expect(@property).to receive(:inclusive?).and_return(true)
        expect(@property).to be_safe_insync(["bar","foo"])
      end

      it "should return true if 'is' value is :absent and should value is empty string" do
        @property.should = ""
        expect(@property).to receive(:inclusive?).and_return(true)
        expect(@property).to be_safe_insync([])
      end

      it "should return false if prepared value != should value" do
        @property.should = "bar,baz,foo"
        expect(@property).to receive(:inclusive?).and_return(true)
        expect(@property).to_not be_safe_insync(["bar","foo"])
      end
    end

    describe "when calling dearrayify" do
      it "should sort and join the array with 'delimiter'" do
        array = double("array")
        expect(array).to receive(:sort).and_return(array)
        expect(array).to receive(:join).with(@property.delimiter)
        @property.dearrayify(array)
      end
    end
  end
end
