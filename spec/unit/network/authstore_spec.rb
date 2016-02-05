#! /usr/bin/env ruby
require 'spec_helper'
require 'rbconfig'

require 'puppet/network/authconfig'

describe Puppet::Network::AuthStore do
  before :each do
    @authstore = Puppet::Network::AuthStore.new
    @authstore.reset_interpolation
  end

  describe "when checking if the acl has some entries" do
    it "should be empty if no ACE have been entered" do
      expect(@authstore).to be_empty
    end

    it "should not be empty if it is a global allow" do
      @authstore.allow('*')

      expect(@authstore).not_to be_empty
    end

    it "should not be empty if at least one allow has been entered" do
      @authstore.allow_ip('1.1.1.*')

      expect(@authstore).not_to be_empty
    end

    it "should not be empty if at least one deny has been entered" do
      @authstore.deny_ip('1.1.1.*')

      expect(@authstore).not_to be_empty
    end
  end

  describe "when checking global allow" do
    it "should not be enabled by default" do
      expect(@authstore).not_to be_globalallow
      expect(@authstore).not_to be_allowed('foo.bar.com', '192.168.1.1')
    end

    it "should always allow when enabled" do
      @authstore.allow('*')

      expect(@authstore).to be_globalallow
      expect(@authstore).to be_allowed('foo.bar.com', '192.168.1.1')
    end
  end

  describe "when checking a regex type of allow" do
    before :each do
      @authstore.allow('/^(test-)?host[0-9]+\.other-domain\.(com|org|net)$|some-domain\.com/')
      @ip = '192.168.1.1'
    end
    ['host5.other-domain.com', 'test-host12.other-domain.net', 'foo.some-domain.com'].each { |name|
      it "should allow the host #{name}" do
        expect(@authstore).to be_allowed(name, @ip)
      end
    }
    ['host0.some-other-domain.com',''].each { |name|
      it "should not allow the host #{name}" do
        expect(@authstore).not_to be_allowed(name, @ip)
      end
    }
  end
end

