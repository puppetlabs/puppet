
class Puppet::SSL::Ocsp

  # X509 extensions are ASN1 Enumerated values, but unfortunately the ruby API
  # only returns the printable strings and not the enum :(
  # so we're reconstructing the value from the strings coming from openssl code
  REASONSTR_TO_CODE = {
    "Unspecified" => OpenSSL::OCSP::REVOKED_STATUS_UNSPECIFIED,
    "Key Compromise" => OpenSSL::OCSP::REVOKED_STATUS_KEYCOMPROMISE,
    "CA Compromise" => OpenSSL::OCSP::REVOKED_STATUS_CACOMPROMISE,
    "Affiliation Changed" => OpenSSL::OCSP::REVOKED_STATUS_AFFILIATIONCHANGED,
    "Superseded" => OpenSSL::OCSP::REVOKED_STATUS_SUPERSEDED,
    "Cessation Of Operation" => OpenSSL::OCSP::REVOKED_STATUS_CESSATIONOFOPERATION,
    "Certificate Hold" => OpenSSL::OCSP::REVOKED_STATUS_CERTIFICATEHOLD,
    "Remove From CRL" => OpenSSL::OCSP::REVOKED_STATUS_REMOVEFROMCRL,
    "Privilege Withdrawn" => OpenSSL::OCSP::REVOKED_STATUS_UNSPECIFIED,
    "AA Compromise" => OpenSSL::OCSP::REVOKED_STATUS_UNSPECIFIED
  }

  def self.reason_to_code(reason)
    return OpenSSL::OCSP::REVOKED_STATUS_NOSTATUS unless reason or reason.size == 0
    REASONSTR_TO_CODE[reason.first]
  end

  def self.code_to_reason(code)
    REASONSTR_TO_CODE.invert[code]
  end
end