#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'mocha'

class TestTypeProviders < Test::Unit::TestCase
	include PuppetTest

    # Make sure default providers behave correctly
    def test_defaultproviders
        # Make a fake type
        type = Puppet::Type.newtype(:defaultprovidertest) do
            newparam(:name) do end
        end

        cleanup { Puppet::Type.rmtype(:defaultprovidertest) }

        basic = type.provide(:basic) do
            defaultfor :operatingsystem => :somethingelse,
                :operatingsystemrelease => :yayness
        end

        assert_equal(basic, type.defaultprovider)
        type.defaultprovider = nil

        greater = type.provide(:greater) do
            defaultfor :operatingsystem => Facter.value("operatingsystem")
        end

        assert_equal(greater, type.defaultprovider)
    end

    # Make sure the provider is always the first parameter created.
    def test_provider_sorting
        type = Puppet::Type.newtype(:sorttest) do
            newparam(:name) {}
            ensurable
        end
        cleanup { Puppet::Type.rmtype(:sorttest) }

        should = [:name, :ensure]
        assert_equal(should, type.allattrs.reject { |p| ! should.include?(p) },
            "Got wrong order of parameters")

        type.provide(:yay) { }
        should = [:name, :provider, :ensure]
        assert_equal(should, type.allattrs.reject { |p| ! should.include?(p) },
            "Providify did not reorder parameters")
    end

    def test_commands
        type = Puppet::Type.newtype(:commands) {}

        cleanup { Puppet::Type.rmtype(:commands) }

        echo = %x{which echo}.chomp
        {:echo => echo, :echo => "echo", :missing => "nosuchcommand", :missing => "/path/to/nosuchcommand"}.each do |name, command|
            # Define a provider with mandatory commands
            provider = type.provide(:testing) {}

            assert_nothing_raised("Could not define command %s with argument %s for provider" % [name, command]) do
                provider.commands(name => command)
            end

            case name
            when :echo:
                assert_equal(echo, provider.command(:echo), "Did not get correct path for echo")
                assert(provider.suitable?, "Provider was not considered suitable with 'echo'")
            when :missing:
                assert_nil(provider.command(:missing), "Somehow got a response for missing commands")
                assert(! provider.suitable?, "Provider was considered suitable with missing command")
            else
                raise "Invalid name %s" % name
            end

            type.unprovide(:testing)
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
            assert_nothing_raised("Could not create provider %s" % name) do
                @type.provide(name) do
                    methods.each do |name|
                        define_method(name) {}
                    end
                end
            end
        end

        model = @type.create(:name => "foo")
        {:numbers => [:numeric], :letters => [:alpha], :both => [:numeric, :alpha],
            :mixed => [], :neither => []}.each do |name, should|
                should.sort! { |a,b| a.to_s <=> b.to_s }
                provider = @type.provider(name)
                assert(provider, "Could not find provider %s" % name)
                assert_equal(should, provider.features,
                    "Provider %s has incorrect features" % name)

                inst = provider.new(model)
                # Make sure the boolean methods work on both the provider and
                # instance.
                @features.keys.each do |feature|
                    method = feature.to_s + "?"
                    assert(inst.respond_to?(method),
                        "No boolean instance method for %s on %s" %
                        [name, feature])
                    assert(provider.respond_to?(method),
                        "No boolean class method for %s on %s" % [name, feature])

                    if should.include?(feature)
                        assert(provider.feature?(feature),
                            "class missing feature? %s" % feature)
                        assert(inst.feature?(feature),
                            "instance missing feature? %s" % feature)
                        assert(provider.send(method),
                            "class missing feature %s" % feature)
                        assert(inst.send(method),
                            "instance missing feature %s" % feature)
                        assert(inst.satisfies?(feature),
                            "instance.satisfy %s returned false" % feature)
                    else
                        assert(! provider.feature?(feature),
                            "class has feature? %s" % feature)
                        assert(! inst.feature?(feature),
                            "instance has feature? %s" % feature)
                        assert(! provider.send(method),
                            "class has feature %s" % feature)
                        assert(! inst.send(method),
                            "instance has feature %s" % feature)
                        assert(! inst.satisfies?(feature),
                            "instance.satisfy %s returned true" % feature)
                    end
                end

            end

        Puppet[:trace] = true
        Puppet::Type.loadall
        Puppet::Type.eachtype do |type|
            assert(type.respond_to?(:feature),
                "No features method defined for %s" % type.name)
        end
    end

    def test_has_feature
        # Define a new feature that has no methods
        @type.feature(:nomeths, "desc")

        # Define a provider with nothing
        provider = @type.provide(:nothing) {}

        assert(provider.respond_to?(:has_features),
            "Provider did not get 'has_features' method added")

        # One with the numeric methods and nothing else
        @type.provide(:numbers) do
            define_method(:one) {}
            define_method(:two) {}
        end
        
        # Another with the numbers and a declaration
        @type.provide(:both) do
            define_method(:one) {}
            define_method(:two) {}

            has_features :alpha
        end
        
        # And just the declaration
        @type.provide(:letters) do
            has_features :alpha
        end

        # And a provider that declares it has our methodless feature.
        @type.provide(:none) do
            has_features :nomeths
        end

        should = {:nothing => [], :both => [:numeric, :alpha],
            :letters => [:alpha], :numbers => [:numeric],
            :none => [:nomeths]}

        should.each do |name, features|
            provider = @type.provider(name)
            assert(provider, "did not get provider named %s" % name)
            features.sort! { |a,b| a.to_s <=> b.to_s }
            assert_equal(features, provider.features,
                "Got incorrect feature list for %s" % name)
        end
    end
end

# $Id$
