require 'puppet/ssl/ocsp'
require 'puppet/ssl/ocsp/response'
require 'puppet/ssl/ocsp/request'
require 'monitor'

module Puppet::SSL::Ocsp::Verifier
  module_function

  def verify(to_check, ssl_host)
    cache(to_check, Puppet[:ocsp_ttl]) do
      request = Puppet::SSL::Ocsp::Request.new("n/a").generate(to_check, ssl_host.certificate, ssl_host.key, Puppet::SSL::Certificate.indirection.find(Puppet::SSL::CA_NAME))
      response = Puppet::SSL::Ocsp::Request.indirection.save(request)
      response = response.is_a?(String) ? Puppet::SSL::Ocsp::Response.from_yaml(response) : Puppet::SSL::Ocsp::Response.new("n/a").content = response
      response.verify(request)
    end
  end

  CACHE = {}.extend(MonitorMixin)

  def cache(to_check, ttl)
    to_check = to_check.content if to_check.is_a?(Puppet::SSL::Certificate)
    now = Time.now
    # OpenSSL::BN doesn't implement correctly hash
    # which means it can't be put in a hash :(
    key = to_check.serial.to_s
    CACHE.synchronize do
      object = CACHE[key]
      if object = CACHE[key] and now <= object[:expire_at]
        Puppet.debug "returning cached OSCP result for #{to_check.subject}"
        object[:result]
      else
        Puppet.debug "returning live OCSP result for #{to_check.subject}, expiring at #{Time.now + ttl}"
        object = { :result => yield(to_check), :expire_at => Time.now + ttl }
        CACHE[key] = object
        object[:result]
      end
    end
  end

  def expire!
    CACHE.synchronize do
      CACHE.clear
    end
  end
end
