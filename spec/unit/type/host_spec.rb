#! /usr/bin/env ruby
require 'spec_helper'

host = Puppet::Type.type(:host)

describe host do
  FakeHostProvider = Struct.new(:ip, :host_aliases, :comment)
  before do
    @class = host
    @catalog = Puppet::Resource::Catalog.new
    @provider = FakeHostProvider.new
    @resource = stub 'resource', :resource => nil, :provider => @provider
  end

  it "should have :name be its namevar" do
    expect(@class.key_attributes).to eq([:name])
  end

  describe "when validating attributes" do
    [:name, :provider ].each do |param|
      it "should have a #{param} parameter" do
        expect(@class.attrtype(param)).to eq(:param)
      end
    end

    [:ip, :target, :host_aliases, :comment, :ensure].each do |property|
      it "should have a #{property} property" do
        expect(@class.attrtype(property)).to eq(:property)
      end
    end

    it "should have a list host_aliases" do
      expect(@class.attrclass(:host_aliases).ancestors).to be_include(Puppet::Property::OrderedList)
    end

  end

  describe "when validating values" do
    it "should support present as a value for ensure" do
      expect { @class.new(:name => "foo", :ensure => :present) }.not_to raise_error
    end

    it "should support absent as a value for ensure" do
      expect { @class.new(:name => "foo", :ensure => :absent) }.not_to raise_error
    end

    it "should accept IPv4 addresses" do
      expect { @class.new(:name => "foo", :ip => '10.96.0.1') }.not_to raise_error
    end

    it "should accept long IPv6 addresses" do
      # Taken from wikipedia article about ipv6
      expect { @class.new(:name => "foo", :ip => '2001:0db8:85a3:08d3:1319:8a2e:0370:7344') }.not_to raise_error
    end

    it "should accept one host_alias" do
      expect { @class.new(:name => "foo", :host_aliases => 'alias1') }.not_to raise_error
    end

    it "should accept multiple host_aliases" do
      expect { @class.new(:name => "foo", :host_aliases => [ 'alias1', 'alias2' ]) }.not_to raise_error
    end

    it "should accept shortened IPv6 addresses" do
      expect { @class.new(:name => "foo", :ip => '2001:db8:0:8d3:0:8a2e:70:7344') }.not_to raise_error
      expect { @class.new(:name => "foo", :ip => '::ffff:192.0.2.128') }.not_to raise_error
      expect { @class.new(:name => "foo", :ip => '::1') }.not_to raise_error
    end

    it "should not accept malformed IPv4 addresses like 192.168.0.300" do
      expect { @class.new(:name => "foo", :ip => '192.168.0.300') }.to raise_error(Puppet::ResourceError, /Parameter ip failed/)
    end

    it "should reject over-long IPv4 addresses" do
      expect { @class.new(:name => "foo", :ip => '10.10.10.10.10') }.to raise_error(Puppet::ResourceError, /Parameter ip failed/)
    end

    it "should not accept malformed IP addresses like 2001:0dg8:85a3:08d3:1319:8a2e:0370:7344" do
      expect { @class.new(:name => "foo", :ip => '2001:0dg8:85a3:08d3:1319:8a2e:0370:7344') }.to raise_error(Puppet::ResourceError, /Parameter ip failed/)
    end

    # Assorted, annotated IPv6 passes.
    ["::1",                          # loopback, compressed, non-routable
     "::",                           # unspecified, compressed, non-routable
     "0:0:0:0:0:0:0:1",              # loopback, full
     "0:0:0:0:0:0:0:0",              # unspecified, full
     "2001:DB8:0:0:8:800:200C:417A", # unicast, full
     "FF01:0:0:0:0:0:0:101",         # multicast, full
     "2001:DB8::8:800:200C:417A",    # unicast, compressed
     "FF01::101",                    # multicast, compressed
     # Some more test cases that should pass.
     "2001:0000:1234:0000:0000:C1C0:ABCD:0876",
     "3ffe:0b00:0000:0000:0001:0000:0000:000a",
     "FF02:0000:0000:0000:0000:0000:0000:0001",
     "0000:0000:0000:0000:0000:0000:0000:0001",
     "0000:0000:0000:0000:0000:0000:0000:0000",
     # Assorted valid, compressed IPv6 addresses.
     "2::10",
     "ff02::1",
     "fe80::",
     "2002::",
     "2001:db8::",
     "2001:0db8:1234::",
     "::ffff:0:0",
     "::1",
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
     "::2:3:4:5:6:7:8",
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
     # IPv4 addresses as dotted-quads
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
     "::ffff:192.168.1.26",
     "::ffff:192.168.1.1",
     "0:0:0:0:0:0:13.1.68.3", # IPv4-compatible IPv6 address, full, deprecated
     "0:0:0:0:0:FFFF:129.144.52.38", # IPv4-mapped IPv6 address, full
     "::13.1.68.3",             # IPv4-compatible IPv6 address, compressed, deprecated
     "::FFFF:129.144.52.38",    # IPv4-mapped IPv6 address, compressed
     "fe80:0:0:0:204:61ff:254.157.241.86",
     "fe80::204:61ff:254.157.241.86",
     "::ffff:12.34.56.78",
     "::ffff:192.0.2.128",      # this is OK, since there's a single zero digit in IPv4
     "fe80:0000:0000:0000:0204:61ff:fe9d:f156",
     "fe80:0:0:0:204:61ff:fe9d:f156",
     "fe80::204:61ff:fe9d:f156",
     "::1",
     "fe80::",
     "fe80::1",
     "::ffff:c000:280",

     # Additional test cases from http://rt.cpan.org/Public/Bug/Display.html?id=50693
     "2001:0db8:85a3:0000:0000:8a2e:0370:7334",
     "2001:db8:85a3:0:0:8a2e:370:7334",
     "2001:db8:85a3::8a2e:370:7334",
     "2001:0db8:0000:0000:0000:0000:1428:57ab",
     "2001:0db8:0000:0000:0000::1428:57ab",
     "2001:0db8:0:0:0:0:1428:57ab",
     "2001:0db8:0:0::1428:57ab",
     "2001:0db8::1428:57ab",
     "2001:db8::1428:57ab",
     "0000:0000:0000:0000:0000:0000:0000:0001",
     "::1",
     "::ffff:0c22:384e",
     "2001:0db8:1234:0000:0000:0000:0000:0000",
     "2001:0db8:1234:ffff:ffff:ffff:ffff:ffff",
     "2001:db8:a::123",
     "fe80::",

     "1111:2222:3333:4444:5555:6666:7777:8888",
     "1111:2222:3333:4444:5555:6666:7777::",
     "1111:2222:3333:4444:5555:6666::",
     "1111:2222:3333:4444:5555::",
     "1111:2222:3333:4444::",
     "1111:2222:3333::",
     "1111:2222::",
     "1111::",
     "1111:2222:3333:4444:5555:6666::8888",
     "1111:2222:3333:4444:5555::8888",
     "1111:2222:3333:4444::8888",
     "1111:2222:3333::8888",
     "1111:2222::8888",
     "1111::8888",
     "::8888",
     "1111:2222:3333:4444:5555::7777:8888",
     "1111:2222:3333:4444::7777:8888",
     "1111:2222:3333::7777:8888",
     "1111:2222::7777:8888",
     "1111::7777:8888",
     "::7777:8888",
     "1111:2222:3333:4444::6666:7777:8888",
     "1111:2222:3333::6666:7777:8888",
     "1111:2222::6666:7777:8888",
     "1111::6666:7777:8888",
     "::6666:7777:8888",
     "1111:2222:3333::5555:6666:7777:8888",
     "1111:2222::5555:6666:7777:8888",
     "1111::5555:6666:7777:8888",
     "::5555:6666:7777:8888",
     "1111:2222::4444:5555:6666:7777:8888",
     "1111::4444:5555:6666:7777:8888",
     "::4444:5555:6666:7777:8888",
     "1111::3333:4444:5555:6666:7777:8888",
     "::3333:4444:5555:6666:7777:8888",
     "::2222:3333:4444:5555:6666:7777:8888",
     "1111:2222:3333:4444:5555:6666:123.123.123.123",
     "1111:2222:3333:4444:5555::123.123.123.123",
     "1111:2222:3333:4444::123.123.123.123",
     "1111:2222:3333::123.123.123.123",
     "1111:2222::123.123.123.123",
     "1111::123.123.123.123",
     "::123.123.123.123",
     "1111:2222:3333:4444::6666:123.123.123.123",
     "1111:2222:3333::6666:123.123.123.123",
     "1111:2222::6666:123.123.123.123",
     "1111::6666:123.123.123.123",
     "::6666:123.123.123.123",
     "1111:2222:3333::5555:6666:123.123.123.123",
     "1111:2222::5555:6666:123.123.123.123",
     "1111::5555:6666:123.123.123.123",
     "::5555:6666:123.123.123.123",
     "1111:2222::4444:5555:6666:123.123.123.123",
     "1111::4444:5555:6666:123.123.123.123",
     "::4444:5555:6666:123.123.123.123",
     "1111::3333:4444:5555:6666:123.123.123.123",
     "::2222:3333:4444:5555:6666:123.123.123.123",

     # Playing with combinations of "0" and "::"; these are all sytactically
     # correct, but are bad form because "0" adjacent to "::" should be
     # combined into "::"
     "::0:0:0:0:0:0:0",
     "::0:0:0:0:0:0",
     "::0:0:0:0:0",
     "::0:0:0:0",
     "::0:0:0",
     "::0:0",
     "::0",
     "0:0:0:0:0:0:0::",
     "0:0:0:0:0:0::",
     "0:0:0:0:0::",
     "0:0:0:0::",
     "0:0:0::",
     "0:0::",
     "0::",

     # Additional cases: http://crisp.tweakblogs.net/blog/2031/ipv6-validation-%28and-caveats%29.html
     "0:a:b:c:d:e:f::",
     "::0:a:b:c:d:e:f", # syntactically correct, but bad form (::0:... could be combined)
     "a:b:c:d:e:f:0::",
    ].each do |ip|
      it "should accept #{ip.inspect} as an IPv6 address" do
        expect { @class.new(:name => "foo", :ip => ip) }.not_to raise_error
      end
    end

    # ...aaaand, some failure cases.
    [":",
     "02001:0000:1234:0000:0000:C1C0:ABCD:0876",     # extra 0 not allowed!
     "2001:0000:1234:0000:00001:C1C0:ABCD:0876",     # extra 0 not allowed!
     "2001:0000:1234:0000:0000:C1C0:ABCD:0876  0",   # junk after valid address
     "2001:0000:1234: 0000:0000:C1C0:ABCD:0876",     # internal space
     "3ffe:0b00:0000:0001:0000:0000:000a",           # seven segments
     "FF02:0000:0000:0000:0000:0000:0000:0000:0001", # nine segments
     "3ffe:b00::1::a",                               # double "::"
     "::1111:2222:3333:4444:5555:6666::",            # double "::"
     "1:2:3::4:5::7:8",                              # Double "::"
     "12345::6:7:8",
     # IPv4 embedded, but bad...
     "1::5:400.2.3.4", "1::5:260.2.3.4", "1::5:256.2.3.4", "1::5:1.256.3.4",
     "1::5:1.2.256.4", "1::5:1.2.3.256", "1::5:300.2.3.4", "1::5:1.300.3.4",
     "1::5:1.2.300.4", "1::5:1.2.3.300", "1::5:900.2.3.4", "1::5:1.900.3.4",
     "1::5:1.2.900.4", "1::5:1.2.3.900", "1::5:300.300.300.300", "1::5:3000.30.30.30",
     "1::400.2.3.4", "1::260.2.3.4", "1::256.2.3.4", "1::1.256.3.4",
     "1::1.2.256.4", "1::1.2.3.256", "1::300.2.3.4", "1::1.300.3.4",
     "1::1.2.300.4", "1::1.2.3.300", "1::900.2.3.4", "1::1.900.3.4",
     "1::1.2.900.4", "1::1.2.3.900", "1::300.300.300.300", "1::3000.30.30.30",
     "::400.2.3.4", "::260.2.3.4", "::256.2.3.4", "::1.256.3.4",
     "::1.2.256.4", "::1.2.3.256", "::300.2.3.4", "::1.300.3.4",
     "::1.2.300.4", "::1.2.3.300", "::900.2.3.4", "::1.900.3.4",
     "::1.2.900.4", "::1.2.3.900", "::300.300.300.300", "::3000.30.30.30",
     "2001:1:1:1:1:1:255Z255X255Y255", # garbage instead of "." in IPv4
     "::ffff:192x168.1.26",            # ditto
     "::ffff:2.3.4",
     "::ffff:257.1.2.3",
     "1.2.3.4:1111:2222:3333:4444::5555",
     "1.2.3.4:1111:2222:3333::5555",
     "1.2.3.4:1111:2222::5555",
     "1.2.3.4:1111::5555",
     "1.2.3.4::5555",
     "1.2.3.4::",

     # Testing IPv4 addresses represented as dotted-quads Leading zero's in
     # IPv4 addresses not allowed: some systems treat the leading "0" in
     # ".086" as the start of an octal number Update: The BNF in RFC-3986
     # explicitly defines the dec-octet (for IPv4 addresses) not to have a
     # leading zero
     "fe80:0000:0000:0000:0204:61ff:254.157.241.086",
     "XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:1.2.3.4",
     "1111:2222:3333:4444:5555:6666:00.00.00.00",
     "1111:2222:3333:4444:5555:6666:000.000.000.000",
     "1111:2222:3333:4444:5555:6666:256.256.256.256",

     "1111:2222:3333:4444::5555:",
     "1111:2222:3333::5555:",
     "1111:2222::5555:",
     "1111::5555:",
     "::5555:",
     ":::",
     "1111:",
     ":",

     ":1111:2222:3333:4444::5555",
     ":1111:2222:3333::5555",
     ":1111:2222::5555",
     ":1111::5555",
     ":::5555",
     ":::",

     # Additional test cases from http://rt.cpan.org/Public/Bug/Display.html?id=50693
     "123",
     "ldkfj",
     "2001::FFD3::57ab",
     "2001:db8:85a3::8a2e:37023:7334",
     "2001:db8:85a3::8a2e:370k:7334",
     "1:2:3:4:5:6:7:8:9",
     "1::2::3",
     "1:::3:4:5",
     "1:2:3::4:5:6:7:8:9",

     # Invalid data
     "XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX",

     # Too many components
     "1111:2222:3333:4444:5555:6666:7777:8888:9999",
     "1111:2222:3333:4444:5555:6666:7777:8888::",
     "::2222:3333:4444:5555:6666:7777:8888:9999",

     # Too few components
     "1111:2222:3333:4444:5555:6666:7777",
     "1111:2222:3333:4444:5555:6666",
     "1111:2222:3333:4444:5555",
     "1111:2222:3333:4444",
     "1111:2222:3333",
     "1111:2222",
     "1111",

     # Missing :
     "11112222:3333:4444:5555:6666:7777:8888",
     "1111:22223333:4444:5555:6666:7777:8888",
     "1111:2222:33334444:5555:6666:7777:8888",
     "1111:2222:3333:44445555:6666:7777:8888",
     "1111:2222:3333:4444:55556666:7777:8888",
     "1111:2222:3333:4444:5555:66667777:8888",
     "1111:2222:3333:4444:5555:6666:77778888",

     # Missing : intended for ::
     "1111:2222:3333:4444:5555:6666:7777:8888:",
     "1111:2222:3333:4444:5555:6666:7777:",
     "1111:2222:3333:4444:5555:6666:",
     "1111:2222:3333:4444:5555:",
     "1111:2222:3333:4444:",
     "1111:2222:3333:",
     "1111:2222:",
     "1111:",
     ":",
     ":8888",
     ":7777:8888",
     ":6666:7777:8888",
     ":5555:6666:7777:8888",
     ":4444:5555:6666:7777:8888",
     ":3333:4444:5555:6666:7777:8888",
     ":2222:3333:4444:5555:6666:7777:8888",
     ":1111:2222:3333:4444:5555:6666:7777:8888",

     # :::
     ":::2222:3333:4444:5555:6666:7777:8888",
     "1111:::3333:4444:5555:6666:7777:8888",
     "1111:2222:::4444:5555:6666:7777:8888",
     "1111:2222:3333:::5555:6666:7777:8888",
     "1111:2222:3333:4444:::6666:7777:8888",
     "1111:2222:3333:4444:5555:::7777:8888",
     "1111:2222:3333:4444:5555:6666:::8888",
     "1111:2222:3333:4444:5555:6666:7777:::",

     # Double ::",
     "::2222::4444:5555:6666:7777:8888",
     "::2222:3333::5555:6666:7777:8888",
     "::2222:3333:4444::6666:7777:8888",
     "::2222:3333:4444:5555::7777:8888",
     "::2222:3333:4444:5555:7777::8888",
     "::2222:3333:4444:5555:7777:8888::",

     "1111::3333::5555:6666:7777:8888",
     "1111::3333:4444::6666:7777:8888",
     "1111::3333:4444:5555::7777:8888",
     "1111::3333:4444:5555:6666::8888",
     "1111::3333:4444:5555:6666:7777::",

     "1111:2222::4444::6666:7777:8888",
     "1111:2222::4444:5555::7777:8888",
     "1111:2222::4444:5555:6666::8888",
     "1111:2222::4444:5555:6666:7777::",

     "1111:2222:3333::5555::7777:8888",
     "1111:2222:3333::5555:6666::8888",
     "1111:2222:3333::5555:6666:7777::",

     "1111:2222:3333:4444::6666::8888",
     "1111:2222:3333:4444::6666:7777::",

     "1111:2222:3333:4444:5555::7777::",


     # Too many components"
     "1111:2222:3333:4444:5555:6666:7777:8888:1.2.3.4",
     "1111:2222:3333:4444:5555:6666:7777:1.2.3.4",
     "1111:2222:3333:4444:5555:6666::1.2.3.4",
     "::2222:3333:4444:5555:6666:7777:1.2.3.4",
     "1111:2222:3333:4444:5555:6666:1.2.3.4.5",

     # Too few components
     "1111:2222:3333:4444:5555:1.2.3.4",
     "1111:2222:3333:4444:1.2.3.4",
     "1111:2222:3333:1.2.3.4",
     "1111:2222:1.2.3.4",
     "1111:1.2.3.4",

     # Missing :
     "11112222:3333:4444:5555:6666:1.2.3.4",
     "1111:22223333:4444:5555:6666:1.2.3.4",
     "1111:2222:33334444:5555:6666:1.2.3.4",
     "1111:2222:3333:44445555:6666:1.2.3.4",
     "1111:2222:3333:4444:55556666:1.2.3.4",
     "1111:2222:3333:4444:5555:66661.2.3.4",

     # Missing .
     "1111:2222:3333:4444:5555:6666:255255.255.255",
     "1111:2222:3333:4444:5555:6666:255.255255.255",
     "1111:2222:3333:4444:5555:6666:255.255.255255",

     # Missing : intended for ::
     ":1.2.3.4",
     ":6666:1.2.3.4",
     ":5555:6666:1.2.3.4",
     ":4444:5555:6666:1.2.3.4",
     ":3333:4444:5555:6666:1.2.3.4",
     ":2222:3333:4444:5555:6666:1.2.3.4",
     ":1111:2222:3333:4444:5555:6666:1.2.3.4",

     # :::
     ":::2222:3333:4444:5555:6666:1.2.3.4",
     "1111:::3333:4444:5555:6666:1.2.3.4",
     "1111:2222:::4444:5555:6666:1.2.3.4",
     "1111:2222:3333:::5555:6666:1.2.3.4",
     "1111:2222:3333:4444:::6666:1.2.3.4",
     "1111:2222:3333:4444:5555:::1.2.3.4",

     # Double ::
     "::2222::4444:5555:6666:1.2.3.4",
     "::2222:3333::5555:6666:1.2.3.4",
     "::2222:3333:4444::6666:1.2.3.4",
     "::2222:3333:4444:5555::1.2.3.4",

     "1111::3333::5555:6666:1.2.3.4",
     "1111::3333:4444::6666:1.2.3.4",
     "1111::3333:4444:5555::1.2.3.4",

     "1111:2222::4444::6666:1.2.3.4",
     "1111:2222::4444:5555::1.2.3.4",

     "1111:2222:3333::5555::1.2.3.4",

     # Missing parts
     "::.",
     "::..",
     "::...",
     "::1...",
     "::1.2..",
     "::1.2.3.",
     "::.2..",
     "::.2.3.",
     "::.2.3.4",
     "::..3.",
     "::..3.4",
     "::...4",

     # Extra : in front
     ":1111:2222:3333:4444:5555:6666:7777::",
     ":1111:2222:3333:4444:5555:6666::",
     ":1111:2222:3333:4444:5555::",
     ":1111:2222:3333:4444::",
     ":1111:2222:3333::",
     ":1111:2222::",
     ":1111::",
     ":::",
     ":1111:2222:3333:4444:5555:6666::8888",
     ":1111:2222:3333:4444:5555::8888",
     ":1111:2222:3333:4444::8888",
     ":1111:2222:3333::8888",
     ":1111:2222::8888",
     ":1111::8888",
     ":::8888",
     ":1111:2222:3333:4444:5555::7777:8888",
     ":1111:2222:3333:4444::7777:8888",
     ":1111:2222:3333::7777:8888",
     ":1111:2222::7777:8888",
     ":1111::7777:8888",
     ":::7777:8888",
     ":1111:2222:3333:4444::6666:7777:8888",
     ":1111:2222:3333::6666:7777:8888",
     ":1111:2222::6666:7777:8888",
     ":1111::6666:7777:8888",
     ":::6666:7777:8888",
     ":1111:2222:3333::5555:6666:7777:8888",
     ":1111:2222::5555:6666:7777:8888",
     ":1111::5555:6666:7777:8888",
     ":::5555:6666:7777:8888",
     ":1111:2222::4444:5555:6666:7777:8888",
     ":1111::4444:5555:6666:7777:8888",
     ":::4444:5555:6666:7777:8888",
     ":1111::3333:4444:5555:6666:7777:8888",
     ":::3333:4444:5555:6666:7777:8888",
     ":::2222:3333:4444:5555:6666:7777:8888",
     ":1111:2222:3333:4444:5555:6666:1.2.3.4",
     ":1111:2222:3333:4444:5555::1.2.3.4",
     ":1111:2222:3333:4444::1.2.3.4",
     ":1111:2222:3333::1.2.3.4",
     ":1111:2222::1.2.3.4",
     ":1111::1.2.3.4",
     ":::1.2.3.4",
     ":1111:2222:3333:4444::6666:1.2.3.4",
     ":1111:2222:3333::6666:1.2.3.4",
     ":1111:2222::6666:1.2.3.4",
     ":1111::6666:1.2.3.4",
     ":::6666:1.2.3.4",
     ":1111:2222:3333::5555:6666:1.2.3.4",
     ":1111:2222::5555:6666:1.2.3.4",
     ":1111::5555:6666:1.2.3.4",
     ":::5555:6666:1.2.3.4",
     ":1111:2222::4444:5555:6666:1.2.3.4",
     ":1111::4444:5555:6666:1.2.3.4",
     ":::4444:5555:6666:1.2.3.4",
     ":1111::3333:4444:5555:6666:1.2.3.4",
     ":::2222:3333:4444:5555:6666:1.2.3.4",

     # Extra : at end
     "1111:2222:3333:4444:5555:6666:7777:::",
     "1111:2222:3333:4444:5555:6666:::",
     "1111:2222:3333:4444:5555:::",
     "1111:2222:3333:4444:::",
     "1111:2222:3333:::",
     "1111:2222:::",
     "1111:::",
     ":::",
     "1111:2222:3333:4444:5555:6666::8888:",
     "1111:2222:3333:4444:5555::8888:",
     "1111:2222:3333:4444::8888:",
     "1111:2222:3333::8888:",
     "1111:2222::8888:",
     "1111::8888:",
     "::8888:",
     "1111:2222:3333:4444:5555::7777:8888:",
     "1111:2222:3333:4444::7777:8888:",
     "1111:2222:3333::7777:8888:",
     "1111:2222::7777:8888:",
     "1111::7777:8888:",
     "::7777:8888:",
     "1111:2222:3333:4444::6666:7777:8888:",
     "1111:2222:3333::6666:7777:8888:",
     "1111:2222::6666:7777:8888:",
     "1111::6666:7777:8888:",
     "::6666:7777:8888:",
     "1111:2222:3333::5555:6666:7777:8888:",
     "1111:2222::5555:6666:7777:8888:",
     "1111::5555:6666:7777:8888:",
     "::5555:6666:7777:8888:",
     "1111:2222::4444:5555:6666:7777:8888:",
     "1111::4444:5555:6666:7777:8888:",
     "::4444:5555:6666:7777:8888:",
     "1111::3333:4444:5555:6666:7777:8888:",
     "::3333:4444:5555:6666:7777:8888:",
     "::2222:3333:4444:5555:6666:7777:8888:",
    ].each do |ip|
      it "should reject #{ip.inspect} as an IPv6 address" do
        expect { @class.new(:name => "foo", :ip => ip) }.to raise_error(Puppet::ResourceError, /Parameter ip failed/)
      end
    end

    it "should not accept newlines in resourcename" do
      expect { @class.new(:name => "fo\no", :ip => '127.0.0.1' ) }.to  raise_error(Puppet::ResourceError, /Hostname cannot include newline/)
    end

    it "should not accept newlines in ipaddress" do
      expect { @class.new(:name => "foo", :ip => "127.0.0.1\n") }.to raise_error(Puppet::ResourceError, /Invalid IP address/)
    end

    it "should not accept newlines in host_aliases" do
      expect { @class.new(:name => "foo", :ip => '127.0.0.1', :host_aliases => [ 'well_formed', "thisalias\nhavenewline" ] ) }.to raise_error(Puppet::ResourceError, /Host aliases cannot include whitespace/)
    end

    it "should not accept newlines in comment" do
      expect { @class.new(:name => "foo", :ip => '127.0.0.1', :comment => "Test of comment blah blah \n test 123" ) }.to raise_error(Puppet::ResourceError, /Comment cannot include newline/)
    end

    it "should not accept spaces in resourcename" do
      expect { @class.new(:name => "foo bar") }.to raise_error(Puppet::ResourceError, /Invalid host name/)
    end

    it "should not accept host_aliases with spaces" do
      expect { @class.new(:name => "foo", :host_aliases => [ 'well_formed', 'not wellformed' ]) }.to raise_error(Puppet::ResourceError, /Host aliases cannot include whitespace/)
    end

    it "should not accept empty host_aliases" do
      expect { @class.new(:name => "foo", :host_aliases => ['alias1','']) }.to raise_error(Puppet::ResourceError, /Host aliases cannot be an empty string/)
    end
  end

  describe "when syncing" do

    it "should send the first value to the provider for ip property" do
      @ip = @class.attrclass(:ip).new(:resource => @resource, :should => %w{192.168.0.1 192.168.0.2})

      @ip.sync

      expect(@provider.ip).to eq('192.168.0.1')
    end

    it "should send the first value to the provider for comment property" do
      @comment = @class.attrclass(:comment).new(:resource => @resource, :should => %w{Bazinga Notme})

      @comment.sync

      expect(@provider.comment).to eq('Bazinga')
    end

    it "should send the joined array to the provider for host_alias" do
      @host_aliases = @class.attrclass(:host_aliases).new(:resource => @resource, :should => %w{foo bar})

      @host_aliases.sync

      expect(@provider.host_aliases).to eq('foo bar')
    end

    it "should also use the specified delimiter for joining" do
      @host_aliases = @class.attrclass(:host_aliases).new(:resource => @resource, :should => %w{foo bar})
      @host_aliases.stubs(:delimiter).returns "\t"

      @host_aliases.sync

      expect(@provider.host_aliases).to eq("foo\tbar")
    end

    it "should care about the order of host_aliases" do
      @host_aliases = @class.attrclass(:host_aliases).new(:resource => @resource, :should => %w{foo bar})
      expect(@host_aliases.insync?(%w{foo bar})).to eq(true)
      expect(@host_aliases.insync?(%w{bar foo})).to eq(false)
    end

    it "should not consider aliases to be in sync if should is a subset of current" do
      @host_aliases = @class.attrclass(:host_aliases).new(:resource => @resource, :should => %w{foo bar})
      expect(@host_aliases.insync?(%w{foo bar anotherone})).to eq(false)
    end

  end
end
