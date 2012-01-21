require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::Module::Tool do
  describe 'http_proxy support' do
    before :each do
      ENV["http_proxy"] = nil
    end

    after :each do
      ENV["http_proxy"] = nil
    end

    it "should support environment variable for port and host" do
      ENV["http_proxy"] = "http://test.com:8011"
      described_class.http_proxy_host.should == "test.com"
      described_class.http_proxy_port.should == 8011
    end

    it "should support puppet configuration for port and host" do
      ENV["http_proxy"] = nil
      Puppet.settings.stubs(:[]).with(:http_proxy_host).returns('test.com')
      Puppet.settings.stubs(:[]).with(:http_proxy_port).returns(7456)

      described_class.http_proxy_port.should == 7456
      described_class.http_proxy_host.should == "test.com"
    end

    it "should use environment variable before puppet settings" do
      ENV["http_proxy"] = "http://test1.com:8011"
      Puppet.settings.stubs(:[]).with(:http_proxy_host).returns('test2.com')
      Puppet.settings.stubs(:[]).with(:http_proxy_port).returns(7456)

      described_class.http_proxy_host.should == "test1.com"
      described_class.http_proxy_port.should == 8011
    end
  end
end
