#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

describe Puppet::Network do
    it "should raise an XMLRPCClientError if a generated class raises a Timeout::Error" do
        http = mock 'http'
        Puppet::Network::HttpPool.stubs(:http_instance).returns http
        file = Puppet::Network::Client.file.new({:Server => "foo.com"})
        http.stubs(:post2).raises Timeout::Error
        lambda { file.retrieve }.should raise_error(Puppet::Network::XMLRPCClientError)
    end
end
