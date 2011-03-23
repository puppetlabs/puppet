require 'puppet/parameter'

class Puppet::Parameter::Path < Puppet::Parameter
  def self.accept_arrays(bool = true)
    @accept_arrays = !!bool
  end
  def self.arrays?
    @accept_arrays
  end

  def validate_path(paths)
    if paths.is_a?(Array) and ! self.class.arrays? then
      fail "#{name} only accepts a single path, not an array of paths"
    end

    # We *always* support Unix path separators, as Win32 does now too.
    absolute = "[/#{::Regexp.quote(::File::SEPARATOR)}]"
    win32    = Puppet.features.microsoft_windows?

    Array(paths).each do |path|
      next if path =~ %r{^#{absolute}}
      next if win32 and path =~ %r{^(?:[a-zA-Z]:)?#{absolute}}
      fail("#{name} must be a fully qualified path")
    end

    paths
  end

  # This will be overridden if someone uses the validate option, which is why
  # it just delegates to the other, useful, method.
  def unsafe_validate(paths)
    validate_path(paths)
  end

  # Likewise, this might be overridden, but by default...
  def unsafe_munge(paths)
    if paths.is_a?(Array) and ! self.class.arrays? then
      fail "#{name} only accepts a single path, not an array of paths"
    end
    paths
  end
end
