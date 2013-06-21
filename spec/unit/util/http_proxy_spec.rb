require 'uri'
require 'spec_helper'
require 'puppet/util/http_proxy'

describe Puppet::Util::HttpProxy do

  host, port = 'some.host', 1234

  describe ".http_proxy_env" do
    it "should return nil if no environment variables" do
      subject.http_proxy_env.should == nil
    end

    it "should return a URI::HTTP object if http_proxy env variable is set" do
      Puppet::Util.withenv('HTTP_PROXY' => host) do
        subject.http_proxy_env.should == URI.parse(host)
      end
    end

    it "should return a URI::HTTP object if HTTP_PROXY env variable is set" do
      Puppet::Util.withenv('HTTP_PROXY' => host) do
        subject.http_proxy_env.should == URI.parse(host)
      end
    end

    it "should return a URI::HTTP object with .host and .port if URI is given" do
      Puppet::Util.withenv('HTTP_PROXY' => "http://#{host}:#{port}") do
        subject.http_proxy_env.should == URI.parse("http://#{host}:#{port}")
      end
    end

    it "should return nil if proxy variable is malformed" do
      Puppet::Util.withenv('HTTP_PROXY' => 'this is not a valid URI') do
        subject.http_proxy_env.should == nil
      end
    end
  end

  describe ".http_proxy_host" do
    it "should return nil if no proxy host in config or env" do
      subject.http_proxy_host.should == nil
    end

    it "should return a proxy host if set in config" do
      Puppet.settings[:http_proxy_host] = host
      subject.http_proxy_host.should == host
    end

    it "should return nil if set to `none` in config" do
      Puppet.settings[:http_proxy_host] = 'none'
      subject.http_proxy_host.should == nil
    end

    it "uses environment variable before puppet settings" do
      Puppet::Util.withenv('HTTP_PROXY' => "http://#{host}:#{port}") do
        Puppet.settings[:http_proxy_host] = 'not.correct'
        subject.http_proxy_host.should == host
      end
    end
  end

  describe ".http_proxy_port" do
    it "should return a proxy port if set in environment" do
      Puppet::Util.withenv('HTTP_PROXY' => "http://#{host}:#{port}") do
        subject.http_proxy_port.should == port
      end
    end

    it "should return a proxy port if set in config" do
      Puppet.settings[:http_proxy_port] = port
      subject.http_proxy_port.should == port
    end

    it "uses environment variable before puppet settings" do
      Puppet::Util.withenv('HTTP_PROXY' => "http://#{host}:#{port}") do
        Puppet.settings[:http_proxy_port] = 7456
        subject.http_proxy_port.should == port
      end
    end

  end

end
