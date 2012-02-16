require 'puppet/ssl/base'

# This represents an OCSP Response
class Puppet::SSL::Ocsp::Response < Puppet::SSL::Base
  wraps OpenSSL::OCSP::Response

  class VerificationError < RuntimeError ; end

  # OCSP response can only be represented as DER encoding, base64 encoded string into
  # YAML. 
  # Why this complicated setup?
  # Because puppet indirector save is the only way we can model a request/response
  # model. Unfortunately in this model, the puppet insist for the response to be
  # serialized as Yaml.
  def self.from_yaml(string)
    instance = wrapped_class.new(Base64.decode64(YAML.load(string)))
    name = "fake"
    result = new(name)
    result.content = instance
    result
  end

  def to_yaml
    return YAML.dump("") unless content
    YAML.dump(Base64.encode64(content.to_der))
  end

  # This might be not necessary, but since the only way of getting one of this
  # instance is saving an Ocsp request and the save operation only returns YAML serialized content
  def self.supported_formats
    [:yaml]
  end

  def verify(request)
    raise VerificationError.new, "OCSP Verification Error: #{content.status_string}" unless content.status == 0
    raise VerificationError.new, "OCSP Verification Error: no valid response from OCSP responder" unless basic = content.basic
    raise VerificationError.new, "OCSP Verification Error: nonce don't match, potential replay attack" if request.content.check_nonce(basic) == 0
    raise VerificationError.new, "OCSP Verification Error: no results" if basic.status.empty?

    basic.status.collect do |r|
      {
        :serial => r[0].serial,
        :valid => r[1] == OpenSSL::OCSP::V_CERTSTATUS_GOOD,
        :revocation_reason => r[2],
        :revoked_at => r[3],
        :ttl => r[5]
      }
    end
  end
end
