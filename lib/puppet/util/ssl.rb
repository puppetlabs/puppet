##
# SSL is a private module with class methods that help work with x.509
# subjects.
#
# @api private
module Puppet::Util::SSL

  @@dn_parsers = nil
  @@no_name = nil

  # Given a DN string, parse it into an OpenSSL certificate subject.  This
  # method will flexibly handle both OpenSSL and RFC2253 formats, as given by
  # nginx and Apache, respectively.
  #
  # @param [String] dn the x.509 Distinguished Name (DN) string.
  #
  # @return [OpenSSL::X509::Name] the certificate subject
  def self.subject_from_dn(dn)
    if is_possibly_valid_dn?(dn)
      parsers = @@dn_parsers ||= [
            OpenSSL::X509::Name.method(:parse_rfc2253),
            OpenSSL::X509::Name.method(:parse_openssl)
        ]
      parsers.each do |parser|
        begin
          return parser.call(dn)
        rescue OpenSSL::X509::NameError
        end
      end
    end

    @@no_name ||= OpenSSL::X509::Name.new
  end

  ##
  # cn_from_subject extracts the CN from the given OpenSSL certificate
  # subject.
  #
  # @api private
  #
  # @param [OpenSSL::X509::Name] subject the subject to extract the CN field from
  #
  # @return [String, nil] the CN, or nil if not found
  def self.cn_from_subject(subject)
    if subject.respond_to? :to_a
      (subject.to_a.assoc('CN') || [])[1]
    end
  end

  def self.is_possibly_valid_dn?(dn)
    dn =~ /=/
  end
end
