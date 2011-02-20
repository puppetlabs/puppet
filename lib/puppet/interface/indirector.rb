require 'puppet'
require 'puppet/interface'

class Puppet::Interface::Indirector < Puppet::Interface

  # This is just a base class.
  @abstract = true

  # Here's your opportunity to override the indirection name.  By default
  # it will be the same name as the interface.
  def self.indirection_name
    name.to_sym
  end

  # Return an indirection associated with an interface, if one exists
  # One usually does.
  def self.indirection
    unless @indirection
      Puppet.info("Could not find terminus for #{indirection_name}") unless @indirection = Puppet::Indirector::Indirection.instance(indirection_name)
    end
    @indirection
  end

  attr_accessor :from, :indirection

  action :destroy do |name, *args|
    call_indirection_method(:destroy, name, *args)
  end

  action :find do |name, *args|
    call_indirection_method(:find, name, *args)
  end

  action :save do |name, *args|
    call_indirection_method(:save, name, *args)
  end

  action :search do |name, *args|
    call_indirection_method(:search, name, *args)
  end

  def indirection
    self.class.indirection
  end

  def initialize(options = {})
    options.each { |opt, val| send(opt.to_s + "=", val) }

    Puppet::Util::Log.newdestination :console

    self.class.load_actions
  end

  def set_terminus(from)
    begin
      indirection.terminus_class = from
    rescue => detail
      raise "Could not set '#{indirection.name}' terminus to '#{from}' (#{detail}); valid terminus types are #{terminus_classes(indirection.name).join(", ") }"
    end
  end

  def call_indirection_method(method, name, *args)
    begin
      result = indirection.send(method, name, *args)
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      raise "Could not call #{method} on #{type}: #{detail}"
    end

    unless result
      raise "Could not #{method} #{indirection.name} for #{name}"
    end

    result
  end

  def indirections
      Puppet::Indirector::Indirection.instances.collect { |t| t.to_s }.sort
  end

  def terminus_classes(indirection)
      Puppet::Indirector::Terminus.terminus_classes(indirection).collect { |t| t.to_s }.sort
  end
end
