require 'spec_helper'
require 'net/http'
require 'puppet/forge/repository'
require 'puppet/forge/cache'

describe Puppet::Forge::Repository do
  describe 'instances' do

    let(:repository) { Puppet::Forge::Repository.new('http://fake.com') }

    describe '#retrieve' do
      before do
        @uri = URI.parse('http://some.url.com')
      end

      it "should access the cache" do
        repository.cache.expects(:retrieve).with(@uri)
        repository.retrieve(@uri)
      end
    end

    describe 'http_proxy support' do
      before :each do
        ENV["http_proxy"] = nil
      end

      after :each do
        ENV["http_proxy"] = nil
      end

      it "should support environment variable for port and host" do
        ENV["http_proxy"] = "http://test.com:8011"
        repository.http_proxy_host.should == "test.com"
        repository.http_proxy_port.should == 8011
      end

      it "should support puppet configuration for port and host" do
        ENV["http_proxy"] = nil
        Puppet.settings.stubs(:[]).with(:http_proxy_host).returns('test.com')
        Puppet.settings.stubs(:[]).with(:http_proxy_port).returns(7456)

        repository.http_proxy_port.should == 7456
        repository.http_proxy_host.should == "test.com"
      end

      it "should use environment variable before puppet settings" do
        ENV["http_proxy"] = "http://test1.com:8011"
        Puppet.settings.stubs(:[]).with(:http_proxy_host).returns('test2.com')
        Puppet.settings.stubs(:[]).with(:http_proxy_port).returns(7456)

        repository.http_proxy_host.should == "test1.com"
        repository.http_proxy_port.should == 8011
      end
    end
  end
end
