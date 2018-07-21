require 'base64'
require 'openssl'

module Puppet::Pops
module Types

# A Puppet Language Type that represents encrypted content.
#
# Instances of this data type can be created from any other data type.
#
# An `Encrypted` can be decrypted using the `decrypt()` function.
# (The decrypted result is always wrapped in a `Sensitive` to prevent accidental leakage of
# of the secret).
#
# Instances of this data type serialize as Base64 encoded strings when the serialization
# format is textual, and as binary content when a serialization format supports this.
#
# @api public
class PEncryptedType < PAnyType

  # Represents an Encrypted value
  # @api public
  #
  class Encrypted
    attr_reader :format
    attr_reader :encrypted_key
    attr_reader :crypt
    attr_reader :encrypted_fingerprint

    # Creates a new Encrypted
    # This API is private - please use `Encrypted.encrypt` method to create an instance.
    # This method is only accessible for serialization purposes.
    #
    # @api private
    #
    def initialize(format, encrypted_key, crypt, encrypted_fingerprint)
      @format = format
      @encrypted_key, @crypt, @encrypted_fingerprint = make_binary(encrypted_key, crypt, encrypted_fingerprint)
    end

    # @api private
    def make_binary(*vars)
      vars.map {|v| Puppet::Pops::Types::PBinaryType::Binary.from_binary(v) }
    end
    private :make_binary

    # Presents the binary content as a base64 encoded string (without line breaks).
    # While this method is public, the content of the String is not API and may change.
    #
    # @api public
    #
    def to_s
      [ @format,
        @encrypted_key,
        @crypt,
        @encrypted_fingerprint,
        ].to_s
    end

    # @api public
    #
    def hash
      # this is the encrypted random key which should give a reasonable spread
      @encrypted_key.hash
    end

    # Returns identity equality since two Encrypted for the same value will always be different.
    # @param o [Object] Any object to check for equality
    # @return [Boolean]
    # @api public
    #
    def eql?(o)
      # Can only equal the same instance since each encryption is based on random values
      # No need to check for anything besides object identity
      __id__ == o.__id__
    end

    # Returns identity equality since two Encrypted for the same value will always be different.
    # @param o [Object] Any object to check for equality
    # @return [Boolean]
    # @api public
    #
    def ==(o)
      self.eql?(o)
    end

    # Encrypts data using a certificate, a cipher name and Any data - returns an Encrypted.
    # This is the API for creating an `Encrypted` value.
    #
    # Note that the `cipher` param accepts a single name, or an array of cipher names.
    # The preferred cipher is returned from the array using the order in --accepted_ciphers if it is not empty.
    # Otherwise, the single cipher, or the first given cipher in the given array is used.
    #
    # @param certificate [Puppet::SLL::Certificate] The certificate to use (i.e. for the receiver's public key)
    # @param cipher [String, Array<String>] The name of the cipher to use - for example 'AES-256-CBC', or an array of names
    # @param data [Object] Any puppet rich data data type
    # @return [Puppet::Pops::Types::PEncryptedType::Encrypted] An Encrypted puppet data type value
    # @api public
    #
    def self.encrypt(certificate, ciphers, data)

      cipher = best_matching_cipher(ciphers)
      if cipher.nil?
        if ciphers.is_a?(Array)
          raise ArgumentError, _("None of the cipher names \"%{ciphers}\" are supported. Supported ciphers: %{available_ciphers}") % {
            available_ciphers: acceptable_and_available_ciphers,
            ciphers: ciphers
          }
        else
          raise ArgumentError, _("Unsupported cipher algorithm \"%{cipher_name}\". Supported ciphers: %{available_ciphers}") % {
            available_ciphers: acceptable_and_available_ciphers,
            cipher_name: cipher
          }
        end
      end

      key = certificate.content.public_key
      fingerprint = certificate.fingerprint
      data = serialize(data)
      format = 'json,' + cipher

      aes_encrypt = OpenSSL::Cipher.new(cipher).encrypt

      # Use a random key
      aes_encrypt.key = aes_key = aes_encrypt.random_key

      # Use a random initialization vector (safer) - these 16 bytes are prepended to the clear text
      # and dropped after decryption.
      #
      iv = aes_encrypt.random_iv

      # Encrypt the data with this key
      crypt = iv + aes_encrypt.update(data) << aes_encrypt.final
      # Encrypt the random key with the public key
      encrypted_key = rsa_key(key).public_encrypt(aes_key)

      # Encrypt the fingerprint with public key
      aes_encrypt.reset

      # use different iv
      iv = aes_encrypt.random_iv
      encrypted_fingerprint = iv + aes_encrypt.update(fingerprint) << aes_encrypt.final

      Encrypted.new(format, encrypted_key, crypt, encrypted_fingerprint)
    end

    # @api private
    def self.rsa_key(key)
      OpenSSL::PKey::RSA.new(key)
    end
    private_class_method :rsa_key

    # @api private
    def self.serialize(data)
      io = StringIO.new
      writer = Puppet::Pops::Serialization::JSON::Writer.new(io)
      serializer = Puppet::Pops::Serialization::Serializer.new(writer)
      serializer.write(data)
      serializer.finish
      io.string
    end
    private_class_method :serialize

    # Returns the union of acceptable and available ciphers
    def self.acceptable_and_available_ciphers
      # return from cache unless accepted_ciphers changed since last cached
      return @supported_ciphers if !@supported_ciphers.nil? && @supported_ciphers_id == Puppet[:accepted_ciphers].__id__
      available = OpenSSL::Cipher.ciphers
      acceptable = Puppet[:accepted_ciphers]
      @supported_ciphers_id = Puppet[:accepted_ciphers].__id__
      @supported_ciphers = acceptable.empty? ? available : acceptable & available
      @supported_ciphers
    end

    def self.best_matching_cipher(ciphers)
      if ciphers.nil?
        # use the default - first accepted, or AES-256-CBC if accepted is not defined
        accepted = Puppet[:accepted_ciphers]
        ciphers = [accepted.empty? ? 'AES-256-CBC' : accepted[0]]
      else
        ciphers = [ciphers] unless ciphers.is_a?(Array)
      end

      accepted_and_available = acceptable_and_available_ciphers
      # prune ciphers such that pruned ciphers contains the preferred cipher first
      pruned_ciphers = accepted_and_available & ciphers

      # none acceptable
      return nil if pruned_ciphers.empty?

      if ciphers.length == 1 || Puppet[:accepted_ciphers].empty?
        # Produce the first value in ciphers that is accepted - or nil if non were
        # Since all ciphers are accepted there is no defined order, so  use first in list of ciphers
        (ciphers & pruned_ciphers)[0]
      else
        # Since there is a preferred order, the pruned[0] contains the preferred cipher name
        # (acceptable and available orders) are in order of preference when accepted_ciphers is defined
        pruned_ciphers[0]
      end
    end

    # Decrypts this `Encrypted` and returns a `Sensitive` instance with the decrypted value
    #
    # @param scope [Puppet::Parser::Scope] Scope is used to find data types for serialization
    # @param host [Puppet::SSL::Host] The host to decrypt for - defaults to localhost
    # @return [Puppet::Pops::Types::PSensitiveType::Sensitive] with the decrypted value
    # @api public
    #
    def decrypt(scope, host = Puppet::SSL::Host.localhost)
      key = host.key
      raise Puppet::DecryptionError.new(_("No private key available for %{host}") % {host: host.name }) unless key
      key = key.content

      # decrypt the random key encrypted with receiver's public key
      begin
        aes_key = key.private_decrypt(@encrypted_key.binary_buffer)
      rescue OpenSSL::PKey::RSAError => e
        raise Puppet::DecryptionError.new(_("Decryption failed (probably using wrong host), caused by: %{message}") % {message: e.message})
      end

      _serializer, cipher = @format.split(/,/)
      # Decrypt using the given cipher, and the random key
      # Use the 16 first byte as IV (they are in clear text)
      # Decrypt the rest with the random key and the IV
      #
      aes_decrypt = OpenSSL::Cipher.new(cipher).decrypt
      aes_decrypt.key = aes_key
      aes_decrypt.iv, crypt_part = iv_split(@crypt)
      data = aes_decrypt.update(crypt_part) << aes_decrypt.final

      # Decrypt (same way) the fingerprint. While not really a secret there is no need
      # to make it easy to understand who the recipient of an encryption is.
      #
      aes_decrypt.reset
      aes_decrypt.iv, fingerprint_part = iv_split(@encrypted_fingerprint)
      fingerprint = aes_decrypt.update(fingerprint_part) << aes_decrypt.final

      # Check if this was for "this recipient"
      #
      unless fingerprint == host.certificate.fingerprint
        raise Puppet::DecryptionError.new(_("Decryption failed, the Encrypted is not encrypted for given host"))
      end

      # The data is a Pcore serialization so it must be deserialized
      clear = deserialize(data, scope)
      sensitive = Puppet::Pops::Types::PSensitiveType::Sensitive

      # Ensure result is a Sensitive
      clear.is_a?(sensitive) ? clear : sensitive.new(clear)
    end

    # @api private
    def iv_split(bin)
      buffer = bin.binary_buffer
      [buffer[0..15], buffer[16..-1]]
    end
    private :iv_split

    def deserialize(data, scope)
      io = StringIO.new(data)
      reader = Puppet::Pops::Serialization::JSON::Reader.new(io)
      loader = scope.compiler.loaders.find_loader(nil)
      deserializer = Puppet::Pops::Serialization::Deserializer.new(reader, loader)
      deserializer.read()
    end
    private :deserialize
  end

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType')
  end

  # Only instances of Encrypted are instances of the PEncryptedType
  #
  def instance?(o, guard = nil)
    o.is_a?(Encrypted)
  end

  def eql?(o)
    self.class == o.class
  end

  def implementation_class
    Encrypted
  end

  def parameter_info(klazz)
    names = %w{format encrypted_key crypt encrypted_fingerprint}
    binary = Puppet::Pops::Types::PBinaryType::Binary
    types = [String, binary, binary, binary]
    [names, types, 4]
  end

  def allocate
    implementation_class.allocate
  end

  # See function `new` for documentation.
  #
  # @api private
  #
  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_Encrypted, type.loader) do
      local_types do
        type 'OptionsHash = Struct[{Optional["cipher"] => Variant[String,Array[String,1]], Optional["node_name"] => String}]'
      end

      # Creates an encrypted
      dispatch :from_any do
        param 'Any', :data
        optional_param 'OptionsHash', :options
      end

      def from_any(data, options = {})
        node_name = options['node_name']
        cipher = options['cipher']

        if node_name.nil?
          trusted = Puppet.lookup(:trusted_information) { nil }
          if trusted.nil?
            # Get the localhost certificate (in apply mode)
            certificate = Puppet::SSL::Host.localhost.certificate
          else
            # Get the certificate for the request
            certificate = trusted.certificate
          end
        else
          # Get certificate for the given node name
          certificate = Puppet::SSL::Host.new(node_name).certificate
          if certificate.nil?
            raise ArgumentError, _("Encrypted.new() Cannot find a certificate for given node '%{node_name}'.") % { node_name: node_name }
          end
        end

        if certificate.nil?
          # TRANSLATORS - "trusted_information" is an internal key, do not translate
          raise ArgumentError, _("Encrypted.new() Cannot find required trusted_information with certificate for target node.")
        end
        Encrypted.encrypt(certificate, cipher, data)
      end
    end
  end

  DEFAULT = PEncryptedType.new

  protected

  def _assignable?(o, guard)
    o.class == self.class
  end

end
end
end
