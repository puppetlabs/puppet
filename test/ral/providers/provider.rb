#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'facter'

class TestProvider < Test::Unit::TestCase
  include PuppetTest

  def echo
    echo = Puppet::Util.which("echo")

    raise "Could not find 'echo' binary; cannot complete test" unless echo

    echo
  end

  def newprovider
    # Create our provider
    provider = Class.new(Puppet::Provider) do
      @name = :fakeprovider
    end
    provider.initvars

    provider
  end

  def setup
    super
    @type = Puppet::Type.newtype(:provider_test) do
      newparam(:name) {}
      ensurable
    end
    cleanup { Puppet::Type.rmtype(:provider_test) }
  end

  def test_confine_defaults_to_suitable

    provider = newprovider
    assert(provider.suitable?, "Marked unsuitable with no confines")
  end

  def test_confine_results
    {
      {:true => true} => true,
      {:true => false} => false,
      {:false => false} => true,
      {:false => true} => false,
      {:operatingsystem => Facter.value(:operatingsystem)} => true,
      {:operatingsystem => :yayness} => false,
      {:nothing => :yayness} => false,
      {:exists => echo} => true,
      {:exists => "/this/file/does/not/exist"} => false,
    }.each do |hash, result|
      provider = newprovider

      # First test :true
      hash.each do |test, val|
        assert_nothing_raised do
          provider.confine test => val
        end
      end

      assert_equal(result, provider.suitable?, "Failed for #{hash.inspect}")

      provider.initvars
    end
  end

  def test_multiple_confines_do_not_override
    provider = newprovider

    # Make sure multiple confines don't overwrite each other
    provider.confine :true => false
    assert(! provider.suitable?)
    provider.confine :true => true
    assert(! provider.suitable?)
  end

  def test_one_failed_confine_is_sufficient

    provider = newprovider

    # Make sure we test multiple of them, and that a single false wins
    provider.confine :true => true, :false => false
    assert(provider.suitable?)
    provider.confine :true => false
    assert(! provider.suitable?)
  end

  # #1197 - the binary should not be
  def test_command_checks_for_binaries_each_time
    provider = newprovider

    provider.commands :testing => "/no/such/path"

    provider.stubs(:which).returns "/no/such/path"

    provider.command(:testing)
    assert_equal("/no/such/path", provider.command(:testing), "Did not return correct binary path")
  end

  def test_command
    {:echo => "echo", :echo_with_path => echo, :missing => "nosuchcommand", :missing_qualified => "/path/to/nosuchcommand"}.each do |name, command|
      provider = newprovider
      assert_nothing_raised("Could not define command #{name} with argument #{command} for provider") do
        provider.commands(name => command)
      end

      if name.to_s =~ /missing/
        assert_nil(provider.command(name), "Somehow got a response for missing commands")
        assert(! provider.suitable?, "Provider was considered suitable with missing command")
        next # skip, since we don't do any validity checking here.
      end

      assert_equal(echo, provider.command(name), "Did not get correct path for echo")
      assert(provider.suitable?, "Provider was not considered suitable with 'echo'")

      # Now make sure they both work
      inst = provider.new(nil)
      [provider, inst].each do |thing|
        assert_nothing_raised("Could not call #{command} on #{thing}") do
          out = thing.send(name, "some", "text")
          assert_equal("some text\n", out)
        end
      end

      assert(provider.suitable?, "Provider considered unsuitable")

      # Now add an invalid command
      assert_nothing_raised do
        provider.commands :fake => "nosuchcommanddefinitely"
      end
      assert(! provider.suitable?, "Provider considered suitable")

      assert_nil(provider.command(:fake), "Got a value for missing command")
      assert_raise(Puppet::Error) do
        provider.fake
      end

      Puppet[:trace] = false
      assert_raise(Puppet::DevError) do
        provider.command(:nosuchcmd)
      end

      # Lastly, verify that we can find our superclass commands
      newprov = Class.new(provider)
      newprov.initvars

      assert_equal(echo, newprov.command(name))
    end
  end

  def test_default?
    provider = newprovider

    assert(! provider.default?, "Was considered default with no settings")

    assert_nothing_raised do
      provider.defaultfor :operatingsystem => Facter.value(:operatingsystem)
    end

    assert(provider.default?, "Was not considered default")

    # Make sure any true value is sufficient.
    assert_nothing_raised do
      provider.defaultfor :operatingsystem => [
        :yayness, :rahness,
        Facter.value(:operatingsystem)
      ]
    end

    assert(provider.default?, "Was not considered default")

    # Now make sure that a random setting returns false.
    assert_nothing_raised do
      provider.defaultfor :operatingsystem => :yayness
    end

    assert(! provider.default?, "Was considered default")
  end

  # Make sure that failed commands get their output in the error.
  def test_outputonfailure
    provider = newprovider

    dir = tstdir
    file = File.join(dir, "mycmd")
    sh = Puppet::Util.which("sh")
    File.open(file, "w") { |f|
      f.puts %{#!#{sh}
      echo A Failure >&2
      exit 2
      }
    }
    File.chmod(0755, file)

    provider.commands :cmd => file

    inst = provider.new(nil)

    assert_raise(Puppet::ExecutionFailure) do
      inst.cmd "some", "arguments"
    end

    out = nil
    begin
      inst.cmd "some", "arguments"
    rescue Puppet::ExecutionFailure => detail
      out = detail.to_s
    end


      assert(
        out =~ /A Failure/,

        "Did not receive command output on failure")


          assert(
            out =~ /Execution of/,

        "Did not receive info wrapper on failure")
  end

  def test_mk_resource_methods
    prov = newprovider
    resourcetype = Struct.new(:validproperties, :parameters)
    m = resourcetype.new([:prop1, :prop2], [:param1, :param2])
    prov.resource_type = m

    assert_nothing_raised("could not call mk_resource_methods") do
      prov.mk_resource_methods
    end

    obj = prov.new(nil)

    %w{prop1 prop2 param1 param2}.each do |param|
      assert(prov.public_method_defined?(param), "no getter for #{param}")
      assert(prov.public_method_defined?(param + "="), "no setter for #{param}")


        assert_equal(
          :absent, obj.send(param),

          "%s did not default to :absent")
      val = "testing #{param}"
      assert_nothing_raised("Could not call setter for #{param}") do
        obj.send(param + "=", val)
      end

        assert_equal(
          val, obj.send(param),

          "did not get correct value for #{param}")
    end
  end

  # Make sure optional commands get looked up but don't affect suitability.
  def test_optional_commands
    type = Puppet::Type.newtype(:optional_commands) {}

    cleanup { Puppet::Type.rmtype(:optional_commands) }

    # Define a provider with mandatory commands
    required = type.provide(:required) {
      commands :missing => "/no/such/binary/definitely"
    }

    # And another with optional commands
    optional = type.provide(:optional) {
      optional_commands :missing => "/no/such/binary/definitely"
    }

    assert(! required.suitable?, "Provider with missing commands considered suitable")
    assert_nil(required.command(:missing), "Provider returned non-nil from missing command")

    assert(optional.suitable?, "Provider with optional commands considered unsuitable")
    assert_nil(optional.command(:missing), "Provider returned non-nil from missing command")

    assert_raise(Puppet::Error, "Provider did not fail when missing command was called") do
      optional.missing
    end
  end

  # Disabling, since I might not keep this interface
  def disabled_test_read_and_each
    # Create a new provider
    provider = @type.provide(:testing)

    assert_raise(Puppet::DevError, "Did not fail when :read was not overridden") do
      provider.read
    end

    children = [:one, :two]
    provider.meta_def(:read) do
      children
    end

    result = []
    assert_nothing_raised("could not call 'each' on provider class") do
      provider.each { |i| result << i }
    end

    assert_equal(children, result, "did not get correct list from each")

    assert_equal(children, provider.collect { |i| i }, "provider does not include enumerable")
  end

  def test_source
    base = @type.provide(:base)

    assert_equal(:base, base.source, "source did not default correctly")
    assert_equal(:base, base.source, "source did not default correctly")

    sub = @type.provide(:sub, :parent => :base)

    assert_equal(:sub, sub.source, "source did not default correctly for sub class")
    assert_equal(:sub, sub.source, "source did not default correctly for sub class")

    other = @type.provide(:other, :parent => :base, :source => :base)

    assert_equal(:base, other.source, "source did not override")
    assert_equal(:base, other.source, "source did not override")
  end

  # Make sure we can initialize with either a resource or a hash, or none at all.
  def test_initialize
    test = @type.provide(:test)

    inst = @type.new :name => "boo"
    prov = nil
    assert_nothing_raised("Could not init with a resource") do
      prov = test.new(inst)
    end
    assert_equal(prov.resource, inst, "did not set resource correctly")
    assert_equal(inst.name, prov.name, "did not get resource name")

    params = {:name => :one, :ensure => :present}
    assert_nothing_raised("Could not init with a hash") do
      prov = test.new(params)
    end
    assert_equal(params, prov.send(:instance_variable_get, "@property_hash"), "did not set resource correctly")
    assert_equal(:one, prov.name, "did not get name from hash")

    assert_nothing_raised("Could not init with no argument") do
      prov = test.new
    end

    assert_raise(Puppet::DevError, "did not fail when no name is present") do
      prov.name
    end
  end
