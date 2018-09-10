#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/property/keyvalue'


describe 'Puppet::Property::KeyValue' do 
  let(:klass) { Puppet::Property::KeyValue }

  it "should be a subclass of Property" do
    expect(klass.superclass).to eq(Puppet::Property)
  end

  describe "as an instance" do
    before do
      # Wow that's a messy interface to the resource.
      klass.initvars
      @resource = stub 'resource', :[]= => nil, :property => nil
      @property = klass.new(:resource => @resource)
      klass.log_only_changed_or_new_keys = false
    end

    it "should have a , as default delimiter" do
      expect(@property.delimiter).to eq(";")
    end

    it "should have a = as default separator" do
      expect(@property.separator).to eq("=")
    end

    it "should have a :membership as default membership" do
      expect(@property.membership).to eq(:key_value_membership)
    end

    it "should return the same value passed into should_to_s" do
      @property.should_to_s({:foo => "baz", :bar => "boo"}) == "foo=baz;bar=boo"
    end

    it "should return the passed in hash values joined with the delimiter from is_to_s" do
      s = @property.is_to_s({"foo" => "baz" , "bar" => "boo"})

      # We can't predict the order the hash is processed in...
      expect(["foo=baz;bar=boo", "bar=boo;foo=baz"]).to be_include s
    end

    describe "when calling hash_to_key_value_s" do
      let(:input) do
        {
          :key1 => "value1",
          :key2 => "value2",
          :key3 => "value3"
        }
      end

      before(:each) do
        @property.instance_variable_set(:@changed_or_new_keys, [:key1, :key2])
      end

      it "returns only the changed or new keys if log_only_changed_or_new_keys is set" do
        klass.log_only_changed_or_new_keys = true

        expect(@property.hash_to_key_value_s(input)).to eql("key1=value1;key2=value2")
      end
    end

    describe "when calling inclusive?" do
      it "should use the membership method to look up on the @resource" do
        @property.expects(:membership).returns(:key_value_membership)
        @resource.expects(:[]).with(:key_value_membership)
        @property.inclusive?
      end

      it "should return true when @resource[membership] == inclusive" do
        @property.stubs(:membership).returns(:key_value_membership)
        @resource.stubs(:[]).with(:key_value_membership).returns(:inclusive)
        expect(@property.inclusive?).to eq(true)
      end

      it "should return false when @resource[membership] != inclusive" do
        @property.stubs(:membership).returns(:key_value_membership)
        @resource.stubs(:[]).with(:key_value_membership).returns(:minimum)
        expect(@property.inclusive?).to eq(false)
      end
    end

    describe "when calling process_current_hash" do
      it "should return {} if hash is :absent" do
        expect(@property.process_current_hash(:absent)).to eq({})
      end

      it "should set every key to nil if inclusive?" do
        @property.stubs(:inclusive?).returns(true)
        expect(@property.process_current_hash({:foo => "bar", :do => "re"})).to eq({ :foo => nil, :do => nil })
      end

      it "should return the hash if !inclusive?" do
        @property.stubs(:inclusive?).returns(false)
        expect(@property.process_current_hash({:foo => "bar", :do => "re"})).to eq({:foo => "bar", :do => "re"})
      end
    end

    describe "when calling should" do
      it "should return nil if @should is nil" do
        expect(@property.should).to eq(nil)
      end

      it "should call process_current_hash" do
        @property.should = ["foo=baz", "bar=boo"]
        @property.stubs(:retrieve).returns({:do => "re", :mi => "fa" })
        @property.expects(:process_current_hash).returns({})
        @property.should
      end

      it "should return the hashed values of @should and the nilled values of retrieve if inclusive" do
        @property.should = ["foo=baz", "bar=boo"]
        @property.expects(:retrieve).returns({:do => "re", :mi => "fa" })
        @property.expects(:inclusive?).returns(true)
        expect(@property.should).to eq({ :foo => "baz", :bar => "boo", :do => nil, :mi => nil })
      end

      it "should return the hashed @should + the unique values of retrieve if !inclusive" do
        @property.should = ["foo=baz", "bar=boo"]
        @property.expects(:retrieve).returns({:foo => "diff", :do => "re", :mi => "fa"})
        @property.expects(:inclusive?).returns(false)
        expect(@property.should).to eq({ :foo => "baz", :bar => "boo", :do => "re", :mi => "fa" })
      end

      it "should mark the keys that will change or be added as a result of our Puppet run" do
        @property.should = {
          :key1 => "new_value1",
          :key2 => "value2",
          :key3 => "new_value3",
          :key4 => "value4"
        }
        @property.stubs(:retrieve).returns(
          {
            :key1 => "value1",
            :key2 => "value2",
            :key3 => "value3"
          }
        )
        @property.stubs(:inclusive?).returns(false)

        @property.should
        expect(@property.instance_variable_get(:@changed_or_new_keys)).to eql([:key1, :key3, :key4])
      end
    end

    describe "when calling retrieve" do
      before do
        @provider = mock("provider")
        @property.stubs(:provider).returns(@provider)
      end

      it "should send 'name' to the provider" do
        @provider.expects(:send).with(:keys)
        @property.expects(:name).returns(:keys)
        @property.retrieve
      end

      it "should return a hash with the provider returned info" do
        @provider.stubs(:send).with(:keys).returns({"do" => "re", "mi" => "fa" })
        @property.stubs(:name).returns(:keys)
        @property.retrieve == {"do" => "re", "mi" => "fa" }
      end

      it "should return :absent when the provider returns :absent" do
        @provider.stubs(:send).with(:keys).returns(:absent)
        @property.stubs(:name).returns(:keys)
        @property.retrieve == :absent
      end
    end

    describe "when calling hashify_should" do
      it "should return the underlying hash if the user passed in a hash" do
        @property.should = { "foo" => "bar" }
        expect(@property.hashify_should).to eql({ :foo => "bar" })
      end

      it "should hashify the array of key/value pairs if that is what our user passed in" do
        @property.should = [ "foo=baz", "bar=boo" ]
        expect(@property.hashify_should).to eq({ :foo => "baz", :bar => "boo" })
      end
    end

    describe "when calling safe_insync?" do
      before do
        @provider = mock("provider")
        @property.stubs(:provider).returns(@provider)
        @property.stubs(:name).returns(:prop_name)
      end

      it "should return true unless @should is defined and not nil" do
        @property.safe_insync?("foo") == true
      end

      it "should return true if the passed in values is nil" do
        @property.safe_insync?(nil) == true
      end

      it "should return true if hashified should value == (retrieved) value passed in" do
        @provider.stubs(:prop_name).returns({ :foo => "baz", :bar => "boo" })
        @property.should = ["foo=baz", "bar=boo"]
        @property.expects(:inclusive?).returns(true)
        expect(@property.safe_insync?({ :foo => "baz", :bar => "boo" })).to eq(true)
      end

      it "should return false if prepared value != should value" do
        @provider.stubs(:prop_name).returns({ "foo" => "bee", "bar" => "boo" })
        @property.should = ["foo=baz", "bar=boo"]
        @property.expects(:inclusive?).returns(true)
        expect(@property.safe_insync?({ "foo" => "bee", "bar" => "boo" })).to eq(false)
      end
    end

    describe 'when validating a passed-in property value' do
      it 'should raise a Puppet::Error if the property value is anything but a Hash or a String' do
        expect { @property.validate(5) }.to raise_error do |error|
          expect(error).to be_a(Puppet::Error)
          expect(error.message).to match("specified as a hash or an array")
        end
      end

      it 'should accept a Hash property value' do
        @property.validate({ 'foo' => 'bar' })
      end

      it "should raise a Puppet::Error if the property value isn't a key/value pair" do
        expect { @property.validate('foo') }.to raise_error do |error|
          expect(error).to be_a(Puppet::Error)
          expect(error.message).to match("separated by '='")
        end
      end

      it 'should accept a valid key/value pair property value' do
        @property.validate('foo=bar')
      end
    end

    describe 'when munging a passed-in property value' do
      it 'should return the value as-is if it is a string' do
        expect(@property.munge('foo=bar')).to eql('foo=bar')
      end

      it 'should stringify + symbolize the keys and stringify the values if it is a hash' do
        input = {
          1     => 2,
          true  => false,
          '   foo   ' => 'bar'
        }
        expected_output = {
          :'1'    => '2',
          :true => 'false',
          :foo  => 'bar'
        }

        expect(@property.munge(input)).to eql(expected_output)
      end
    end
  end
end
