test_name "puppet should be able to authenticate a well-known SSL server"

script <<EOM
#! /usr/bin/env ruby
require 'rubygems'
require 'openssl'
require 'net/https'
require 'puppet'

cert_store = OpenSSL::X509::Store.new
cert_store.set_default_paths

conn = Net::HTTP.new('github.com', 443)
conn.use_ssl     = true
conn.verify_mode = OpenSSL::SSL::VERIFY_PEER
conn.cert_store  = cert_store

conn.start {|c| puts "connected" }
EOM

step "connect to github.com"
agents.each do |agent|
  on(agents, "ruby -e #{script}") do
    assert_match(/\Aconnected\Z/, stdout)
  end
end
