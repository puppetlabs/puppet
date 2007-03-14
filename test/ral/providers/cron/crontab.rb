#!/usr/bin/env ruby

$:.unshift("../../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'mocha'
require 'puppettest/fileparsing'
require 'puppet/type/cron'
require 'puppet/provider/cron/crontab'

class TestCronParsedProvider < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::FileParsing

    def setup
        super
        @provider = Puppet::Type.type(:cron).provider(:crontab)

        @oldfiletype = @provider.filetype
    end

    def teardown
        Puppet::Util::FileType.filetype(:ram).clear
        @provider.filetype = @oldfiletype
        @provider.clear
        super
    end

    def test_parse_record
        fields = [:month, :weekday, :monthday, :hour, :command, :minute]
        {
            "* * * * * /bin/echo" => {:command => "/bin/echo"},
            "10 * * * * /bin/echo test" => {:minute => "10",
                :command => "/bin/echo test"}
        }.each do |line, should|
            result = nil
            assert_nothing_raised("Could not parse %s" % line.inspect) do
                result = @provider.parse_line(line)
            end
            should[:record_type] = :crontab
            fields.each do |field|
                if should[field]
                    assert_equal(should[field], result[field],
                        "Did not parse %s in %s correctly" % [field, line.inspect])
                else
                    assert_equal(:absent, result[field],
                        "Did not set %s absent in %s" % [field, line.inspect])
                end
            end
        end
    end

    def test_prefetch_hook
        count = 0
        env = Proc.new do
            count += 1
            {:record_type => :environment, :line => "env%s=val" % count}
        end
        comment = Proc.new do |name|
            count += 1
            hash = {:record_type => :comment, :line => "comment %s" % count}
            if name
                hash[:name] = name
            end
            hash
        end
        record = Proc.new do
            count += 1
            {:record_type => :crontab, :command => "command%s" % count}
        end

        result = nil
        args = []
        # First try it with all three
        args << comm = comment.call(false)
        args << name = comment.call(true)
        args << var = env.call()
        args << line = record.call
        args << sec = comment.call(false)
        assert_nothing_raised do
            result = @provider.prefetch_hook(args)
        end
        assert_equal([comm, line, sec], result,
            "Did not remove name and var records")

        assert_equal(name[:name], line[:name],
            "did not set name in hook")
        assert_equal([var[:line]], line[:environment],
            "did not set env")

        # Now try it with an env, a name, and a record
        args.clear
        args << var = env.call()
        args << name = comment.call(true)
        args << line = record.call
        assert_nothing_raised do
            result = @provider.prefetch_hook(args)
        end

        assert_equal([var, line], result,
            "Removed var record")
        assert_equal(name[:name], line[:name],
            "did not set name in hook")
        assert_nil(line[:environment], "incorrectly set env")

        # try it with a comment, an env, and a record
        args.clear
        args << comm = comment.call(false)
        args << var = env.call()
        args << line = record.call
        assert_nothing_raised do
            result = @provider.prefetch_hook(args)
        end
        assert_equal([comm, var, line], result,
            "Removed var record")
        assert_nil(line[:name], "name got set somehow")
        assert_nil(line[:environment], "env got set somehow")

        # Try it with multiple records
        args = []
        should = []
        args << startcom = comment.call(false)
        should << startcom
        args << startenv = env.call
        should << startenv

        args << name1 = comment.call(true)
        args << env1s = env.call
        args << env1m = env.call
        args << line1 = record.call
        should << line1

        args << midcom = comment.call(false)
        args << midenv = env.call
        should << midcom << midenv

        args << name2 = comment.call(true)
        args << env2s = env.call
        args << env2m = env.call
        args << line2 = record.call
        should << line2

        args << endcom = comment.call(false)
        args << endenv = env.call
        should << endcom << endenv

        assert_nothing_raised do
            result = @provider.prefetch_hook(args)
        end
        assert_equal(should, result,
            "Did not handle records correctly")

        assert_equal(line1[:name], line1[:name], "incorrectly set first name")
        assert_equal(line1[:environment], line1[:environment],
            "incorrectly set first env")

        assert_equal(line2[:name], line2[:name], "incorrectly set second name")
        assert_equal(line2[:environment], line2[:environment],
            "incorrectly set second env")
    end

    # A simple test to see if we can load the cron from disk.
    def test_load
        setme()
        records = nil
        assert_nothing_raised {
            records = @provider.retrieve(@me)
        }
        assert_instance_of(Array, records, "did not get correct response")
    end
end

# $Id$
