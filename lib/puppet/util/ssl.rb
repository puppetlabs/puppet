module Puppet::Util::SSL
  # Given a DN string, parse it into an OpenSSL certificate subject.
  # This method will flexibly handle both OpenSSl and RFC2253 formats, as
  # given by nginx and Apache, respectively.
  #
  # @param dn [String] the DN string
  # @return [OpenSSL::X509::Name] the certificate subject
  def self.subject_from_dn(dn)
    # try to parse both rfc2253 (Apache) and OpenSSL (nginx) formats
    begin
      subject = OpenSSL::X509::Name.parse_rfc2253(dn)
    rescue OpenSSL::X509::NameError
      subject = OpenSSL::X509::Name.parse_openssl(dn)
    end
    subject
  end

  # Extract the CN from the given OpenSSL certtificate subject.
  #
  # @param subject [OpenSSL::X509::Name] the subject to extract from
  # @return [String, nil] the CN, or nil if not found
  def self.cn_from_subject(subject)
    if subject.respond_to? :to_a
      (subject.to_a.assoc('CN') || [])[1]
    end
  end
end
