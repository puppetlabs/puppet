require 'openssl'
require 'puppet/ssl'
require 'puppet/ssl/digest'
require 'puppet/util/ssl'

# The base class for wrapping SSL instances.
class Puppet::SSL::Base
  # For now, use the YAML separator.
  SEPARATOR = "\n---\n"

  # Only allow printing ascii characters, excluding /
  VALID_CERTNAME = /\A[ -.0-~]+\Z/

  def self.from_multiple_s(text)
    text.split(SEPARATOR).collect { |inst| from_s(inst) }
  end

  def self.to_multiple_s(instances)
    instances.collect { |inst| inst.to_s }.join(SEPARATOR)
  end

  def self.wraps(klass)
    @wrapped_class = klass
  end

  def self.wrapped_class
    raise(Puppet::DevError, "#{self} has not declared what class it wraps") unless defined?(@wrapped_class)
    @wrapped_class
  end

  def self.validate_certname(name)
    raise "Certname #{name.inspect} must not contain unprintable or non-ASCII characters" unless name =~ VALID_CERTNAME
  end

  attr_accessor :name, :content

  # Is this file for the CA?
  def ca?
    name == Puppet::SSL::Host.ca_name
  end

  def generate
    raise Puppet::DevError, "#{self.class} did not override 'generate'"
  end

  def initialize(name)
    @name = name.to_s.downcase
    self.class.validate_certname(@name)
  end

  ##
  # name_from_subject extracts the common name attribute from the subject of an
  # x.509 certificate certificate
  #
  # @api private
  #
  # @param [OpenSSL::X509::Name] subject The full subject (distinguished name) of the x.509
  #   certificate.
  #
  # @return [String] the name (CN) extracted from the subject.
  def self.name_from_subject(subject)
    Puppet::Util::SSL.cn_from_subject(subject)
  end

  # Create an instance of our Puppet::SSL::* class using a given instance of the wrapped class
  def self.from_instance(instance, name = nil)
    raise ArgumentError, "Object must be an instance of #{wrapped_class}, #{instance.class} given" unless instance.is_a? wrapped_class
    raise ArgumentError, "Name must be supplied if it cannot be determined from the instance" if name.nil? and !instance.respond_to?(:subject)

    name ||= name_from_subject(instance.subject)
    result = new(name)
    result.content = instance
    result
  end

  # Convert a string into an instance
  def self.from_s(string, name = nil)
    instance = wrapped_class.new(string)
    from_instance(instance, name)
  end

  # Read content from disk appropriately.
  def read(path)
    @content = wrapped_class.new(File.read(path))
  end

  # Convert our thing to pem.
  def to_s
    return "" unless content
    content.to_pem
  end

  def to_data_hash
    to_s
  end

  # Provide the full text of the thing we're dealing with.
  def to_text
    return "" unless content
    content.to_text
  end

  def fingerprint(md = :SHA256)
    mds = md.to_s.upcase
    digest(mds).to_hex
  end

  def digest(algorithm=nil)
    unless algorithm
      algorithm = digest_algorithm
    end

    Puppet::SSL::Digest.new(algorithm, content.to_der)
  end

  def digest_algorithm
    # The signature_algorithm on the X509 cert is a combination of the digest
    # algorithm and the encryption algorithm
    # e.g. md5WithRSAEncryption, sha256WithRSAEncryption
    # Unfortunately there isn't a consistent pattern
    # See RFCs 3279, 5758
    digest_re = Regexp.union(
      /ripemd160/i,
      /md[245]/i,
      /sha\d*/i
    )
    ln = content.signature_algorithm
    if match = digest_re.match(ln)
      match[0].downcase
    else
      raise Puppet::Error, "Unknown signature algorithm '#{ln}'"
    end
  end

  private

  def wrapped_class
    self.class.wrapped_class
  end
end
