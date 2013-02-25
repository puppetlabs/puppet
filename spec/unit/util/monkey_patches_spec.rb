#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/monkey_patches'

describe OpenSSL::SSL::SSLContext do
  it 'disables SSLv2 via the SSLContext#options bitmask' do
    (subject.options & OpenSSL::SSL::OP_NO_SSLv2).should == OpenSSL::SSL::OP_NO_SSLv2
  end
  it 'has no ciphers with version SSLv2 enabled' do
    ciphers = subject.ciphers.select do |name, version, bits, alg_bits|
      /SSLv2/.match(version)
    end
    ciphers.should be_empty
  end
end
