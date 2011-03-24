require 'puppet/interface'

module Puppet::Interface::InterfaceCollection
  @interfaces = Hash.new { |hash, key| hash[key] = {} }

  def self.interfaces
    unless @loaded
      @loaded = true
      $LOAD_PATH.each do |dir|
        next unless FileTest.directory?(dir)
        Dir.chdir(dir) do
          Dir.glob("puppet/interface/v*/*.rb").collect { |f| f.sub(/\.rb/, '') }.each do |file|
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
    return @interfaces.keys
  end

  def self.[](name, version)
    @interfaces[underscorize(name)][version] if interface?(name, version)
  end

  def self.interface?(name, version)
    name = underscorize(name)
    unless @interfaces.has_key?(name) && @interfaces[name].has_key?(version)
      require "puppet/interface/v#{version}/#{name}"
    end
    return @interfaces.has_key?(name) && @interfaces[name].has_key?(version)
  rescue LoadError
    return false
  end

  def self.register(interface)
    @interfaces[underscorize(interface.name)][interface.version] = interface
  end

  def self.underscorize(name)
    unless name.to_s =~ /^[-_a-z]+$/i then
      raise ArgumentError, "#{name.inspect} (#{name.class}) is not a valid interface name"
    end

    name.to_s.downcase.split(/[-_]/).join('_').to_sym
  end
end