end

class TestProviderFeatures < Test::Unit::TestCase
  include PuppetTest

  def setup
    super
    @type = Puppet::Type.newtype(:feature_test) do
      newparam(:name) {}
      ensurable
    end
    cleanup { Puppet::Type.rmtype(:feature_test) }

    @features = {:numeric => [:one, :two], :alpha => [:a, :b]}

    @features.each do |name, methods|
      assert_nothing_raised("Could not define features") do
        @type.feature(name, "boo", :methods => methods)
      end
    end
  end

  # Give them the basic run-through.
  def test_method_features
    @providers = {:numbers => @features[:numeric], :letters => @features[:alpha]}
    @providers[:both] = @features[:numeric] + @features[:alpha]
    @providers[:mixed] = [:one, :b]
    @providers[:neither] = [:something, :else]

    @providers.each do |name, methods|
      assert_nothing_raised("Could not create provider #{name}") do
        @type.provide(name) do
          methods.each do |name|
            define_method(name) {}
          end
        end
      end
    end

    resource = @type.new(:name => "foo")
    {:numbers => [:numeric], :letters => [:alpha], :both => [:numeric, :alpha], :mixed => [], :neither => []}.each do |name, should|
      should.sort! { |a,b| a.to_s <=> b.to_s }
      provider = @type.provider(name)
      assert(provider, "Could not find provider #{name}")
      assert_equal(should, provider.features, "Provider #{name} has incorrect features")

      inst = provider.new(resource)
      # Make sure the boolean methods work on both the provider and
      # instance.
      @features.keys.each do |feature|
        method = feature.to_s + "?"
        assert(inst.respond_to?(method), "No boolean instance method for #{name} on #{feature}")
        assert(provider.respond_to?(method), "No boolean class method for #{name} on #{feature}")

        if should.include?(feature)
          assert(provider.feature?(feature), "class missing feature? #{feature}")
          assert(inst.feature?(feature), "instance missing feature? #{feature}")
          assert(provider.send(method), "class missing feature #{feature}")
          assert(inst.send(method), "instance missing feature #{feature}")
          assert(inst.satisfies?(feature), "instance.satisfy #{feature} returned false")
          else
            assert(! provider.feature?(feature), "class has feature? #{feature}")
            assert(! inst.feature?(feature), "instance has feature? #{feature}")
            assert(! provider.send(method), "class has feature #{feature}")
            assert(! inst.send(method), "instance has feature #{feature}")
            assert(! inst.satisfies?(feature), "instance.satisfy #{feature} returned true")
          end
        end

      end

    Puppet[:trace] = true
    Puppet::Type.loadall
    Puppet::Type.eachtype do |type|
      assert(type.respond_to?(:feature), "No features method defined for #{type.name}")
    end
  end

  def test_has_feature
    # Define a new feature that has no methods
    @type.feature(:nomeths, "desc")

    # Define a provider with nothing
    provider = @type.provide(:nothing) {}


      assert(
        provider.respond_to?(:has_features),

      "Provider did not get 'has_features' method added")

        assert(
          provider.respond_to?(:has_feature),

      "Provider did not get the 'has_feature' alias method")

    # One with the numeric methods and nothing else
    @type.provide(:numbers) do
      define_method(:one) {}
      define_method(:two) {}
    end

    # Another with the numbers and a declaration
    @type.provide(:both) do
      define_method(:one) {}
      define_method(:two) {}

      has_feature :alpha
    end

    # And just the declaration
    @type.provide(:letters) do
      has_feature :alpha
    end

    # And a provider that declares it has our methodless feature.
    @type.provide(:none) do
      has_feature :nomeths
    end

    should = {:nothing => [], :both => [:numeric, :alpha],
      :letters => [:alpha], :numbers => [:numeric],
      :none => [:nomeths]}

    should.each do |name, features|
      provider_class = @type.provider(name)
      provider = provider_class.new({})

      assert(provider, "did not get provider named #{name}")
      features.sort! { |a,b| a.to_s <=> b.to_s }
      assert_equal(features, provider.features, "Got incorrect feature list for provider instance #{name}")
      assert_equal(features, provider_class.features, "Got incorrect feature list for provider class #{name}")
      features.each do |feat|
        assert(provider.feature?(feat), "Provider instance #{name} did not have feature #{feat}")
        assert(provider_class.feature?(feat), "Provider class #{name} did not have feature #{feat}")
      end
    end
  end

  def test_supports_parameter?
    # Make some parameters for each setting
    @type.newparam(:neither) {}
    @type.newparam(:some, :required_features => :alpha)
    @type.newparam(:both, :required_features => [:alpha, :numeric])

    # and appropriate providers
    nope = @type.provide(:nope) {}
    maybe = @type.provide(:maybe) { has_feature(:alpha) }
    yep = @type.provide(:yep) { has_features(:alpha, :numeric) }

    # Now make sure our providers answer correctly.
    [nope, maybe, yep].each do |prov|
      assert(prov.respond_to?(:supports_parameter?), "#{prov.name} does not respond to :supports_parameter?")
      case prov.name
      when :nope
        supported = [:neither]
        un = [:some, :both]
      when :maybe
        supported = [:neither, :some]
        un = [:both]
      when :yep
        supported = [:neither, :some, :both]
        un = []
      end

      supported.each do |param|
        assert(prov.supports_parameter?(param), "#{param} was not supported by #{prov.name}")
      end
      un.each do |param|
        assert(! prov.supports_parameter?(param), "#{param} was incorrectly supported by #{prov.name}")
      end
    end
  end
end

