require 'puppet/ssl/ocsp/response'
require 'puppet/ssl/ocsp/request'

module Puppet::SSL::Ocsp::Responder
  module_function

  def respond(request)
    request = request.content if request.is_a?(Puppet::SSL::Ocsp::Request)

    unless ca = Puppet::SSL::CertificateAuthority.instance
      return ocsp_internal_error_response
    end
    ca_cert = ca.host.certificate.content
    cacid = OpenSSL::OCSP::CertificateId.new(ca_cert, ca_cert)

    # we can't verify because we have no way to find the
    # cert that signed the request, except by looking
    # in the signed cert
    # unless request.verify([certificate], ssl_store)
    #   return ocsp_invalid_request_error
    # end

    return ocsp_invalid_request_response unless request.certid and request.certid.size > 0

    # we're dealing only with the first cid
    candidate = request.certid.first
    serial = candidate.serial
    return ocsp_response(request, ca_cert, ca.host.key.content) unless candidate.cmp_issuer(cacid)

    # Let's now check if our cert has been revoked
    return ocsp_internal_error_response unless crl = Puppet::SSL::CertificateRevocationList.indirection.find(Puppet::SSL::CA_NAME)

    ocsp_response(request, candidate, ca_cert, ca.host.key.content, crl.content.revoked.find { |r| r.serial == serial })
  end

  def ocsp_internal_error_response
    wrap_response(OpenSSL::OCSP::Response.create(OpenSSL::OCSP::RESPONSE_STATUS_INTERNALERROR, nil))
  end

  def ocsp_invalid_request_response
    wrap_response(OpenSSL::OCSP::Response.create(OpenSSL::OCSP::RESPONSE_STATUS_MALFORMEDREQUEST, nil))
  end

  def ocsp_response(request, certid, ca, cakey, revoked)
    time = Time.now.to_i
    basic_response = OpenSSL::OCSP::BasicResponse.new
    basic_response.copy_nonce(request)
    if revoked
      # certificate is revoked, let's find why
      reason = revoked.extensions.select { |ext| ext.oid == 'CRLReason' }.map { |ext| ext.value }
      # there seems to be an openssl bug, where add_status doesn't use absolute time but relative time
      # to now. That means there are great chances the revoked time will be be wrong in the response
      basic_response.add_status(certid, OpenSSL::OCSP::V_CERTSTATUS_REVOKED, Puppet::SSL::Ocsp.reason_to_code(reason), revoked.time, 0, Puppet.settings[:ocsp_ttl], nil)
    else
      # certificate is not in the CRL
      basic_response.add_status(certid, OpenSSL::OCSP::V_CERTSTATUS_GOOD, 0, nil, 0, Puppet.settings[:ocsp_ttl], nil)
    end

    basic_response.sign(ca, cakey,[])

    wrap_response(OpenSSL::OCSP::Response.create(OpenSSL::OCSP::RESPONSE_STATUS_SUCCESSFUL, basic_response))
  end

  def ocsp_unknown_ca_response(request, ca, cakey)
    basic_response = OpenSSL::OCSP::BasicResponse.new
    basic_response.copy_nonce(request)
    basic_response.sign(ca, cakey,[])

    basic_response.add_status(certid, OpenSSL::OCSP::V_CERTSTATUS_UNKNOWN, 0, nil, 0, Puppet.settings[:ocsp_ttl], nil)

    wrap_response(OpenSSL::OCSP::Response.create(OpenSSL::OCSP::RESPONSE_STATUS_SUCCESSFUL, basic_response))
  end

  def wrap_response(ocsp_response)
    response = Puppet::SSL::Ocsp::Response.new("none")
    response.content = ocsp_response
    response
  end
end