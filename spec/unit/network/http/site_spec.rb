#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/http'

describe Puppet::Network::HTTP::Site do
  let(:scheme)      { 'https' }
  let(:host)        { 'rubygems.org' }
  let(:port)        { 443 }

  def create_site(scheme, host, port)
    Puppet::Network::HTTP::Site.new(scheme, host, port)
  end

  it 'accepts scheme, host, and port' do
    site = create_site(scheme, host, port)

    expect(site.scheme).to eq(scheme)
    expect(site.host).to eq(host)
    expect(site.port).to eq(port)
  end

  it 'generates an external URI string' do
    site = create_site(scheme, host, port)

    expect(site.addr).to eq("https://rubygems.org:443")
  end

  it 'considers sites to be different when the scheme is different' do
    https_site = create_site('https', host, port)
    http_site = create_site('http', host, port)

    expect(https_site).to_not eq(http_site)
  end

  it 'considers sites to be different when the host is different' do
    rubygems_site = create_site(scheme, 'rubygems.org', port)
    github_site = create_site(scheme, 'github.com', port)

    expect(rubygems_site).to_not eq(github_site)
  end

  it 'considers sites to be different when the port is different' do
    site_443 = create_site(scheme, host, 443)
    site_80 = create_site(scheme, host, 80)

    expect(site_443).to_not eq(site_80)
  end

  it 'compares values when determining equality' do
    site = create_site(scheme, host, port)

    sites = {}
    sites[site] = site

    another_site = create_site(scheme, host, port)

    expect(sites.include?(another_site)).to be_truthy
  end

  it 'computes the same hash code for equivalent objects' do
    site = create_site(scheme, host, port)
    same_site = create_site(scheme, host, port)

    expect(site.hash).to eq(same_site.hash)
  end

  it 'uses ssl with https' do
    site = create_site('https', host, port)

    expect(site).to be_use_ssl
  end

  it 'does not use ssl with http' do
    site = create_site('http', host, port)

    expect(site).to_not be_use_ssl
  end

  it 'moves to a new URI location' do
    site = create_site('http', 'host1', 80)

    uri = URI.parse('https://host2:443/some/where/else')
    new_site = site.move_to(uri)

    expect(new_site.scheme).to eq('https')
    expect(new_site.host).to eq('host2')
    expect(new_site.port).to eq(443)
  end
end
