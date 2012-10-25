class Puppet::SSL::Digest
  attr_reader :digest

  def initialize(algorithm, content)
    algorithm ||= 'SHA256'
    @digest = OpenSSL::Digest.new(algorithm, content)
  end

  def to_s
    "(#{name}) #{to_hex}"
  end

  def to_hex
    @digest.hexdigest.scan(/../).join(':').upcase
  end

  def name
    @digest.name.upcase
  end
end
