require 'spec_helper'

require 'puppet/network/http'
require 'puppet/network/http/api/indirected_routes'
require 'puppet/indirector_testing'

module PuppetSpec::Network
  def not_found_code
    Puppet::Network::HTTP::Error::HTTPNotFoundError::CODE
  end

  def not_acceptable_code
    Puppet::Network::HTTP::Error::HTTPNotAcceptableError::CODE
  end

  def bad_request_code
    Puppet::Network::HTTP::Error::HTTPBadRequestError::CODE
  end

  def not_authorized_code
    Puppet::Network::HTTP::Error::HTTPNotAuthorizedError::CODE
  end

  def params
    { :environment => "production" }
  end

  def master_url_prefix
    "#{Puppet::Network::HTTP::MASTER_URL_PREFIX}/v3"
  end

  def ca_url_prefix
    "#{Puppet::Network::HTTP::CA_URL_PREFIX}/v1"
  end

  def a_request_that_heads(data, request = {}, params = params())
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => "text/pson"
      },
      :method => "HEAD",
      :path => "#{master_url_prefix}/#{data.class.indirection.name}/#{data.value}",
      :params => params,
    })
  end

  def a_request_that_submits(data, request = {}, params = params())
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => request[:content_type_header] || "text/pson"
      },
      :method => "PUT",
      :path => "#{master_url_prefix}/#{data.class.indirection.name}/#{data.value}",
      :params => params,
      :body => request[:body].nil? ? data.render("pson") : request[:body]
    })
  end

  def a_request_that_destroys(data, request = {}, params = params())
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => "text/pson"
      },
      :method => "DELETE",
      :path => "#{master_url_prefix}/#{data.class.indirection.name}/#{data.value}",
      :params => params,
      :body => ''
    })
  end

  def a_request_that_finds(data, request = {}, params = params())
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => "text/pson"
      },
      :method => "GET",
      :path => "#{master_url_prefix}/#{data.class.indirection.name}/#{data.value}",
      :params => params,
      :body => ''
    })
  end

  def a_request_that_searches(data, request = {}, params = params())
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => "text/pson"
      },
      :method => "GET",
      :path => "#{master_url_prefix}/#{data.class.indirection.name}s/#{data.name}",
      :params => params,
      :body => ''
    })
  end

end

