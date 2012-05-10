require 'spec_helper'
require 'net/http'
require 'puppet/forge/repository'
require 'puppet/forge/cache'

describe Puppet::Forge::Repository do
  let(:repository) { Puppet::Forge::Repository.new('http://fake.com') }

  it "retrieve accesses the cache" do
    uri = URI.parse('http://some.url.com')
    repository.cache.expects(:retrieve).with(uri)

    repository.retrieve(uri)
  end

  describe 'http_proxy support' do
    after :each do
      ENV["http_proxy"] = nil
    end

    it "supports environment variable for port and host" do
      ENV["http_proxy"] = "http://test.com:8011"

      repository.http_proxy_host.should == "test.com"
      repository.http_proxy_port.should == 8011
    end

    it "supports puppet configuration for port and host" do
      ENV["http_proxy"] = nil
      proxy_settings_of('test.com', 7456)

      repository.http_proxy_port.should == 7456
      repository.http_proxy_host.should == "test.com"
    end

    it "uses environment variable before puppet settings" do
      ENV["http_proxy"] = "http://test1.com:8011"
      proxy_settings_of('test2.com', 7456)

      repository.http_proxy_host.should == "test1.com"
      repository.http_proxy_port.should == 8011
    end

    def proxy_settings_of(host, port)
      Puppet.settings.stubs(:[]).with(:http_proxy_host).returns(host)
      Puppet.settings.stubs(:[]).with(:http_proxy_port).returns(port)
    end
  end
end
