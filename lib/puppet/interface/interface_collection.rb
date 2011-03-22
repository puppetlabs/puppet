require 'puppet/interface'

module Puppet::Interface::InterfaceCollection
  @interfaces = {}

  def self.interfaces
    unless @loaded
      @loaded = true
      $LOAD_PATH.each do |dir|
        next unless FileTest.directory?(dir)
        Dir.chdir(dir) do
          Dir.glob("puppet/interface/*.rb").collect { |f| f.sub(/\.rb/, '') }.each do |file|
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

  def self.[](name)
    @interfaces[underscorize(name)] if interface?(name)
  end

  def self.interface?(name)
    name = underscorize(name)
    require "puppet/interface/#{name}" unless @interfaces.has_key? name
    return @interfaces.has_key? name
  rescue LoadError
    return false
  end

  def self.register(interface)
    @interfaces[underscorize(interface.name)] = interface
  end

  def self.underscorize(name)
    unless name.to_s =~ /^[-_a-z]+$/i then
      raise ArgumentError, "#{name.inspect} (#{name.class}) is not a valid interface name"
    end

    name.to_s.downcase.split(/[-_]/).join('_').to_sym
  end
end
