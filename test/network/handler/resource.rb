#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'base64'
require 'cgi'

class TestResourceServer < Test::Unit::TestCase
    include PuppetTest::ServerTest

    def verify_described(type, described)
        described.each do |name, trans|
            type.clear
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
        type.clear
    end

    def test_describe_file
        # Make a file to describe
        file = tempfile()
        str = "yayness\n"

        server = nil

        assert_nothing_raised do
            server = Puppet::Network::Handler.resource.new()
        end

        # The first run we create the file on the copy, the second run
        # the file is already there so the object should be in sync
        2.times do |i|
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

                # Now we have to clear, so that the server's object gets removed
                Puppet::Type.type(:file).clear

                # And remove the file, so we can verify it gets recreated
                if i == 0
                    File.unlink(file)
                end

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

                if i == 0
                    assert_events([:file_created], object)
                else
                    assert_nothing_raised {
                        object.retrieve
                    }
                    assert(object.insync?, "Object was not in sync")
                end

                assert(FileTest.exists?(file), "File did not get recreated")

                if i == 0
                if object.should(:content)
                    assert_equal(str, File.read(file), "File contents are not the same")
                else
                    assert_equal("", File.read(file), "File content was incorrectly made")
                end
                end
                if FileTest.exists? file
                    File.unlink(file)
                end
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

            # Now we have to clear, so that the server's object gets removed
            Puppet::Type.type(:file).clear

            # And remove the file, so we can verify it gets recreated
            Dir.rmdir(file)

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

            #assert_apply(object)
            assert_events([:directory_created], object)
            assert(FileTest.directory?(file), "Directory did not get recreated")
            Dir.rmdir(file)
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
            unless type.respond_to? :list
                Puppet.warning "%s does not respond to :list" % type.name
                next
            end
            next unless type.name == :package
            Puppet.info "Describing each %s" % type.name

            # First do a listing from the server
            bucket = nil
            assert_nothing_raised {
                bucket = server.list(type.name)
            }

            #type.clear

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
            type.list.each do |obj|
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
            server = Puppet::Network::Handler.resource.new()
        end

        file = tempfile()
        str = "yayness\n"

        File.open(file, "w") { |f| f.print str }

        filetrans = nil
        assert_nothing_raised {
            filetrans = server.describe("file", file)
        }

        Puppet::Type.type(:file).clear

        bucket = Puppet::TransBucket.new
        bucket.type = "file"
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

        Puppet::Type.type(:file).clear
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

# $Id$
