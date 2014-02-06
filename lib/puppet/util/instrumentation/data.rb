require 'puppet/indirector'
require 'puppet/util/instrumentation'

# This is just a transport class to be used through the instrumentation_data
# indirection. All the data resides in the real underlying listeners which this
# class delegates to.
class Puppet::Util::Instrumentation::Data
  extend Puppet::Indirector

  indirects :instrumentation_data, :terminus_class => :local

  attr_reader :listener

  def initialize(listener_name)
    @listener = Puppet::Util::Instrumentation[listener_name]
    raise "Listener #{listener_name} wasn't registered" unless @listener
  end

  def name
    @listener.name
  end

  def to_data_hash
    { :name => name }.merge(@listener.respond_to?(:data) ? @listener.data : {})
  end

  def to_pson_data_hash
    {
      'document_type' => "Puppet::Util::Instrumentation::Data",
      'data' => to_data_hash,
    }
  end

  def to_pson(*args)
    to_pson_data_hash.to_pson(*args)
  end

  def self.from_data_hash(data)
    data
  end

  def self.from_pson(data)
    Puppet.deprecation_warning("from_pson is being removed in favour of from_data_hash.")
    data
  end
end
