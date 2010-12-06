#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../lib/puppettest')

require 'puppettest'
#require 'puppettest/fileparsing'
#require 'puppet/type/port'
#require 'test/unit'
#require 'facter'
#
#class TestParsedPort < Test::Unit::TestCase
#    include PuppetTest
#    include PuppetTest::FileParsing
#
#    def setup
#        super
#        @provider = Puppet::Type.type(:port).provider(:parsed)
#        @oldfiletype = @provider.filetype
#    end
#
#    def teardown
#        Puppet::Util::FileType.filetype(:ram).clear
#        @provider.filetype = @oldfiletype
#        @provider.clear
#        super
#    end
#
#    # Generate a line from a hash.  The line might include '\n'.
#    def genline(hash)
#        line = [hash[:name], "#{hash[:number]}/%s"].join("\t\t")
#        if hash[:alias]
#            line += "\t\t" + hash[:alias].join(" ")
#        end
#        if hash[:description]
#            line += "\t# " + hash[:description]
#        end
#
#        return hash[:protocols].collect { |p| line % p }.join("\n")
#    end
#
#    # Parse our sample data and make sure we regenerate it correctly.
#    def test_portsparse
#        files = fakedata("data/types/port")
#        files.each do |file|
#            oldtarget = @provider.default_target
#            cleanup do
#                @provider.default_target = oldtarget
#            end
#            @provider.default_target = file
#
#            assert_nothing_raised("failed to fetch #{file}") {
#                @provider.prefetch
#            }
#
#            hashes = @provider.target_records(file).find_all { |i| i.is_a? Hash }
#            assert(hashes.length > 0, "Did not create any hashes")
#            dns = hashes.find { |i| i[:name] == "domain" }
#
#            assert(dns, "Did not retrieve dns record")
#            assert_equal("53", dns[:number], "dns number is wrong")
#
#            text = nil
#            assert_nothing_raised("failed to generate #{file}") do
#                text = @provider.to_file(@provider.target_records(file))
#            end
#
#            oldlines = File.readlines(file)
#            newlines = text.chomp.split "\n"
#            regex = /^(\S+)\s+(\d+)\/(\w+)/
#            oldlines.zip(newlines).each do |old, new|
#                if omatch = regex.match(old)
#                    assert(newmatch = regex.match(new),
#                        "Lines were not equivalent: %s vs %s" %
#                        [old.inspect, new.inspect]
#                    )
#                    oldfields = omatch.captures and
#                    newfields = newmatch.captures
#
#                    assert_equal(oldfields, newfields,
#                        "Lines were not equivalent: %s vs %s" %
#                        [old.inspect, new.inspect]
#                    )
#                end
#            #    assert_equal(old.chomp.gsub(/\s+/, ''),
#            #        new.gsub(/\s+/, ''),
#            #        "Lines are not equal in #{file}")
#            end
#        end
#    end
#
#    # Try parsing the different forms of lines
#    def test_parsing
#        # Each of the different possible values for each field.
#        options = {
#            :name => "service",
#            :number => "1",
#            :alias => [nil, ["null"], %w{null sink}, %w{null sink other}],
#            :description => [nil, "my description"],
#            :protocols => [%w{tcp}, %w{udp}, %w{tcp udp}]
#        }
#
#        # Now go through all of the different iterations and make sure we
#        # parse them correctly.
#        keys = options.keys
#
#        name = options[:name]
#        number = options[:number]
#        options[:alias].each do |al|
#            options[:description].each do |desc|
#                options[:protocols].each do |proto|
#                    hash = {:name => name, :number => number, :alias => al,
#                        :description => desc, :protocols => proto}
#                    line = genline(hash)
#
#                    # Try parsing it
#                    record = nil
#                    assert_nothing_raised do
#                        record = @provider.parse_line(line)
#                    end
#                    assert(record, "Did not get record returned")
#                    hash.each do |param, value|
#                        if value
#                            assert_equal(value, record[param],
#                                "did not get #{param} out of '#{line}'")
#                        end
#                    end
#
#                    # Now make sure it generates correctly
#                    assert_equal(line, @provider.to_line(record),
#                        "Did not generate #{line} correctly")
#                end
#            end
#        end
#    end
#
#    # Make sure we correctly join lines by name, so that they're considered
#    # a single record.
#    def test_lines
#        result = nil
#        assert_nothing_raised do
#            result = @provider.lines(
#"smtp        25/tcp      mail
#time        37/tcp      timserver
#time        37/udp      timserver
#rlp     39/udp      resource    # resource location
#tacacs      49/tcp              # Login Host Protocol (TACACS)
#nameserver  42/tcp      name        # IEN 116
#whois       43/tcp      nicname
#tacacs      49/udp
#re-mail-ck  50/tcp              # Remote Mail Checking Protocol
#domain      53/tcp      nameserver  # name-domain server
#re-mail-ck  50/udp
#domain      53/udp      nameserver"
#            )
#        end
#
#        assert_equal([
#"smtp        25/tcp      mail",
#"time        37/tcp      timserver
#time        37/udp      timserver",
#"rlp     39/udp      resource    # resource location",
#"tacacs      49/tcp              # Login Host Protocol (TACACS)
#tacacs      49/udp",
#"nameserver  42/tcp      name        # IEN 116",
#"whois       43/tcp      nicname",
#"re-mail-ck  50/tcp              # Remote Mail Checking Protocol
#re-mail-ck  50/udp",
#"domain      53/tcp      nameserver  # name-domain server
#domain      53/udp      nameserver"
#], result)
#
#    end
#
#    # Make sure we correctly handle port merging.
#    def test_port_merge
#        fields = [:name, :number, :protocols, :alias, :description]
#        base = %w{a 1}
#
#        z = proc { |ary| h = {}; fields.zip(ary) { |p,v| h[p] = v if v }; h }
#
#        # Make sure our zipper is working
#        assert_equal({:name => "a", :number => "1", :protocols => %w{tcp udp}},
#            z.call(["a", "1", %w{tcp udp}])
#        )
#
#        # Here we go through the different options, just testing each key
#        # separately.
#        {
#            # The degenerate case - just two protocols
#            [%w{tcp udp}] => [[%w{tcp}], [%w{udp}]],
#
#            # one alias
#            [%w{tcp udp}, %w{A}] => [[%w{tcp}, %w{A}], [%w{udp}]],
#
#            # Other side
#            [%w{tcp udp}, %w{A}] => [[%w{tcp}], [%w{udp}], %w{A}],
#
#            # Both
#            [%w{tcp udp}, %w{A}] => [[%w{tcp}, %w{A}], [%w{udp}], %w{A}],
#
#            # Adding aliases
#            [%w{tcp udp}, %w{A B}] => [[%w{tcp}, %w{A}], [%w{udp}], %w{B}],
#
#            # Merging aliases
#            [%w{tcp udp}, %w{A B}] => [[%w{tcp}, %w{A B}], [%w{udp}], %w{B}],
#
#            # One description
#            [%w{tcp udp}, nil, "desc"] => [[%w{tcp}, nil, "desc"], [%w{udp}] ],
#
#            # other side
#            [%w{tcp udp}, nil, "desc"] => [[%w{tcp}], [%w{udp}, nil, "desc"] ],
#
#            # Conflicting -- first hash wins
#            [%w{tcp udp}, nil, "first"] =>
#                [[%w{tcp}, nil, "first"], [%w{udp}, nil, "desc"] ],
#        }.each do |result, hashes|
#            assert_equal(
#                z.call(base + result),
#                @provider.port_merge(
#                    z.call(base + hashes[0]),
#                    z.call(base + hashes[1])
#                ),
#                "Did not get %s out of %s + %s" % [
#                    result.inspect,
#                    hashes[0].inspect,
#                    hashes[1].inspect
#                ]
#            )
#        end
#    end
#end

