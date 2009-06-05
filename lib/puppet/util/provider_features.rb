# Provides feature definitions.
require 'puppet/util/methodhelper'
require 'puppet/util/docs'
require 'puppet/util'
module Puppet::Util::ProviderFeatures
    include Puppet::Util::Docs
    # The class that models the features and handles checking whether the features
    # are present.
    class ProviderFeature
        include Puppet::Util
        include Puppet::Util::MethodHelper
        include Puppet::Util::Docs
        attr_accessor :name, :docs, :methods

        # Are all of the requirements met?
        def available?(obj)
            if self.methods
                if methods_available?(obj)
                    return true
                else
                    return false
                end
            else
                # In this case, the provider has to declare support for this
                # feature, and that's been checked before we ever get to the
                # method checks.
                return false
            end
        end

        def initialize(name, docs, hash)
            self.name = symbolize(name)
            self.docs = docs
            hash = symbolize_options(hash)
            set_options(hash)
        end

        private

        # Are all of the required methods available?
        def methods_available?(obj)
            methods.each do |m|
                if obj.is_a?(Class)
                    return false unless obj.public_method_defined?(m)
                else
                    return false unless obj.respond_to?(m)
                end
            end
            return true
        end
    end

    # Define one or more features.  At a minimum, features require a name
    # and docs, and at this point they should also specify a list of methods
    # required to determine if the feature is present.
    def feature(name, docs, hash = {})
        @features ||= {}
        raise(Puppet::DevError, "Feature %s is already defined" % name) if @features.include?(name)
        begin
            obj = ProviderFeature.new(name, docs, hash)
            @features[obj.name] = obj
        rescue ArgumentError => detail
            error = ArgumentError.new(
                "Could not create feature %s: %s" % [name, detail]
            )
            error.set_backtrace(detail.backtrace)
            raise error
        end
    end

    # Return a hash of all feature documentation.
    def featuredocs
        str = ""
        @features ||= {}
        return nil if @features.empty?
        names = @features.keys.sort { |a,b| a.to_s <=> b.to_s }
        names.each do |name|
            doc = @features[name].docs.gsub(/\n\s+/, " ")
            str += "- **%s**: %s\n" % [name, doc]
        end

        if providers.length > 0
            headers = ["Provider", names].flatten
            data = {}
            providers.each do |provname|
                data[provname] = []
                prov = provider(provname)
                names.each do |name|
                    if prov.feature?(name)
                        data[provname] << "**X**"
                    else
                        data[provname] << ""
                    end
                end
            end
            str += doctable(headers, data)
        end
        str
    end

    # Return a list of features.
    def features
        @features ||= {}
        @features.keys
    end

    # Generate a module that sets up the boolean methods to test for given
    # features.
    def feature_module
        unless defined? @feature_module
            @features ||= {}
            @feature_module = ::Module.new
            const_set("FeatureModule", @feature_module)
            features = @features
            # Create a feature? method that can be passed a feature name and
            # determine if the feature is present.
            @feature_module.send(:define_method, :feature?) do |name|
                method = name.to_s + "?"
                if respond_to?(method) and send(method)
                    return true
                else
                    return false
                end
            end

            # Create a method that will list all functional features.
            @feature_module.send(:define_method, :features) do
                return false unless defined?(features)
                features.keys.find_all { |n| feature?(n) }.sort { |a,b|
                    a.to_s <=> b.to_s
                }
            end

            # Create a method that will determine if a provided list of
            # features are satisfied by the curred provider.
            @feature_module.send(:define_method, :satisfies?) do |*needed|
                ret = true
                needed.flatten.each do |feature|
                    unless feature?(feature)
                        ret = false
                        break
                    end
                end
                ret
            end

            # Create a boolean method for each feature so you can test them
            # individually as you might need.
            @features.each do |name, feature|
                method = name.to_s + "?"
                @feature_module.send(:define_method, method) do
                    (is_a?(Class) ?  declared_feature?(name) : self.class.declared_feature?(name)) or feature.available?(self)
                end
            end

            # Allow the provider to declare that it has a given feature.
            @feature_module.send(:define_method, :has_features) do |*names|
                @declared_features ||= []
                names.each do |name|
                    name = symbolize(name)
                    @declared_features << name
                end
            end
            # Aaah, grammatical correctness
            @feature_module.send(:alias_method, :has_feature, :has_features)
        end
        @feature_module
    end

    # Return the actual provider feature instance.  Really only used for testing.
    def provider_feature(name)
        return nil unless defined?(@features)

        @features[name]
    end
end

