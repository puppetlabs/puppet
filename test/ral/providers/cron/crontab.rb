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
        @type = Puppet::Type.type(:cron)
        @provider = @type.provider(:crontab)
        @provider.initvars

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
            "10 * * * * /bin/echo test" => {:minute => ["10"],
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

    def test_parse_and_generate
        @provider.filetype = :ram
        crondir = datadir(File.join(%w{providers cron}))
        files = Dir.glob("%s/crontab.*" % crondir)

        setme
        @provider.default_target = @me
        target = @provider.target_object(@me)
        files.each do |file|
            str = args = nil
            assert_nothing_raised("could not load %s" % file) do
                str, args = YAML.load(File.read(file))
            end
            
            # Stupid old yaml
            args.each do |hash|
                hash.each do |param, value|
                    if param.is_a?(String) and param =~ /^:/
                        hash.delete(param)
                        param = param.sub(/^:/,'').intern
                        hash[param] = value
                    end

                    if value.is_a?(String) and value =~ /^:/
                        value = value.sub(/^:/,'').intern
                        hash[param] = value
                    end
                end
            end
            target.write(str)
            assert_nothing_raised("could not parse %s" % file) do
                @provider.prefetch
            end
            records = @provider.send(:instance_variable_get, "@records")

            args.zip(records) do |should, sis|
                # Make the values a bit more equal.
                should[:target] = @me
                should[:ensure] = :present
                #should[:environment] ||= []
                should[:on_disk] = true
                is = sis.dup
                sis.dup.each do |p,v|
                    is.delete(p) if v == :absent
                end
                assert_equal(should, is,
                    "Did not parse %s correctly" % file)
            end

            assert_nothing_raised("could not generate %s" % file) do
                @provider.flush_target(@me)
            end

            assert_equal(str, target.read, "%s changed" % file)
            @provider.clear
        end
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

    # Test that a cron job turns out as expected, by creating one and generating
    # it directly
    def test_simple_to_cron
        # make the cron
        setme()

        name = "yaytest"
        args = {:name => name,
            :command => "date > /dev/null",
            :minute => "30",
            :user => @me,
            :record_type => :crontab
        }
        # generate the text
        str = nil
        assert_nothing_raised {
            str = @provider.to_line(args)
        }

        assert_equal("# Puppet Name: #{name}\n30 * * * * date > /dev/null", str,
            "Cron did not generate correctly")
    end
    
    # Test that comments are correctly retained
    def test_retain_comments
        str = "# this is a comment\n#and another comment\n"
        user = "fakeuser"
        records = nil
        target = @provider.filetype = :ram
        target = @provider.target_object(user)
        target.write(str)
        assert_nothing_raised {
            @provider.prefetch
        }

        assert_nothing_raised {
            newstr = @provider.flush_target(user)
            assert(target.read.include?(str), "Comments were lost")
        }
    end

    def test_simpleparsing
        @provider.filetype = :ram
        text = "5 1,2 * 1 0 /bin/echo funtest"

        records = nil
        assert_nothing_raised {
            records = @provider.parse(text)
        }

        should = {
            :minute => %w{5},
            :hour => %w{1 2},
            :monthday => :absent,
            :month => %w{1},
            :weekday => %w{0},
            :command => "/bin/echo funtest"
        }

        is = records.shift
        assert(is, "Did not get record")

        should.each do |p, v|
            assert_equal(v, is[p], "did not parse %s correctly" % p)
        end
    end

    # Make sure we can create a cron in an empty tab
    def test_mkcron_if_empty
        setme
        @provider.filetype = @oldfiletype

        records = @provider.retrieve(@me)

        target = @provider.target_object(@me)

        cleanup do
            if records.length == 0
                target.remove
            else
                target.write(@provider.to_file(records))
            end
        end

        # Now get rid of it
        assert_nothing_raised("Could not remove cron tab") do
            target.remove
        end

        @provider.flush :target => @me, :command => "/do/something",
            :record_type => :crontab
        created = @provider.retrieve(@me)
        assert(created.detect { |r| r[:command] == "/do/something" },
            "Did not create cron tab")
    end

    # Make sure we correctly bidirectionally parse things.
    def test_records_and_strings
        @provider.filetype = :ram
        setme

        target = @provider.target_object(@me)
        
        [
            "* * * * * /some/command",
            "0,30 * * * * /some/command",
            "0-30 * * * * /some/command",
            "# Puppet Name: name\n0-30 * * * * /some/command",
            "# Puppet Name: name\nVAR=VALUE\n0-30 * * * * /some/command",
            "# Puppet Name: name\nVAR=VALUE\nC=D\n0-30 * * * * /some/command",
            "0 * * * * /some/command"
        ].each do |str|
            @provider.initvars
            str += "\n"
            target.write(str)
            assert_equal(str, target.read,
                "Did not write correctly")
            assert_nothing_raised("Could not prefetch with %s" % str.inspect) do
                @provider.prefetch
            end
            assert_nothing_raised("Could not flush with %s" % str.inspect) do
                @provider.flush_target(@me)
            end

            assert_equal(str, target.read,
                "Changed in read/write")

            @provider.clear
        end
    end

    # Test that a specified cron job will be matched against an existing job
    # with no name, as long as all fields match
    def test_matchcron
        str = "0,30 * * * * date\n"
        setme
        @provider.filetype = :ram

        cron = nil
        assert_nothing_raised {
            cron = @type.create(
                :name => "yaycron",
                :minute => [0, 30],
                :command => "date",
                :user => @me
            )
        }

        hash = @provider.parse_line(str)
        hash[:user] = @me

        instance = @provider.match(hash, "yaycron" => cron)
        assert(instance, "did not match cron")
        assert_equal(cron, instance,
            "Did not match cron job")
    end

    def test_data
        setme
        @provider.filetype = :ram
        target = @provider.target_object(@me)
        fakedata("data/providers/cron/examples").each do |file|
            text = File.read(file)
            target.write(text)

            assert_nothing_raised("Could not parse %s" % file) do
                @provider.prefetch
            end
            # mark the provider modified
            @provider.modified(@me)

            # and zero the text
            target.write("")

            result = nil
            assert_nothing_raised("Could not generate %s" % file) do
                @provider.flush_target(@me)
            end

            # Ignore whitespace differences, since those don't affect function.
            modtext = text.gsub(/[ \t]+/, " ")
            modtarget = target.read.gsub(/[ \t]+/, " ")
            assert_equal(modtext, modtarget,
                "File was not rewritten the same")

            @provider.clear
        end
    end

    # Match freebsd's annoying @daily stuff.
    def test_match_freebsd_special
        @provider.filetype = :ram
        setme

        target = @provider.target_object(@me)
        
        [
            "@daily /some/command",
            "@daily /some/command more"
        ].each do |str|
            @provider.initvars
            str += "\n"
            target.write(str)
            assert_equal(str, target.read,
                "Did not write correctly")
            assert_nothing_raised("Could not prefetch with %s" % str.inspect) do
                @provider.prefetch
            end
            records = @provider.send(:instance_variable_get, "@records")
            records.each do |r|
                assert_equal(:freebsd_special, r[:record_type],
                    "Did not create lines as freebsd lines")
            end
            assert_nothing_raised("Could not flush with %s" % str.inspect) do
                @provider.flush_target(@me)
            end

            assert_equal(str, target.read,
                "Changed in read/write")

            @provider.clear
        end
    end

    def test_prefetch
        cron = @type.create :command => "/bin/echo yay", :name => "test", :hour => 4

        assert_nothing_raised("Could not prefetch cron") do
            cron.provider.class.prefetch("test" => cron)
        end
    end

    # Testing #669.
    def test_environment_settings
        @provider.filetype = :ram
        setme

        target = @provider.target_object(@me)

        # First with no env settings
        cron = @type.create :command => "/bin/echo yay", :name => "test", :hour => 4

        assert_apply(cron)

        props = cron.retrieve.inject({}) { |hash, ary| hash[ary[0]] = ary[1]; hash }

        # Now set the env
        cron[:environment] = "TEST=foo"
        assert_apply(cron)

        props = cron.retrieve.inject({}) { |hash, ary| hash[ary[0]] = ary[1]; hash }
        assert(target.read.include?("TEST=foo"), "Did not get environment setting")
        #assert_equal(["TEST=foo"], props[:environment], "Did not get environment setting")

        # Modify it
        cron[:environment] = ["TEST=foo", "BLAH=yay"]
        assert_apply(cron)

        props = cron.retrieve.inject({}) { |hash, ary| hash[ary[0]] = ary[1]; hash }
        assert(target.read.include?("TEST=foo"), "Did not keep environment setting")
        assert(target.read.include?("BLAH=yay"), "Did not get second environment setting")
        #assert_equal(["TEST=foo", "BLAH=yay"], props[:environment], "Did not modify environment setting")

        # And remove it
        cron[:environment] = :absent
        assert_apply(cron)

        props = cron.retrieve.inject({}) { |hash, ary| hash[ary[0]] = ary[1]; hash }
        assert(! target.read.include?("TEST=foo"), "Did not remove environment setting")
        assert(! target.read.include?("BLAH=yay"), "Did not remove second environment setting")
        #assert_nil(props[:environment], "Did not modify environment setting")

    end
end

# $Id$
