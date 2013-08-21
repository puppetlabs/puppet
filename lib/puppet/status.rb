require 'puppet/indirector'

class Puppet::Status
  extend Puppet::Indirector
  indirects :status, :terminus_class => :local

  attr :status, true

  def initialize( status = nil )
    @status = status || {"is_alive" => true}
  end

  def to_data_hash
    @status
  end

  def to_pson(*args)
    @status.to_pson
  end

  def self.from_pson(pson)
    if pson.include?('status')
      self.new(pson['status'])
    else
      self.new(pson)
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
