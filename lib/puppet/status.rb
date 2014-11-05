require 'puppet/indirector'

class Puppet::Status
  extend Puppet::Indirector
  indirects :status, :terminus_class => :local

  attr_accessor :status

  def initialize( status = nil )
    @status = status || {"is_alive" => true}
  end

  def to_data_hash
    @status
  end

  def self.from_data_hash(data)
    if data.include?('status')
      self.new(data['status'])
    else
      self.new(data)
    end
  end

  def name
    "status"
  end

  def name=(name)
    # NOOP
  end

  def version
    @status['version']
  end

  def version=(version)
    @status['version'] = version
  end
end
