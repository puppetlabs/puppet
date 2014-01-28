require 'puppet'
require 'puppet/provider/parsedfile'
require 'puppet/external/nagios'

# The base class for all Naginator providers.
class Puppet::Provider::Naginator < Puppet::Provider::ParsedFile
  NAME_STRING = "## --PUPPET_NAME-- (called '_naginator_name' in the manifest)"
  # Retrieve the associated class from Nagios::Base.
  def self.nagios_type
    unless @nagios_type
      name = resource_type.name.to_s.sub(/^nagios_/, '')
      unless @nagios_type = Nagios::Base.type(name.to_sym)
        raise Puppet::DevError, "Could not find nagios type '#{name}'"
      end

      # And add our 'ensure' settings, since they aren't a part of
      # Naginator by default
      @nagios_type.send(:attr_accessor, :ensure, :target, :on_disk)
    end
    @nagios_type
  end

  def self.parse(text)
      Nagios::Parser.new.parse(text.gsub(NAME_STRING, "_naginator_name"))
  rescue => detail
      raise Puppet::Error, "Could not parse configuration for #{resource_type.name}: #{detail}", detail.backtrace
  end

  def self.to_file(records)
    header + records.collect { |record|
        # Remap the TYPE_name or _naginator_name params to the
        # name if the record is a template (register == 0)
        if record.to_s =~ /register\s+0/
            record.to_s.sub("_naginator_name", "name").sub(record.type.to_s + "_name", "name")
        else
            record.to_s.sub("_naginator_name", NAME_STRING)
        end
    }.join("\n")
  end

  def self.skip_record?(record)
    false
  end

  def self.valid_attr?(klass, attr_name)
    nagios_type.parameters.include?(attr_name)
  end

  def initialize(resource = nil)
    if resource.is_a?(Nagios::Base)
      # We don't use a duplicate here, because some providers (ParsedFile, at least)
      # use the hash here for later events.
      @property_hash = resource
    elsif resource
      @resource = resource if resource
      # LAK 2007-05-09: Keep the model stuff around for backward compatibility
      @model = resource
      @property_hash = self.class.nagios_type.new
    else
      @property_hash = self.class.nagios_type.new
    end
  end
end
