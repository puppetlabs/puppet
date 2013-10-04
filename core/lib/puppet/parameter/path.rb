require 'puppet/parameter'

# This specialized {Puppet::Parameter} handles validation and munging of paths.
# By default, a single path is accepted, and by calling {accept_arrays} it is possible to
# allow an array of paths.
#
class Puppet::Parameter::Path < Puppet::Parameter
  # Specifies whether multiple paths are accepted or not.
  # @dsl type
  #
  def self.accept_arrays(bool = true)
    @accept_arrays = !!bool
  end
  def self.arrays?
    @accept_arrays
  end

  # Performs validation of the given paths.
  # If the concrete parameter defines a validation method, it may call this method to perform
  # path validation.
  # @raise [Puppet::Error] if this property is configured for single paths and an array is given
  # @raise [Puppet::Error] if a path is not an absolute path
  # @return [Array<String>] the given paths
  #
  def validate_path(paths)
    if paths.is_a?(Array) and ! self.class.arrays? then
      fail "#{name} only accepts a single path, not an array of paths"
    end

    fail("#{name} must be a fully qualified path") unless Array(paths).all? {|path| absolute_path?(path)}

    paths
  end

  # This is the default implementation of the `validate` method.
  # It will be overridden if the validate option is used when defining the parameter.
  # @return [void]
  #
  def unsafe_validate(paths)
    validate_path(paths)
  end

  # This is the default implementation  of `munge`.
  # If the concrete parameter defines a `munge` method, this default implementation will be overridden.
  # This default implementation does not perform any munging, it just checks the one/many paths
  # constraints. A derived implementation can perform this check as:
  # `paths.is_a?(Array) and ! self.class.arrays?` and raise a {Puppet::Error}.
  # @param paths [String, Array<String>] one of multiple paths
  # @return [String, Array<String>] the given paths
  # @raise [Puppet::Error] if the given paths does not comply with the on/many paths rule.
  def unsafe_munge(paths)
    if paths.is_a?(Array) and ! self.class.arrays? then
      fail "#{name} only accepts a single path, not an array of paths"
    end
    paths
  end
end