describe Puppet::Network::AuthStore::Declaration do

  ['100.101.99.98','100.100.100.100','1.2.3.4','11.22.33.44'].each { |ip|
    describe "when the pattern is a simple numeric IP such as #{ip}" do
      before :each do
        @declaration = Puppet::Network::AuthStore::Declaration.new(:allow_ip,ip)
      end
      it "should match the specified IP" do
        expect(@declaration).to be_match('www.testsite.org',ip)
      end
      it "should not match other IPs" do
        expect(@declaration).not_to be_match('www.testsite.org','200.101.99.98')
      end
    end

    (1..3).each { |n|
      describe "when the pattern is an IP mask with #{n} numeric segments and a *" do
        before :each do
          @ip_pattern = ip.split('.')[0,n].join('.')+'.*'
          @declaration = Puppet::Network::AuthStore::Declaration.new(:allow_ip,@ip_pattern)
        end
        it "should match an IP in the range" do
          expect(@declaration).to be_match('www.testsite.org',ip)
        end
        it "should not match other IPs" do
          expect(@declaration).not_to be_match('www.testsite.org','200.101.99.98')
        end
        it "should not match IPs that differ in the last non-wildcard segment" do
          other = ip.split('.')
          other[n-1].succ!
          expect(@declaration).not_to be_match('www.testsite.org',other.join('.'))
        end
      end
    }
  }

  describe "when the pattern is a numeric IP with a back reference" do
    pending("implementation of backreferences for IP") do
      before :each do
        @ip = '100.101.$1'
        @declaration = Puppet::Network::AuthStore::Declaration.new(:allow_ip,@ip).interpolate('12.34'.match(/(.*)/))
      end
      it "should match an IP with the appropriate interpolation" do
        @declaration.should be_match('www.testsite.org',@ip.sub(/\$1/,'12.34'))
      end
      it "should not match other IPs" do
        @declaration.should_not be_match('www.testsite.org',@ip.sub(/\$1/,'66.34'))
      end
    end
  end

  [
    "02001:0000:1234:0000:0000:C1C0:ABCD:0876",
    "2001:0000:1234:0000:00001:C1C0:ABCD:0876",
    " 2001:0000:1234:0000:0000:C1C0:ABCD:0876  0",
    "2001:0000:1234: 0000:0000:C1C0:ABCD:0876",
    "3ffe:0b00:0000:0001:0000:0000:000a",
    "FF02:0000:0000:0000:0000:0000:0000:0000:0001",
    "3ffe:b00::1::a",
    "1:2:3::4:5::7:8",
    "12345::6:7:8",
    "1::5:400.2.3.4",
    "1::5:260.2.3.4",
    "1::5:256.2.3.4",
    "1::5:1.256.3.4",
    "1::5:1.2.256.4",
    "1::5:1.2.3.256",
    "1::5:300.2.3.4",
    "1::5:1.300.3.4",
    "1::5:1.2.300.4",
    "1::5:1.2.3.300",
    "1::5:900.2.3.4",
    "1::5:1.900.3.4",
    "1::5:1.2.900.4",
    "1::5:1.2.3.900",
    "1::5:300.300.300.300",
    "1::5:3000.30.30.30",
    "1::400.2.3.4",
    "1::260.2.3.4",
    "1::256.2.3.4",
    "1::1.256.3.4",
    "1::1.2.256.4",
    "1::1.2.3.256",
    "1::300.2.3.4",
    "1::1.300.3.4",
    "1::1.2.300.4",
    "1::1.2.3.300",
    "1::900.2.3.4",
    "1::1.900.3.4",
    "1::1.2.900.4",
    "1::1.2.3.900",
    "1::300.300.300.300",
    "1::3000.30.30.30",
    "::400.2.3.4",
    "::260.2.3.4",
    "::256.2.3.4",
    "::1.256.3.4",
    "::1.2.256.4",
    "::1.2.3.256",
    "::300.2.3.4",
    "::1.300.3.4",
    "::1.2.300.4",
    "::1.2.3.300",
    "::900.2.3.4",
    "::1.900.3.4",
    "::1.2.900.4",
    "::1.2.3.900",
    "::300.300.300.300",
    "::3000.30.30.30",
    "2001:DB8:0:0:8:800:200C:417A:221", # unicast, full
    "FF01::101::2" # multicast, compressed
  ].each { |invalid_ip|
    describe "when the pattern is an invalid IPv6 address such as #{invalid_ip}" do
      it "should raise an exception" do
        expect { Puppet::Network::AuthStore::Declaration.new(:allow,invalid_ip) }.to raise_error(Puppet::AuthStoreError, /Invalid pattern/)
      end
    end
  }

  [
    "1.2.3.4",
    "2001:0000:1234:0000:0000:C1C0:ABCD:0876",
    "3ffe:0b00:0000:0000:0001:0000:0000:000a",
    "FF02:0000:0000:0000:0000:0000:0000:0001",
    "0000:0000:0000:0000:0000:0000:0000:0001",
    "0000:0000:0000:0000:0000:0000:0000:0000",
    "::ffff:192.168.1.26",
    "2::10",
    "ff02::1",
    "fe80::",
    "2002::",
    "2001:db8::",
    "2001:0db8:1234::",
    "::ffff:0:0",
    "::1",
    "::ffff:192.168.1.1",
    "1:2:3:4:5:6:7:8",
    "1:2:3:4:5:6::8",
    "1:2:3:4:5::8",
    "1:2:3:4::8",
    "1:2:3::8",
    "1:2::8",
    "1::8",
    "1::2:3:4:5:6:7",
    "1::2:3:4:5:6",
    "1::2:3:4:5",
    "1::2:3:4",
    "1::2:3",
    "1::8",
    "::2:3:4:5:6:7",
    "::2:3:4:5:6",
    "::2:3:4:5",
    "::2:3:4",
    "::2:3",
    "::8",
    "1:2:3:4:5:6::",
    "1:2:3:4:5::",
    "1:2:3:4::",
    "1:2:3::",
    "1:2::",
    "1::",
    "1:2:3:4:5::7:8",
    "1:2:3:4::7:8",
    "1:2:3::7:8",
    "1:2::7:8",
    "1::7:8",
    "1:2:3:4:5:6:1.2.3.4",
    "1:2:3:4:5::1.2.3.4",
    "1:2:3:4::1.2.3.4",
    "1:2:3::1.2.3.4",
    "1:2::1.2.3.4",
    "1::1.2.3.4",
    "1:2:3:4::5:1.2.3.4",
    "1:2:3::5:1.2.3.4",
    "1:2::5:1.2.3.4",
    "1::5:1.2.3.4",
    "1::5:11.22.33.44",
    "fe80::217:f2ff:254.7.237.98",
    "fe80::217:f2ff:fe07:ed62",
    "2001:DB8:0:0:8:800:200C:417A", # unicast, full
    "FF01:0:0:0:0:0:0:101", # multicast, full
    "0:0:0:0:0:0:0:1", # loopback, full
    "0:0:0:0:0:0:0:0", # unspecified, full
    "2001:DB8::8:800:200C:417A", # unicast, compressed
    "FF01::101", # multicast, compressed
    "::1", # loopback, compressed, non-routable
    "::", # unspecified, compressed, non-routable
    "0:0:0:0:0:0:13.1.68.3", # IPv4-compatible IPv6 address, full, deprecated
    "0:0:0:0:0:FFFF:129.144.52.38", # IPv4-mapped IPv6 address, full
    "::13.1.68.3", # IPv4-compatible IPv6 address, compressed, deprecated
    "::FFFF:129.144.52.38", # IPv4-mapped IPv6 address, compressed
    "2001:0DB8:0000:CD30:0000:0000:0000:0000/60", # full, with prefix
    "2001:0DB8::CD30:0:0:0:0/60", # compressed, with prefix
    "2001:0DB8:0:CD30::/60", # compressed, with prefix #2
    "::/128", # compressed, unspecified address type, non-routable
    "::1/128", # compressed, loopback address type, non-routable
    "FF00::/8", # compressed, multicast address type
    "FE80::/10", # compressed, link-local unicast, non-routable
    "FEC0::/10", # compressed, site-local unicast, deprecated
    "127.0.0.1", # standard IPv4, loopback, non-routable
    "0.0.0.0", # standard IPv4, unspecified, non-routable
    "255.255.255.255", # standard IPv4
    "fe80:0000:0000:0000:0204:61ff:fe9d:f156",
    "fe80:0:0:0:204:61ff:fe9d:f156",
    "fe80::204:61ff:fe9d:f156",
    "fe80:0000:0000:0000:0204:61ff:254.157.241.086",
    "fe80:0:0:0:204:61ff:254.157.241.86",
    "fe80::204:61ff:254.157.241.86",
    "::1",
    "fe80::",
    "fe80::1"
  ].each { |ip|
    describe "when the pattern is a valid IP such as #{ip}" do
      before :each do
        @declaration = Puppet::Network::AuthStore::Declaration.new(:allow_ip,ip)
      end
      it "should match the specified IP" do
        expect(@declaration).to be_match('www.testsite.org',ip)
      end
      it "should not match other IPs" do
        expect(@declaration).not_to be_match('www.testsite.org','200.101.99.98')
      end
    end unless ip =~ /:.*\./ # Hybrid IPs aren't supported by ruby's ipaddr
  }

  [
    "::2:3:4:5:6:7:8",
  ].each { |ip|
    describe "when the pattern is a valid IP such as #{ip}" do
      let(:declaration) do
        Puppet::Network::AuthStore::Declaration.new(:allow_ip,ip)
      end

      issue_7477 = !(IPAddr.new(ip) rescue false)

      describe "on rubies with a fix for issue [7477](https://goo.gl/Bb1LU)", :if => issue_7477
        it "should match the specified IP" do
          expect(declaration).to be_match('www.testsite.org',ip)
        end
        it "should not match other IPs" do
          expect(declaration).not_to be_match('www.testsite.org','200.101.99.98')
        end
    end
  }

  {
  'spirit.mars.nasa.gov' => 'a PQDN',
  'ratchet.2ndsiteinc.com' => 'a PQDN with digits',
  'a.c.ru' => 'a PQDN with short segments',
  }.each {|pqdn,desc|
    describe "when the pattern is #{desc}" do
      before :each do
        @host = pqdn
        @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,@host)
      end
      it "should match the specified PQDN" do
        expect(@declaration).to be_match(@host,'200.101.99.98')
      end
      it "should not match a similar FQDN" do
        pending "FQDN consensus"
        expect(@declaration).not_to be_match(@host+'.','200.101.99.98')
      end
    end
  }

  ['abc.12seps.edu.phisher.biz','www.google.com','slashdot.org'].each { |host|
    (1...(host.split('.').length)).each { |n|
      describe "when the pattern is #{"*."+host.split('.')[-n,n].join('.')}" do
        before :each do
          @pattern = "*."+host.split('.')[-n,n].join('.')
          @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,@pattern)
        end
        it "should match #{host}" do
          expect(@declaration).to be_match(host,'1.2.3.4')
        end
        it "should not match www.testsite.gov" do
          expect(@declaration).not_to be_match('www.testsite.gov','200.101.99.98')
        end
        it "should not match hosts that differ in the first non-wildcard segment" do
          other = host.split('.')
          other[-n].succ!
          expect(@declaration).not_to be_match(other.join('.'),'1.2.3.4')
        end
      end
    }
  }

  describe "when the pattern is a FQDN" do
    before :each do
      @host = 'spirit.mars.nasa.gov.'
      @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,@host)
    end
    it "should match the specified FQDN" do
      pending "FQDN consensus"
      expect(@declaration).to be_match(@host,'200.101.99.98')
    end
    it "should not match a similar PQDN" do
      expect(@declaration).not_to be_match(@host[0..-2],'200.101.99.98')
    end
  end


  describe "when the pattern is an opaque string with a back reference" do
    before :each do
      @host = 'c216f41a-f902-4bfb-a222-850dd957bebb'
      @item = "/catalog/#{@host}"
      @pattern = %{^/catalog/([^/]+)$}
      @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,'$1')
    end
    it "should match an IP with the appropriate interpolation" do
      expect(@declaration.interpolate(@item.match(@pattern))).to be_match(@host,'10.0.0.5')
    end
  end

  describe "when the pattern is an opaque string with a back reference and the matched data contains dots" do
    before :each do
      @host = 'admin.mgmt.nym1'
      @item = "/catalog/#{@host}"
      @pattern = %{^/catalog/([^/]+)$}
      @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,'$1')
    end
    it "should match a name with the appropriate interpolation" do
      expect(@declaration.interpolate(@item.match(@pattern))).to be_match(@host,'10.0.0.5')
    end
  end

  describe "when the pattern is an opaque string with a back reference and the matched data contains dots with an initial prefix that looks like an IP address" do
    before :each do
      @host = '01.admin.mgmt.nym1'
      @item = "/catalog/#{@host}"
      @pattern = %{^/catalog/([^/]+)$}
      @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,'$1')
    end
    it "should match a name with the appropriate interpolation" do
      expect(@declaration.interpolate(@item.match(@pattern))).to be_match(@host,'10.0.0.5')
    end
  end

  describe "when comparing patterns" do
    before :each do
      @ip        = Puppet::Network::AuthStore::Declaration.new(:allow,'127.0.0.1')
      @host_name = Puppet::Network::AuthStore::Declaration.new(:allow,'www.hard_knocks.edu')
      @opaque    = Puppet::Network::AuthStore::Declaration.new(:allow,'hey_dude')
    end
    it "should consider ip addresses before host names" do
      expect(@ip < @host_name).to be_truthy
    end
    it "should consider ip addresses before opaque strings" do
      expect(@ip < @opaque).to be_truthy
    end
    it "should consider host_names before opaque strings" do
      expect(@host_name < @opaque).to be_truthy
    end
  end
end
