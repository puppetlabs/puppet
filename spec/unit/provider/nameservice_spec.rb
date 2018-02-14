#! /usr/bin/env ruby

require 'spec_helper'
require 'puppet/provider/nameservice'
require 'puppet/etc'
require 'puppet_spec/character_encoding'

describe Puppet::Provider::NameService do

  before :each do
    described_class.initvars
    described_class.resource_type = faketype
  end

  # These are values getpwent might give you
  let :users do
    [
      Struct::Passwd.new('root', 'x', 0, 0),
      Struct::Passwd.new('foo', 'x', 1000, 2000),
      nil
    ]
  end

  # These are values getgrent might give you
  let :groups do
    [
      Struct::Group.new('root', 'x', 0, %w{root}),
      Struct::Group.new('bin', 'x', 1, %w{root bin daemon}),
      nil
    ]
  end

  # A fake struct besides Struct::Group and Struct::Passwd
  let :fakestruct do
    Struct.new(:foo, :bar)
  end

  # A fake value get<foo>ent might return
  let :fakeetcobject do
    fakestruct.new('fooval', 'barval')
  end

  # The provider sometimes relies on @resource for valid properties so let's
  # create a fake type with properties that match our fake struct.
  let :faketype do
    Puppet::Type.newtype(:nameservice_dummytype) do
      newparam(:name)
      ensurable
      newproperty(:foo)
      newproperty(:bar)
    end
  end

  let :provider do
    described_class.new(:name => 'bob', :foo => 'fooval', :bar => 'barval')
  end

  let :resource do
    resource = faketype.new(:name => 'bob', :ensure => :present)
    resource.provider = provider
    resource
  end

  # These values simulate what Ruby Etc would return from a host with the "same"
  # user represented in different encodings on disk.
  let(:utf_8_jose) { "Jos\u00E9"}
  let(:utf_8_labeled_as_latin_1_jose) { utf_8_jose.dup.force_encoding(Encoding::ISO_8859_1) }
  let(:valid_latin1_jose) { utf_8_jose.encode(Encoding::ISO_8859_1)}
  let(:invalid_utf_8_jose) { valid_latin1_jose.dup.force_encoding(Encoding::UTF_8) }
  let(:escaped_utf_8_jose) { "Jos\uFFFD".force_encoding(Encoding::UTF_8) }

  let(:utf_8_mixed_users) {
    [
      Struct::Passwd.new('root', 'x', 0, 0),
      Struct::Passwd.new('foo', 'x', 1000, 2000),
      Struct::Passwd.new(utf_8_jose, utf_8_jose, 1001, 2000), # UTF-8 character
      # In a UTF-8 environment, ruby will return strings labeled as UTF-8 even if they're not valid in UTF-8
      Struct::Passwd.new(invalid_utf_8_jose, invalid_utf_8_jose, 1002, 2000),
      nil
    ]
  }

  let(:latin_1_mixed_users) {
    [
      # In a LATIN-1 environment, ruby will return *all* strings labeled as LATIN-1
      Struct::Passwd.new('root'.force_encoding(Encoding::ISO_8859_1), 'x', 0, 0),
      Struct::Passwd.new('foo'.force_encoding(Encoding::ISO_8859_1), 'x', 1000, 2000),
      Struct::Passwd.new(utf_8_labeled_as_latin_1_jose, utf_8_labeled_as_latin_1_jose, 1002, 2000),
      Struct::Passwd.new(valid_latin1_jose, valid_latin1_jose, 1001, 2000), # UTF-8 character
      nil
    ]
  }

  describe "#options" do
    it "should add options for a valid property" do
      described_class.options :foo, :key1 => 'val1', :key2 => 'val2'
      described_class.options :bar, :key3 => 'val3'
      expect(described_class.option(:foo, :key1)).to eq('val1')
      expect(described_class.option(:foo, :key2)).to eq('val2')
      expect(described_class.option(:bar, :key3)).to eq('val3')
    end

    it "should raise an error for an invalid property" do
      expect { described_class.options :baz, :key1 => 'val1' }.to raise_error(
        Puppet::Error, 'baz is not a valid attribute for nameservice_dummytype')
    end
  end

  describe "#option" do
    it "should return the correct value" do
      described_class.options :foo, :key1 => 'val1', :key2 => 'val2'
      expect(described_class.option(:foo, :key2)).to eq('val2')
    end

    it "should symbolize the name first" do
      described_class.options :foo, :key1 => 'val1', :key2 => 'val2'
      expect(described_class.option('foo', :key2)).to eq('val2')
    end

    it "should return nil if no option has been specified earlier" do
      expect(described_class.option(:foo, :key2)).to be_nil
    end

    it "should return nil if no option for that property has been specified earlier" do
      described_class.options :bar, :key2 => 'val2'
      expect(described_class.option(:foo, :key2)).to be_nil
    end

    it "should return nil if no matching key can be found for that property" do
      described_class.options :foo, :key3 => 'val2'
      expect(described_class.option(:foo, :key2)).to be_nil
    end
  end

  describe "#section" do
    it "should raise an error if resource_type has not been set" do
      described_class.expects(:resource_type).returns nil
      expect { described_class.section }.to raise_error Puppet::Error, 'Cannot determine Etc section without a resource type'
    end

    # the return values are hard coded so I am using types that actually make
    # use of the nameservice provider
    it "should return pw for users" do
      described_class.resource_type = Puppet::Type.type(:user)
      expect(described_class.section).to eq('pw')
    end

    it "should return gr for groups" do
      described_class.resource_type = Puppet::Type.type(:group)
      expect(described_class.section).to eq('gr')
    end
  end

  describe "#listbyname" do
    it "should be deprecated" do
      Puppet.expects(:deprecation_warning).with(regexp_matches(/listbyname is deprecated/))
      described_class.listbyname
    end

    it "should return a list of users if resource_type is user" do
      described_class.resource_type = Puppet::Type.type(:user)
      Puppet::Etc.expects(:setpwent)
      Puppet::Etc.stubs(:getpwent).returns(*users)
      Puppet::Etc.expects(:endpwent)
      expect(described_class.listbyname).to eq(%w{root foo})
    end

    context "encoding handling" do
      described_class.resource_type = Puppet::Type.type(:user)

      # These two tests simulate an environment where there are two users with
      # the same name on disk, but each name is stored on disk in a different
      # encoding
      it "should return names with invalid byte sequences replaced with '?'" do
        Etc.stubs(:getpwent).returns(*utf_8_mixed_users)
        expect(invalid_utf_8_jose).to_not be_valid_encoding
        result = PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::UTF_8) do
          described_class.listbyname
        end
        expect(result).to eq(['root', 'foo', utf_8_jose, escaped_utf_8_jose])
      end

      it "should return names in their original encoding/bytes if they would not be valid UTF-8" do
        Etc.stubs(:getpwent).returns(*latin_1_mixed_users)
        result = PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::ISO_8859_1) do
          described_class.listbyname
        end
        expect(result).to eq(['root'.force_encoding(Encoding::UTF_8), 'foo'.force_encoding(Encoding::UTF_8), utf_8_jose, valid_latin1_jose])
      end
    end

    it "should return a list of groups if resource_type is group", :unless => Puppet.features.microsoft_windows? do
      described_class.resource_type = Puppet::Type.type(:group)
      Puppet::Etc.expects(:setgrent)
      Puppet::Etc.stubs(:getgrent).returns(*groups)
      Puppet::Etc.expects(:endgrent)
      expect(described_class.listbyname).to eq(%w{root bin})
    end

    it "should yield if a block given" do
      yield_results = []
      described_class.resource_type = Puppet::Type.type(:user)
      Puppet::Etc.expects(:setpwent)
      Puppet::Etc.stubs(:getpwent).returns(*users)
      Puppet::Etc.expects(:endpwent)
      described_class.listbyname {|x| yield_results << x }
      expect(yield_results).to eq(%w{root foo})
    end
  end

  describe "instances" do
    it "should return a list of objects in UTF-8 with any invalid characters replaced with '?'" do
      # These two tests simulate an environment where there are two users with
      # the same name on disk, but each name is stored on disk in a different
      # encoding
      Etc.stubs(:getpwent).returns(*utf_8_mixed_users)
      result = PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::UTF_8) do
        described_class.instances
      end
      expect(result.map(&:name)).to eq(
        [
          'root'.force_encoding(Encoding::UTF_8), # started as UTF-8 on disk, returned unaltered as UTF-8
          'foo'.force_encoding(Encoding::UTF_8), # started as UTF-8 on disk, returned unaltered as UTF-8
          utf_8_jose, # started as UTF-8 on disk, returned unaltered as UTF-8
          escaped_utf_8_jose # started as LATIN-1 on disk, but Etc returned as UTF-8 and we escaped invalid chars
        ]
      )
    end

    it "should have object names in their original encoding/bytes if they would not be valid UTF-8" do
      Etc.stubs(:getpwent).returns(*latin_1_mixed_users)
      result = PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::ISO_8859_1) do
        described_class.instances
      end
      expect(result.map(&:name)).to eq(
        [
          'root'.force_encoding(Encoding::UTF_8), # started as LATIN-1 on disk, we overrode to UTF-8
          'foo'.force_encoding(Encoding::UTF_8), # started as LATIN-1 on disk, we overrode to UTF-8
          utf_8_jose, # started as UTF-8 on disk, returned by Etc as LATIN-1, and we overrode to UTF-8
          valid_latin1_jose # started as LATIN-1 on disk, returned by Etc as valid LATIN-1, and we leave as LATIN-1
        ]
      )
    end

    it "should pass the Puppet::Etc :canonical_name Struct member to the constructor" do
      users = [ Struct::Passwd.new(invalid_utf_8_jose, invalid_utf_8_jose, 1002, 2000), nil ]
      Etc.stubs(:getpwent).returns(*users)
      described_class.expects(:new).with(:name => escaped_utf_8_jose, :canonical_name => invalid_utf_8_jose, :ensure => :present)
      described_class.instances
    end
  end

  describe "validate" do
    it "should pass if no check is registered at all" do
      expect { described_class.validate(:foo, 300) }.to_not raise_error
      expect { described_class.validate('foo', 300) }.to_not raise_error
    end

    it "should pass if no check for that property is registered" do
      described_class.verify(:bar, 'Must be 100') { |val| val == 100 }
      expect { described_class.validate(:foo, 300) }.to_not raise_error
      expect { described_class.validate('foo', 300) }.to_not raise_error
    end

    it "should pass if the value is valid" do
      described_class.verify(:foo, 'Must be 100') { |val| val == 100 }
      expect { described_class.validate(:foo, 100) }.to_not raise_error
      expect { described_class.validate('foo', 100) }.to_not raise_error
    end

    it "should raise an error if the value is invalid" do
      described_class.verify(:foo, 'Must be 100') { |val| val == 100 }
      expect { described_class.validate(:foo, 200) }.to raise_error(ArgumentError, 'Invalid value 200: Must be 100')
      expect { described_class.validate('foo', 200) }.to raise_error(ArgumentError, 'Invalid value 200: Must be 100')
    end
  end

  describe "getinfo" do
    before :each do
      # with section=foo we'll call Etc.getfoonam instead of getpwnam or getgrnam
      described_class.stubs(:section).returns 'foo'
      resource # initialize the resource so our provider has a @resource instance variable
    end

    it "should return a hash if we can retrieve something" do
      Puppet::Etc.expects(:send).with(:getfoonam, 'bob').returns fakeetcobject
      provider.expects(:info2hash).with(fakeetcobject).returns(:foo => 'fooval', :bar => 'barval')
      expect(provider.getinfo(true)).to eq({:foo => 'fooval', :bar => 'barval'})
    end

    it "should return nil if we cannot retrieve anything" do
      Puppet::Etc.expects(:send).with(:getfoonam, 'bob').raises(ArgumentError, "can't find bob")
      provider.expects(:info2hash).never
      expect(provider.getinfo(true)).to be_nil
    end

    # Nameservice instances track the original resource name on disk, before
    # overriding to UTF-8, in @canonical_name for querying that state on disk
    # again if needed
    it "should use the instance's @canonical_name to query the system" do
      provider_instance = described_class.new(:name => 'foo', :canonical_name => 'original_foo', :ensure => :present)
      Puppet::Etc.expects(:send).with(:getfoonam, 'original_foo')
      provider_instance.getinfo(true)
    end

    it "should use the instance's name instead of canonical_name if not supplied during instantiation" do
      provider_instance = described_class.new(:name => 'foo', :ensure => :present)
      Puppet::Etc.expects(:send).with(:getfoonam, 'foo')
      provider_instance.getinfo(true)
    end
  end

  describe "info2hash" do
    it "should return a hash with all properties" do
      # we have to have an implementation of posixmethod which has to
      # convert a propertyname (e.g. comment) into a fieldname of our
      # Struct (e.g. gecos). I do not want to test posixmethod here so
      # let's fake an implementation which does not do any translation. We
      # expect two method invocations because info2hash calls the method
      # twice if the Struct responds to the propertyname (our fake Struct
      # provides values for :foo and :bar) TODO: Fix that
      provider.expects(:posixmethod).with(:foo).returns(:foo).twice
      provider.expects(:posixmethod).with(:bar).returns(:bar).twice
      provider.expects(:posixmethod).with(:ensure).returns :ensure
      expect(provider.info2hash(fakeetcobject)).to eq({ :foo => 'fooval', :bar => 'barval' })
    end
  end

  describe "munge" do
    it "should return the input value if no munge method has be defined" do
      expect(provider.munge(:foo, 100)).to eq(100)
    end

    it "should return the munged value otherwise" do
      described_class.options(:foo, :munge => proc { |x| x*2 })
      expect(provider.munge(:foo, 100)).to eq(200)
    end
  end

  describe "unmunge" do
    it "should return the input value if no unmunge method has been defined" do
      expect(provider.unmunge(:foo, 200)).to eq(200)
    end

    it "should return the unmunged value otherwise" do
      described_class.options(:foo, :unmunge => proc { |x| x/2 })
      expect(provider.unmunge(:foo, 200)).to eq(100)
    end
  end


  describe "exists?" do
    it "should return true if we can retrieve anything" do
      provider.expects(:getinfo).with(true).returns(:foo => 'fooval', :bar => 'barval')
      expect(provider).to be_exists
    end
    it "should return false if we cannot retrieve anything" do
      provider.expects(:getinfo).with(true).returns nil
      expect(provider).not_to be_exists
    end
  end

  describe "get" do
    before(:each) {described_class.resource_type = faketype }

    it "should return the correct getinfo value" do
      provider.expects(:getinfo).with(false).returns(:foo => 'fooval', :bar => 'barval')
      expect(provider.get(:bar)).to eq('barval')
    end

    it "should unmunge the value first" do
      described_class.options(:bar, :munge => proc { |x| x*2}, :unmunge => proc {|x| x/2})
      provider.expects(:getinfo).with(false).returns(:foo => 200, :bar => 500)
      expect(provider.get(:bar)).to eq(250)
    end

    it "should return nil if getinfo cannot retrieve the value" do
      provider.expects(:getinfo).with(false).returns(:foo => 'fooval', :bar => 'barval')
      expect(provider.get(:no_such_key)).to be_nil
    end

  end

  describe "set" do
    before :each do
      resource # initialize resource so our provider has a @resource object
      described_class.verify(:foo, 'Must be 100') { |val| val == 100 }
    end

    it "should raise an error on invalid values" do
      expect { provider.set(:foo, 200) }.to raise_error(ArgumentError, 'Invalid value 200: Must be 100')
    end

    it "should execute the modify command on valid values" do
      provider.expects(:modifycmd).with(:foo, 100).returns ['/bin/modify', '-f', '100' ]
      provider.expects(:execute).with(['/bin/modify', '-f', '100'], has_entry(:custom_environment, {}))
      provider.set(:foo, 100)
    end

    it "should munge the value first" do
      described_class.options(:foo, :munge => proc { |x| x*2}, :unmunge => proc {|x| x/2})
      provider.expects(:modifycmd).with(:foo, 200).returns(['/bin/modify', '-f', '200' ])
      provider.expects(:execute).with(['/bin/modify', '-f', '200'], has_entry(:custom_environment, {}))
      provider.set(:foo, 100)
    end

    it "should fail if the modify command fails" do
      provider.expects(:modifycmd).with(:foo, 100).returns(['/bin/modify', '-f', '100' ])
      provider.expects(:execute).with(['/bin/modify', '-f', '100'], kind_of(Hash)).raises(Puppet::ExecutionFailure, "Execution of '/bin/modify' returned 1: some_failure")
      expect { provider.set(:foo, 100) }.to raise_error Puppet::Error, /Could not set foo/
    end
  end

  describe "comments_insync?" do
    # comments_insync? overrides Puppet::Property#insync? and will act on an
    # array containing a should value (the expected value of Puppet::Property
    # @should)
    context "given strings with compatible encodings" do
      it "should return false if the is-value and should-value are not equal" do
        is_value = "foo"
        should_value = ["bar"]
        expect(provider.comments_insync?(is_value, should_value)).to be_falsey
      end

      it "should return true if the is-value and should-value are equal" do
        is_value = "foo"
        should_value = ["foo"]
        expect(provider.comments_insync?(is_value, should_value)).to be_truthy
      end
    end

    context "given strings with incompatible encodings" do
      let(:snowman_iso) { "\u2603".force_encoding(Encoding::ISO_8859_1) }
      let(:snowman_utf8) { "\u2603".force_encoding(Encoding::UTF_8) }
      let(:snowman_binary) { "\u2603".force_encoding(Encoding::ASCII_8BIT) }
      let(:arabic_heh_utf8) { "\u06FF".force_encoding(Encoding::UTF_8) }

      it "should be able to compare unequal strings and return false" do
        expect(Encoding.compatible?(snowman_iso, arabic_heh_utf8)).to be_falsey
        expect(provider.comments_insync?(snowman_iso, [arabic_heh_utf8])).to be_falsey
      end

      it "should be able to compare equal strings and return true" do
        expect(Encoding.compatible?(snowman_binary, snowman_utf8)).to be_falsey
        expect(provider.comments_insync?(snowman_binary, [snowman_utf8])).to be_truthy
      end

      it "should not manipulate the actual encoding of either string" do
        expect(Encoding.compatible?(snowman_binary, snowman_utf8)).to be_falsey
        provider.comments_insync?(snowman_binary, [snowman_utf8])
        expect(snowman_binary.encoding).to eq(Encoding::ASCII_8BIT)
        expect(snowman_utf8.encoding).to eq(Encoding::UTF_8)
      end
    end
  end
end
