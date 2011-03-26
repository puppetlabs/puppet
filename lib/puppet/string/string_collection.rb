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

  def self.versions(name)
    versions = []
    $LOAD_PATH.each do |dir|
      next unless FileTest.directory?(dir)
      v_dir = File.join dir, %w[puppet string v*]
      Dir.glob(File.join v_dir, "#{name}{.rb,/*.rb}").each do |f|
        v = f.sub(%r[.*/v([^/]+?)/#{name}(?:(?:/[^/]+)?.rb)$], '\1')
        if validate_version(v)
          versions << v
        else
          warn "'#{v}' (#{f}) is not a valid version string; skipping"
        end
      end
    end
    return versions.uniq.sort { |a, b| compare_versions(a, b)  }
  end

  def self.validate_version(version)
    !!(SEMVER_VERSION =~ version.to_s)
  end

  def self.compare_versions(a, b)
    a, b = [a, b].map do |x|
      parts = SEMVER_VERSION.match(x).to_a[1..4]
      parts[0..2] = parts[0..2].map { |e| e.to_i }
      parts
    end

    cmp = a[0..2] <=> b[0..2]
    if cmp == 0
      cmp = a[3] <=> b[3]
      cmp = +1 if a[3].empty? && !b[3].empty?
      cmp = -1 if b[3].empty? && !a[3].empty?
    end
    cmp
  end

  def self.[](name, version)
    version = versions(name).last if version == :latest
    unless version.nil?
      @strings[underscorize(name)][version] if string?(name, version)
    end
  end

  def self.string?(name, version)
    version = versions(name).last if version == :latest
    return false if version.nil?

    name = underscorize(name)

    unless @strings.has_key?(name) && @strings[name].has_key?(version)
      require "puppet/string/v#{version}/#{name}"
    end
    return @strings.has_key?(name) && @strings[name].has_key?(version)
  rescue LoadError
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
