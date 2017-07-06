# Provides feature definitions.
require 'puppet/util/methodhelper'
require 'puppet/util/docs'
require 'puppet/util'
# This module models provider features and handles checking whether the features
# are present.
# @todo Unclear what is api and what is private in this module.
#
module Puppet::Util::ProviderFeatures
  include Puppet::Util::Docs
  # This class models provider features and handles checking whether the features
  # are present.
  # @todo Unclear what is api and what is private in this class
  class ProviderFeature
    include Puppet::Util
    include Puppet::Util::MethodHelper
    include Puppet::Util::Docs
    attr_accessor :name, :docs, :methods

    # Are all of the requirements met?
    # Requirements are checked by checking if feature predicate methods have been generated - see {#methods_available?}.
    # @param obj [Object, Class] the object or class to check if requirements are met
    # @return [Boolean] whether all requirements for this feature are met or not.
    def available?(obj)
      if self.methods
        return !!methods_available?(obj)
      else
        # In this case, the provider has to declare support for this
        # feature, and that's been checked before we ever get to the
        # method checks.
        return false
      end
    end

    def initialize(name, docs, hash)
      self.name = name.intern
      self.docs = docs
      hash = symbolize_options(hash)
      set_options(hash)
    end

    private

    # Checks whether all feature predicate methods are available.
    # @param obj [Object, Class] the object or class to check if feature predicates are available or not.
    # @return [Boolean] Returns whether all of the required methods are available or not in the given object.
    def methods_available?(obj)
      methods.each do |m|
        if obj.is_a?(Class)
          return false unless obj.public_method_defined?(m)
        else
          return false unless obj.respond_to?(m)
        end
      end
      true
    end
  end

  # Defines one feature.
  # At a minimum, a feature requires a name
  # and docs, and at this point they should also specify a list of methods
  # required to determine if the feature is present.
  # @todo How methods that determine if the feature is present are specified.
  def feature(name, docs, hash = {})
    @features ||= {}
    raise(Puppet::DevError, "Feature #{name} is already defined") if @features.include?(name)
    begin
      obj = ProviderFeature.new(name, docs, hash)
      @features[obj.name] = obj
    rescue ArgumentError => detail
      error = ArgumentError.new(
        "Could not create feature #{name}: #{detail}"
      )
      error.set_backtrace(detail.backtrace)
      raise error
    end
  end

  # @return [String] Returns a string with documentation covering all features.
  def featuredocs
    str = ""
    @features ||= {}
    return nil if @features.empty?
    names = @features.keys.sort { |a,b| a.to_s <=> b.to_s }
    names.each do |name|
      doc = @features[name].docs.gsub(/\n\s+/, " ")
      str << "- *#{name}*: #{doc}\n"
    end

    if providers.length > 0
      headers = ["Provider", names].flatten
      data = {}
      providers.each do |provname|
        data[provname] = []
        prov = provider(provname)
        names.each do |name|
          if prov.feature?(name)
            data[provname] << "*X*"
          else
            data[provname] << ""
          end
        end
      end
      str << doctable(headers, data)
    end
    str
  end

  # @return [Array<String>] Returns a list of features.
  def features
    @features ||= {}
    @features.keys
  end

  # Generates a module that sets up the boolean predicate methods to test for given features.
  #
  def feature_module
    unless defined?(@feature_module)
      @features ||= {}
      @feature_module = ::Module.new
      const_set("FeatureModule", @feature_module)
      features = @features
      # Create a feature? method that can be passed a feature name and
      # determine if the feature is present.
      @feature_module.send(:define_method, :feature?) do |name|
        method = name.to_s + "?"
        return !!(respond_to?(method) and send(method))
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
          @declared_features << name.intern
        end
      end
      # Aaah, grammatical correctness
      @feature_module.send(:alias_method, :has_feature, :has_features)
    end
    @feature_module
  end

  # @return [ProviderFeature] Returns a provider feature instance by name.
  # @param name [String] the name of the feature to return
  # @note Should only be used for testing.
  # @api private
  #
  def provider_feature(name)
    return nil unless defined?(@features)

    @features[name]
  end
end

