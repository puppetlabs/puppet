#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppettest'

# Test the different features of the main puppet module
class TestPuppetModule < Test::Unit::TestCase
	include PuppetTest
    include SignalObserver
    
    def mkfakeclient
        Class.new(Puppet::Client) do
            def initialize
            end

            def runnow
                Puppet.info "fake client has run"
            end
        end
    end

    def mktestclass
        Class.new do
            def initialize(file)
                @file = file
            end

            def started?
                FileTest.exists?(@file)
            end

            def start
                File.open(@file, "w") do |f| f.puts "" end
            end

            def shutdown
                File.unlink(@file)
            end
        end
    end

    # Make sure that services get correctly started and stopped
    def test_servicehandling
        file = tempfile()
        testclass = mktestclass()

        obj = testclass.new(file)

        assert_nothing_raised {
            Puppet.newservice(obj)
        }

        assert_nothing_raised {
            Puppet.start(false)
        }

        # Give it a sec or so
        sleep 0.3

        assert(obj.started?, "Object was not started")

        assert_nothing_raised {
            Puppet.shutdown(false)
        }
        # Give it a sec or so
        sleep 0.3

        assert(!obj.started?, "Object is still running")

    end

    def test_path
        oldpath = ENV["PATH"]
        cleanup do
            ENV["PATH"] = oldpath
        end
        newpath = oldpath + ":" + "/something/else"
        assert_nothing_raised do
            Puppet[:path] = newpath
        end

        assert_equal(newpath, ENV["PATH"])
    end

    def test_libdir
        oldlibs = $:.dup
        cleanup do
            $:.each do |dir|
                unless oldlibs.include?(dir)
                    $:.delete(dir)
                end
            end
        end
        one = tempfile()
        two = tempfile()
        Dir.mkdir(one)
        Dir.mkdir(two)

        # Make sure setting the libdir gets the dir added to $:
        assert_nothing_raised do
            Puppet[:libdir] = one
        end

        assert($:.include?(one), "libdir was not added")

        # Now change it, make sure it gets added and the old one gets
        # removed
        assert_nothing_raised do
            Puppet[:libdir] = two
        end

        assert($:.include?(two), "libdir was not added")
        assert(! $:.include?(one), "old libdir was not removed")
    end
end

# $Id$
