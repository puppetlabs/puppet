#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'puppettest/support/utils'
require 'base64'
require 'cgi'

class TestResourceServer < Test::Unit::TestCase
    include PuppetTest::Support::Utils
    include PuppetTest::ServerTest

    def verify_described(type, described)
        described.each do |name, trans|
            obj = nil
            assert_nothing_raised do
                obj = trans.to_type
            end

            assert(obj, "Could not create object")
            assert_nothing_raised do
                obj.retrieve
            end

            if trans.type == :package
                assert_equal(Puppet::Type.type(:package).defaultprovider.name, obj[:provider])
            end
        end
    end

    def test_describe_file
        # Make a file to describe
        file = tempfile()
        str = "yayness\n"

        server = nil

        assert_nothing_raised do
            server = Puppet::Network::Handler.resource.new()
        end

        [   [nil],
            [[:content, :mode], []],
            [[], [:content]],
            [[:content], [:mode]]
        ].each do |ary|
            retrieve = ary[0] || []
            ignore = ary[1] || []

            File.open(file, "w") { |f| f.print str }

            result = nil
            assert_nothing_raised do
                result = server.describe("file", file, *ary)
            end

            assert(result, "Could not retrieve file information")

            assert_instance_of(Puppet::TransObject, result)

            object = nil
            assert_nothing_raised do
                object = result.to_type
            end

            assert(object, "Could not create type")

            retrieve.each do |property|
                assert(object.should(property), "Did not retrieve %s" % property)
            end

            ignore.each do |property|
                assert(! object.should(property), "Incorrectly retrieved %s" % property)
            end
        end
    end

    def test_describe_directory
        # Make a file to describe
        file = tempfile()

        server = nil

        assert_nothing_raised do
            server = Puppet::Network::Handler.resource.new()
        end

        [   [nil],
            [[:ensure, :checksum, :mode], []],
            [[], [:checksum]],
            [[:ensure, :checksum], [:mode]]
        ].each do |ary|
            retrieve = ary[0] || []
            ignore = ary[1] || []

            Dir.mkdir(file)

            result = nil
            assert_nothing_raised do
                result = server.describe("file", file, *ary)
            end

            assert(result, "Could not retrieve file information")

            assert_instance_of(Puppet::TransObject, result)

            # And remove the file, so we can verify it gets recreated
            Dir.rmdir(file)

            object = nil
            assert_nothing_raised do
                object = result.to_type
            end

            catalog = mk_catalog(object)

            assert(object, "Could not create type")

            retrieve.each do |property|
                assert(object.should(property), "Did not retrieve %s" % property)
            end

            ignore.each do |property|
                assert(! object.should(property), "Incorrectly retrieved %s" % property)
            end
        end
    end

    def test_describe_alltypes
        # Systems get pretty retarded, so I'm going to set the path to some fake
        # data for ports
        #Puppet::Type::ParsedType::Port.path = File.join(basedir,
        #    "test/data/types/ports/1")
        #Puppet.err Puppet::Type::ParsedType::Port.path
        server = nil
        assert_nothing_raised do
            server = Puppet::Network::Handler.resource.new()
        end

        require 'etc'

        # Make the example schedules, for testing
        Puppet::Type.type(:schedule).mkdefaultschedules

        Puppet::Type.eachtype do |type|
            unless type.respond_to? :instances
                Puppet.warning "%s does not respond to :instances" % type.name
                next
            end
            next unless type.name == :package
            Puppet.info "Describing each %s" % type.name

            # First do a listing from the server
            bucket = nil
            assert_nothing_raised {
                bucket = server.list(type.name)
            }

            count = 0
            described = {}
            bucket.each do |obj|
                assert_instance_of(Puppet::TransObject, obj)
                break if count > 5
                described[obj.name] = server.describe(obj.type, obj.name)
                count += 1
            end

            verify_described(type, described)

            count = 0
            described = {}
            Puppet.info "listing again"
            type.instances.each do |obj|
                assert_instance_of(type, obj)

                break if count > 5
                trans = nil
                assert_nothing_raised do
                    described[obj.name] = server.describe(type.name, obj.name)
                end

                count += 1
            end

            if described.empty?
                Puppet.notice "Got no example objects for %s" % type.name
            end

            # We separate these, in case the list operation creates objects
            verify_described(type, described)
        end
    end

    def test_apply
        server = nil
        assert_nothing_raised do
            server = Puppet::Network::Handler.resource.new(:Local => false)
        end

        file = tempfile()
        str = "yayness\n"

        File.open(file, "w") { |f| f.print str }

        filetrans = nil
        assert_nothing_raised {
            filetrans = server.describe("file", file)
        }

        bucket = Puppet::TransBucket.new
        bucket.type = "file"
        bucket.name = "test"
        bucket.push filetrans

        oldbucket = bucket.dup
        File.unlink(file)
        assert_nothing_raised {
            server.apply(bucket)
        }

        assert(FileTest.exists?(file), "File did not get recreated")

        # Now try it as a "nonlocal" server
        server.local = false
        yaml = nil
        assert_nothing_raised {
            yaml = Base64.encode64(YAML::dump(bucket))
        }

        File.unlink(file)

        if Base64.decode64(yaml) =~ /(.{20}Loglevel.{20})/
            Puppet.warning "YAML is broken on this machine"
            return
        end
        # puts Base64.decode64(yaml)
        objects = nil
        assert_nothing_raised("Could not reload yaml") {
            YAML::load(Base64.decode64(yaml))
        }

        # The server is supposed to accept yaml and execute it.
        assert_nothing_raised {
            server.apply(yaml)
        }
        assert(FileTest.exists?(file), "File did not get recreated from YAML")
    end
end

