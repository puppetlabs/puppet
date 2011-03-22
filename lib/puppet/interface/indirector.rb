require 'puppet'
require 'puppet/interface'

class Puppet::Interface::Indirector < Puppet::Interface
  def self.indirections
    Puppet::Indirector::Indirection.instances.collect { |t| t.to_s }.sort
  end

  def self.terminus_classes(indirection)
    Puppet::Indirector::Terminus.terminus_classes(indirection.to_sym).collect { |t| t.to_s }.sort
  end

  action :destroy do
    invoke { |*args| call_indirection_method(:destroy, *args) }
  end

  action :find do
    invoke { |*args| call_indirection_method(:find, *args) }
  end

  action :save do
    invoke { |*args| call_indirection_method(:save, *args) }
  end

  action :search do
    invoke { |*args| call_indirection_method(:search, *args) }
  end

  # Print the configuration for the current terminus class
  action :info do
    invoke do |*args|
      if t = indirection.terminus_class
        puts "Run mode '#{Puppet.run_mode.name}': #{t}"
      else
        $stderr.puts "No default terminus class for run mode '#{Puppet.run_mode.name}'"
      end
    end
  end

  attr_accessor :from

  def indirection_name
    @indirection_name || name.to_sym
  end

  # Here's your opportunity to override the indirection name.  By default
  # it will be the same name as the interface.
  def set_indirection_name(name)
    @indirection_name = name
  end

  # Return an indirection associated with an interface, if one exists
  # One usually does.
  def indirection
    unless @indirection
      Puppet.info("Could not find terminus for #{indirection_name}") unless @indirection = Puppet::Indirector::Indirection.instance(indirection_name)
    end
    @indirection
  end

  def set_terminus(from)
    begin
      indirection.terminus_class = from
    rescue => detail
      raise "Could not set '#{indirection.name}' terminus to '#{from}' (#{detail}); valid terminus types are #{terminus_classes(indirection.name).join(", ") }"
    end
  end

  def call_indirection_method(method, *args)
    begin
      result = indirection.send(method, *args)
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      raise "Could not call '#{method}' on '#{indirection_name}': #{detail}"
    end

    result
  end
end
