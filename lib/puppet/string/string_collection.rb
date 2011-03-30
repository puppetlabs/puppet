require 'puppet/string'

module Puppet::String::StringCollection
  SEMVER_VERSION = /^(\d+)\.(\d+)\.(\d+)([A-Za-z][0-9A-Za-z-]*|)$/

  @strings = Hash.new { |hash, key| hash[key] = {} }

  def self.strings
    unless @loaded
      @loaded = true
      $LOAD_PATH.each do |dir|
        next unless FileTest.directory?(dir)
        Dir.chdir(dir) do
          Dir.glob("puppet/string/v*/*.rb").collect { |f| f.sub(/\.rb/, '') }.each do |file|
            iname = file.sub(/\.rb/, '')
            begin
              require iname
            rescue Exception => detail
              puts detail.backtrace if Puppet[:trace]
              raise "Could not load #{iname} from #{dir}/#{file}: #{detail}"
            end
          end
        end
      end
    end
    return @strings.keys
  end

  def self.validate_version(version)
    !!(SEMVER_VERSION =~ version.to_s)
  end

  def self.[](name, version)
    @strings[underscorize(name)][version] if string?(name, version)
  end

  def self.string?(name, version)
    name = underscorize(name)
    cache = @strings[name]
    return true if cache.has_key?(version)

    loaded = cache.keys

    module_names = ["puppet/string/#{name}"]
    unless version == :current
      module_names << "#{name}@#{version}/puppet/string/#{name}"
    end

    module_names.each do |module_name|
      begin
        require module_name
        if version == :current || !module_name.include?('@')
          loaded = (cache.keys - loaded).first
          cache[:current] = cache[loaded] unless loaded.nil?
        end
        return true if cache.has_key?(version)
      rescue LoadError => e
        raise unless e.message =~ /-- #{module_name}$/
        # pass
      end
    end

    return false
  end

  def self.register(string)
    @strings[underscorize(string.name)][string.version] = string
  end

  def self.underscorize(name)
    unless name.to_s =~ /^[-_a-z]+$/i then
      raise ArgumentError, "#{name.inspect} (#{name.class}) is not a valid string name"
    end

    name.to_s.downcase.split(/[-_]/).join('_').to_sym
  end
end
