#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../lib/puppettest')

require 'puppettest'
require 'mocha'
require 'puppettest/fileparsing'

class TestCronParsedProvider < Test::Unit::TestCase
  include PuppetTest
  include PuppetTest::FileParsing


  FIELDS = {
    :crontab => %w{command minute hour month monthday weekday}.collect { |o| o.intern },
    :freebsd_special => %w{special command}.collect { |o| o.intern },
    :environment => [:line],
    :blank => [:line],
    :comment => [:line],
  }

  # These are potentially multi-line records; there's no one-to-one map, but they model
  # a full cron job.  These tests assume individual record types will always be correctly
  # parsed, so all they
  def sample_crons
    @sample_crons ||= YAML.load(File.read(File.join(@crondir, "crontab_collections.yaml")))
  end

  # These are simple lines that can appear in the files; there is a one to one
  # mapping between records and lines.  We have plenty of redundancy here because
  # we use these records to build up our complex, multi-line cron jobs below.
  def sample_records
    @sample_records ||= YAML.load(File.read(File.join(@crondir, "crontab_sample_records.yaml")))
  end

  def setup
    super
    @type = Puppet::Type.type(:cron)
    @provider = @type.provider(:crontab)
    @provider.initvars
    @crondir = datadir(File.join(%w{providers cron}))

    @oldfiletype = @provider.filetype
  end

  def teardown
    Puppet::Util::FileType.filetype(:ram).clear
    @provider.clear
    super
  end

  # Make sure a cron job matches up.  Any non-passed fields are considered absent.
  def assert_cron_equal(msg, cron, options)
    assert_instance_of(@provider, cron, "not an instance of provider in #{msg}")
    options.each do |param, value|
      assert_equal(value, cron.send(param), "#{param} was not equal in #{msg}")
    end
    %w{command environment minute hour month monthday weekday}.each do |var|
      assert_equal(:absent, cron.send(var), "#{var} was not parsed absent in #{msg}") unless options.include?(var.intern)
    end
  end

  # Make sure a cron record matches.  This only works for crontab records.
  def assert_record_equal(msg, record, options)
    raise ArgumentError, "You must pass the required record type" unless options.include?(:record_type)
    assert_instance_of(Hash, record, "not an instance of a hash in #{msg}")
    options.each do |param, value|
      assert_equal(value, record[param], "#{param} was not equal in #{msg}")
    end
    FIELDS[record[:record_type]].each do |var|
      assert_equal(:absent, record[var], "#{var} was not parsed absent in #{msg}") unless options.include?(var)
    end
  end

  def assert_header(file)
    header = []
    file.gsub! /^(# HEADER: .+$)\n/ do
      header << $1
      ''
    end
    assert_equal(4, header.length, "Did not get four header lines")
  end

  # This handles parsing every possible iteration of cron records.  Note that this is only
  # single-line stuff and doesn't include multi-line values (e.g., with names and/or envs).
  # Those have separate tests.
  def test_parse_line
    # First just do each sample record one by one
    sample_records.each do |name, options|
      result = nil
      assert_nothing_raised("Could not parse #{name}: '#{options[:text]}'") do
        result = @provider.parse_line(options[:text])
      end
      assert_record_equal("record for #{name}", result, options[:record])
    end

    # Then do them all at once.
    records = []
    text = ""
    # Sort sample_records so that the :empty entry does not come last
    # (if it does, the test will fail because the empty last line will
    # be ignored)
    sample_records.sort { |a, b| a.first.to_s <=> b.first.to_s }.each do |name, options|
      records << options[:record]
      text += options[:text] + "\n"
    end

    result = nil
    assert_nothing_raised("Could not match all records in one file") do
      result = @provider.parse(text)
    end

    records.zip(result).each do |should, record|
      assert_record_equal("record for #{should.inspect} in full match", record, should)
    end
  end

  # Here we test that each record generates to the correct text.
  def test_generate_line
    # First just do each sample record one by one
    sample_records.each do |name, options|
      result = nil
      assert_nothing_raised("Could not generate #{name}: '#{options[:record]}'") do
        result = @provider.to_line(options[:record])
      end
      assert_equal(options[:text], result, "Did not generate correct text for #{name}")
    end

    # Then do them all at once.
    records = []
    text = ""
    sample_records.each do |name, options|
      records << options[:record]
      text += options[:text] + "\n"
    end

    result = nil
    assert_nothing_raised("Could not match all records in one file") do
      result = @provider.to_file(records)
    end

    assert_header(result)

    assert_equal(text, result, "Did not generate correct full crontab")
  end

  # Test cronjobs that are made up from multiple records.
  def test_multi_line_cronjobs
    fulltext = ""
    all_records = []
    sample_crons.each do |name, record_names|
      records = record_names.collect do |record_name|
        unless record = sample_records[record_name]
          raise "Could not find sample record #{record_name}"
        end
        record
      end

      text = records.collect { |r| r[:text] }.join("\n") + "\n"
      record_list = records.collect { |r| r[:record] }

      # Add it to our full collection
      all_records += record_list
      fulltext += text

      # First make sure we generate each one correctly
      result = nil
      assert_nothing_raised("Could not generate multi-line cronjob #{name}") do
        result = @provider.to_file(record_list)
      end
      assert_header(result)
      assert_equal(text, result, "Did not generate correct text for multi-line cronjob #{name}")

      # Now make sure we parse each one correctly
      assert_nothing_raised("Could not parse multi-line cronjob #{name}") do
        result = @provider.parse(text)
      end
      record_list.zip(result).each do |should, record|
        assert_record_equal("multiline cronjob #{name}", record, should)
      end
    end

    # Make sure we can generate it all correctly
    result = nil
    assert_nothing_raised("Could not generate all multi-line cronjobs") do
      result = @provider.to_file(all_records)
    end
    assert_header(result)
    assert_equal(fulltext, result, "Did not generate correct text for all multi-line cronjobs")

    # Now make sure we parse them all correctly
    assert_nothing_raised("Could not parse multi-line cronjobs") do
      result = @provider.parse(fulltext)
    end
    all_records.zip(result).each do |should, record|
      assert_record_equal("multiline cronjob %s", record, should)
    end
  end

  # Take our sample files, and make sure we can entirely parse them,
  # then that we can generate them again and we get the same data.
  def test_parse_and_generate_sample_files
    @provider.stubs(:filetype).returns(Puppet::Util::FileType.filetype(:ram))
    crondir = datadir(File.join(%w{providers cron}))
    files = Dir.glob("#{crondir}/crontab.*")

    setme
    @provider.default_target = @me
    target = @provider.target_object(@me)
    files.each do |file|
      str = args = nil
      assert_nothing_raised("could not load #{file}") do
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
      assert_nothing_raised("could not parse #{file}") do
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

              assert_equal(
        should, is,
        
          "Did not parse #{file} correctly")
      end

      assert_nothing_raised("could not generate #{file}") do
        @provider.flush_target(@me)
      end

      assert_equal(str, target.read, "#{file} changed")
      @provider.clear
    end
  end

  # A simple test to see if we can load the cron from disk.
  def test_load
    setme
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
    setme

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


          assert_equal(
        "# Puppet Name: #{name}\n30 * * * * date > /dev/null", str,
        
      "Cron did not generate correctly")
  end

  # Test that comments are correctly retained
  def test_retain_comments
    str = "# this is a comment\n#and another comment\n"
    user = "fakeuser"
    records = nil
    @provider.stubs(:filetype).returns(Puppet::Util::FileType.filetype(:ram))
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
    @provider.stubs(:filetype).returns(Puppet::Util::FileType.filetype(:ram))
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
      assert_equal(v, is[p], "did not parse #{p} correctly")
    end
  end

  # Make sure we can create a cron in an empty tab.
  # LAK:FIXME This actually modifies the user's crontab,
  # which is pretty heinous.
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
    assert(created.detect { |r| r[:command] == "/do/something" }, "Did not create cron tab")
  end

  # Make sure we correctly bidirectionally parse things.
  def test_records_and_strings
    @provider.stubs(:filetype).returns(Puppet::Util::FileType.filetype(:ram))
    setme

    target = @provider.target_object(@me)

    [
      "   FOO=var",
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

            assert_equal(
        str, target.read,
        
        "Did not write correctly")
      assert_nothing_raised("Could not prefetch with #{str.inspect}") do
        @provider.prefetch
      end
      assert_nothing_raised("Could not flush with #{str.inspect}") do
        @provider.flush_target(@me)
      end


            assert_equal(
        str, target.read,
        
        "Changed in read/write")

      @provider.clear
    end
  end

  # Test that a specified cron job will be matched against an existing job
  # with no name, as long as all fields match
  def test_matchcron
    mecron = "0,30 * * * * date

    * * * * * funtest
    # a comment
    0,30 * * 1 * date
    "

    youcron = "0,30 * * * * date

    * * * * * yaytest
    # a comment
    0,30 * * 1 * fooness
    "
    setme
    @provider.stubs(:filetype).returns(Puppet::Util::FileType.filetype(:ram))
    you = "you"

    # Write the same tab to multiple targets
    @provider.target_object(@me).write(mecron.gsub(/^\s+/, ''))
    @provider.target_object(you).write(youcron.gsub(/^\s+/, ''))

    # Now make some crons that should match
    matchers = [

            @type.new(
                
        :name => "yaycron",
        :minute => [0, 30],
        :command => "date",
        
        :user => @me
      ),

            @type.new(
                
        :name => "youtest",
        :command => "yaytest",
        
        :user => you
      )
    ]

    nonmatchers = [

            @type.new(
                
        :name => "footest",
        :minute => [0, 30],
        :hour => 1,
        :command => "fooness",
        
        :user => @me # wrong target
      ),

            @type.new(
                
        :name => "funtest2",
        :command => "funtest",
        
        :user => you # wrong target for this cron
      )
    ]

    # Create another cron so we prefetch two of them
    @type.new(:name => "testing", :minute => 30, :command => "whatever", :user => "you")

    assert_nothing_raised("Could not prefetch cron") do
      @provider.prefetch([matchers, nonmatchers].flatten.inject({}) { |crons, cron| crons[cron.name] = cron; crons })
    end

    matchers.each do |cron|
      assert_equal(:present, cron.provider.ensure, "Cron #{cron.name} was not matched")
      if value = cron.value(:minute) and value == "*"
        value = :absent
      end
      assert_equal(value, cron.provider.minute, "Minutes were not retrieved, so cron was not matched")
      assert_equal(cron.value(:target), cron.provider.target, "Cron #{cron.name} was matched from the wrong target")
    end

    nonmatchers.each do |cron|
      assert_equal(:absent, cron.provider.ensure, "Cron #{cron.name} was incorrectly matched")
    end
  end

  def test_data
    setme
    @provider.stubs(:filetype).returns(Puppet::Util::FileType.filetype(:ram))
    target = @provider.target_object(@me)
    fakedata("data/providers/cron/examples").each do |file|
      text = File.read(file)
      target.write(text)

      assert_nothing_raised("Could not parse #{file}") do
        @provider.prefetch
      end
      # mark the provider modified
      @provider.modified(@me)

      # and zero the text
      target.write("")

      result = nil
      assert_nothing_raised("Could not generate #{file}") do
        @provider.flush_target(@me)
      end

      # Ignore whitespace differences, since those don't affect function.
      modtext = text.gsub(/[ \t]+/, " ")
      modtarget = target.read.gsub(/[ \t]+/, " ")
      assert_equal(modtext, modtarget, "File was not rewritten the same")

      @provider.clear
    end
  end

  # Match freebsd's annoying @daily stuff.
  def test_match_freebsd_special
    @provider.stubs(:filetype).returns(Puppet::Util::FileType.filetype(:ram))
    setme

    target = @provider.target_object(@me)

    [
      "@daily /some/command",
      "@daily /some/command more"
    ].each do |str|
      @provider.initvars
      str += "\n"
      target.write(str)
      assert_nothing_raised("Could not prefetch with #{str.inspect}") do
        @provider.prefetch
      end
      records = @provider.send(:instance_variable_get, "@records")
      records.each do |r|

              assert_equal(
        :freebsd_special, r[:record_type],
        
          "Did not create lines as freebsd lines")
      end
      assert_nothing_raised("Could not flush with #{str.inspect}") do
        @provider.flush_target(@me)
      end


            assert_equal(
        str, target.read,
        
        "Changed in read/write")

      @provider.clear
    end
  end

  # #707
  def test_write_freebsd_special
    assert_equal(@provider.to_line(:record_type => :crontab, :ensure => :present, :special => "reboot", :command => "/bin/echo something"), "@reboot /bin/echo something")
  end

  def test_prefetch
    cron = @type.new :command => "/bin/echo yay", :name => "test", :hour => 4

    assert_nothing_raised("Could not prefetch cron") do
      cron.provider.class.prefetch("test" => cron)
    end
  end

  # Testing #669.
  def test_environment_settings
    @provider.stubs(:filetype).returns(Puppet::Util::FileType.filetype(:ram))
    setme

    target = @provider.target_object(@me)

    # First with no env settings
    resource = @type.new :command => "/bin/echo yay", :name => "test", :hour => 4
    cron = resource.provider

    cron.ensure = :present
    cron.command = "/bin/echo yay"
    cron.hour = %w{4}
    cron.flush

    result = target.read
    assert_equal("# Puppet Name: test\n* 4 * * * /bin/echo yay\n", result, "Did not write cron out correctly")

    # Now set the env
    cron.environment = "TEST=foo"
    cron.flush

    result = target.read
    assert_equal("# Puppet Name: test\nTEST=foo\n* 4 * * * /bin/echo yay\n", result, "Did not write out environment setting")

    # Modify it
    cron.environment = ["TEST=foo", "BLAH=yay"]
    cron.flush

    result = target.read
    assert_equal("# Puppet Name: test\nTEST=foo\nBLAH=yay\n* 4 * * * /bin/echo yay\n", result, "Did not write out environment setting")

    # And remove it
    cron.environment = :absent
    cron.flush

    result = target.read
    assert_equal("# Puppet Name: test\n* 4 * * * /bin/echo yay\n", result, "Did not write out environment setting")
  end

  # Testing #1216
  def test_strange_lines
    @provider.stubs(:filetype).returns(Puppet::Util::FileType.filetype(:ram))
    text = " 5 \t\t 1,2 * 1 0 /bin/echo funtest"

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
      assert_equal(v, is[p], "did not parse #{p} correctly")
    end
  end
end
