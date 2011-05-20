#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet'
require 'puppet/sslcertificates'
require 'puppet/sslcertificates/ca'

describe Puppet::SSLCertificates::CA do
  before :all do
    @hosts = %w{host.domain.com Other.Testing.Com}
  end

  before :each do
    Puppet::Util::SUIDManager.stubs(:asuser).yields
    file = Tempfile.new("ca_testing")
    @dir = file.path
    file.delete

    Puppet.settings[:confdir] = @dir
    Puppet.settings[:vardir]  = @dir

    @ca = Puppet::SSLCertificates::CA.new
  end

  after :each do
    system("rm -rf #{@dir}")
  end

  describe 'when cleaning' do
    it 'should remove associated files' do
      dirs = [:csrdir, :signeddir, :publickeydir, :privatekeydir, :certdir]

      @hosts.each do |host|
        files = []
        dirs.each do |dir|
          dir = Puppet[dir]

          # Case insensitivity is handled through downcasing
          file = File.join(dir, host.downcase + '.pem')

          File.open(file, "w") do |f|
            f.puts "testing"
          end

          files << file
        end

        lambda { @ca.clean(host) }.should_not raise_error

        files.reject {|f| ! File.exists?(f)}.should be_empty
      end
    end
  end

  describe 'when mapping hosts to files' do
    it 'should correctly return the certfile' do
      @hosts.each do |host|
        value = nil
        lambda { value = @ca.host2certfile host }.should_not raise_error

        File.join(Puppet[:signeddir], host.downcase + '.pem').should == value
      end
    end

    it 'should correctly return the csrfile' do
      @hosts.each do |host|
        value = nil
        lambda { value = @ca.host2csrfile host }.should_not raise_error

        File.join(Puppet[:csrdir], host.downcase + '.pem').should == value
      end
    end
  end

  describe 'when listing' do
    it 'should find all csr' do
      list = []

      # Make some fake CSRs
      @hosts.each do |host|
        file = File.join(Puppet[:csrdir], host.downcase + '.pem')
        File.open(file, 'w') { |f| f.puts "yay" }
        list << host.downcase
      end

      @ca.list.sort.should == list.sort
    end
  end

  describe 'when creating a root certificate' do
    before :each do
      lambda { @ca.mkrootcert }.should_not raise_exception
    end

    it 'should store the public key' do
      File.exists?(Puppet[:capub]).should be_true
    end

    it 'should prepend "Puppet CA: " to the fqdn as the ca_name by default' do
      host_mock_fact = mock()
      host_mock_fact.expects(:value).returns('myhost')
      domain_mock_fact = mock()
      domain_mock_fact.expects(:value).returns('puppetlabs.lan')
      Facter.stubs(:[]).with('hostname').returns(host_mock_fact)
      Facter.stubs(:[]).with('domain').returns(domain_mock_fact)

      @ca.mkrootcert.name.should == 'Puppet CA: myhost.puppetlabs.lan'
    end
  end
end
