require 'puppet'
require 'puppet/indirector/certificate_status'
require 'puppet/ssl/certificate'
require 'puppet/ssl/certificate_authority'
require 'puppet/ssl/certificate_request'
require 'puppet/ssl/host'
require 'puppet/ssl/key'

class Puppet::Indirector::CertificateStatus::File < Puppet::Indirector::Code

  desc "Manipulate certificate status on the local filesystem. Only functional
    on the CA."

  def ca
    raise ArgumentError, "This process is not configured as a certificate authority" unless Puppet::SSL::CertificateAuthority.ca?
    Puppet::SSL::CertificateAuthority.new
  end

  def destroy(request)
    deleted = []
    [
      Puppet::SSL::Certificate,
      Puppet::SSL::CertificateRequest,
      Puppet::SSL::Key,
    ].collect do |part|
      if part.indirection.destroy(request.key)
        deleted << "#{part}"
      end
    end

    return "Nothing was deleted" if deleted.empty?
    "Deleted for #{request.key}: #{deleted.join(", ")}"
  end

  def save(request)
    if request.instance.desired_state == "signed"
      certificate_request = Puppet::SSL::CertificateRequest.indirection.find(request.key)
      raise Puppet::Error, "Cannot sign for host #{request.key} without a certificate request" unless certificate_request
      ca.sign(request.key)
    elsif request.instance.desired_state == "revoked"
      certificate = Puppet::SSL::Certificate.indirection.find(request.key)
      raise Puppet::Error, "Cannot revoke host #{request.key} because has it doesn't have a signed certificate" unless certificate
      ca.revoke(request.key)
    else
      raise Puppet::Error, "State #{request.instance.desired_state} invalid; Must specify desired state of 'signed' or 'revoked' for host #{request.key}"
    end

  end

  def search(request)
    # Support historic interface wherein users provide classes to filter
    # the search.  When used via the REST API, the arguments must be
    # a Symbol or an Array containing Symbol objects.
    klasses = case request.options[:for]
    when Class
      [request.options[:for]]
    when nil
      [
        Puppet::SSL::Certificate,
        Puppet::SSL::CertificateRequest,
        Puppet::SSL::Key,
      ]
    else
      [request.options[:for]].flatten.map do |klassname|
        indirection.class.model(klassname.to_sym)
      end
    end

    klasses.collect do |klass|
      klass.indirection.search(request.key, request.options)
    end.flatten.collect do |result|
      result.name
    end.uniq.collect &Puppet::SSL::Host.method(:new)
  end

  def find(request)
    ssl_host = Puppet::SSL::Host.new(request.key)
    public_key = Puppet::SSL::Certificate.indirection.find(request.key)

    if ssl_host.certificate_request || public_key
      ssl_host
    else
      nil
    end
  end

  def validate_key(request)
    # We only use desired_state from the instance and use request.key
    # otherwise, so the name does not need to match
  end
end
