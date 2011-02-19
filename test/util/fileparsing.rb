#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppettest'
require 'puppettest/fileparsing'
require 'puppet'
require 'puppet/util/fileparsing'

class TestUtilFileParsing < Test::Unit::TestCase
  include PuppetTest
  include PuppetTest::FileParsing

  class FParser
    include Puppet::Util::FileParsing
  end

  def setup
    super
    @parser = FParser.new
  end

  def test_lines
    assert_equal("\n", @parser.line_separator, "Default separator was incorrect")

    {"\n" => ["one two\nthree four", "one two\nthree four\n"],
    "\t" => ["one two\tthree four", "one two\tthree four\t"],
    }.each do |sep, tests|
      assert_nothing_raised do
        @parser.line_separator = sep
      end

        assert_equal(
          sep, @parser.line_separator,

          "Did not set separator")

      tests.each do |test|
        assert_equal(["one two", "three four"], @parser.lines(test), "Incorrectly parsed #{test.inspect}")
      end
    end
  end

  # Make sure parse calls the appropriate methods or errors out
  def test_parse
    @parser.meta_def(:parse_line) do |line|
      line.split(/\s+/)
    end

    text = "one line\ntwo line"
    should = [%w{one line}, %w{two line}]
    ret = nil
    assert_nothing_raised do
      ret = @parser.parse(text)
    end

    assert_equal(should, ret)
  end

  # Make sure we correctly handle different kinds of text lines.
  def test_text_line
    comment = "# this is a comment"

    # Make sure it fails if no regex is passed
    assert_raise(ArgumentError) do
      @parser.text_line :comment
    end

    # define a text matching comment record
    assert_nothing_raised do
      @parser.text_line :comment, :match => /^#/
    end

    # Make sure it matches
    assert_nothing_raised do

      assert_equal(
        {:record_type => :comment, :line => comment},

        @parser.parse_line(comment))
    end

    # But not something else
    assert_nothing_raised do
      assert_nil(@parser.parse_line("some other text"))
    end

    # Now define another type and make sure we get the right one back
    assert_nothing_raised do
      @parser.text_line :blank, :match => /^\s*$/
    end

    # The comment should still match
    assert_nothing_raised do

      assert_equal(
        {:record_type => :comment, :line => comment},

        @parser.parse_line(comment))
    end

    # As should our new line type
    assert_nothing_raised do

      assert_equal(
        {:record_type => :blank, :line => ""},

        @parser.parse_line(""))
    end

  end

  def test_parse_line
    Puppet[:trace] = false

    comment = "# this is a comment"

    # Make sure it fails if we don't have any record types defined
    assert_raise(Puppet::DevError) do
      @parser.parse_line(comment)
    end

    # Now define a text matching comment record
    assert_nothing_raised do
      @parser.text_line :comment, :match => /^#/
    end

    # And make sure we can't define another one with the same name
    assert_raise(ArgumentError) do
      @parser.text_line :comment, :match => /^"/
    end

    result = nil
    assert_nothing_raised("Did not parse text line") do
      result = @parser.parse_line comment
    end

    assert_equal({:record_type => :comment, :line => comment}, result)

    # Make sure we just return nil on unmatched lines.
    assert_nothing_raised("Did not parse text line") do
      result = @parser.parse_line "No match for this"
    end

    assert_nil(result, "Somehow matched an empty line")

    # Now define another type of comment, and make sure both types get
    # correctly returned as comments
    assert_nothing_raised do
      @parser.text_line :comment2, :match => /^"/
    end

    assert_nothing_raised("Did not parse old comment") do
      assert_equal({:record_type => :comment, :line => comment}, @parser.parse_line(comment))
    end
    comment = '" another type of comment'
    assert_nothing_raised("Did not parse new comment") do
      assert_equal({:record_type => :comment2, :line => comment}, @parser.parse_line(comment))
    end

    # Now define two overlapping record types and make sure we keep the
    # correct order.  We do first match, not longest match.
    assert_nothing_raised do
      @parser.text_line :one, :match => /^y/
      @parser.text_line :two, :match => /^yay/
    end

    assert_nothing_raised do
      assert_equal({:record_type => :one, :line => "yayness"}, @parser.parse_line("yayness"))
    end

  end

  def test_record_line
    tabrecord = "tab	separated	content"
    spacerecord = "space separated content"

    # Make sure we always require an appropriate set of options
    [{:separator => "\t"}, {}, {:fields => %w{record_type}}].each do |opts|
      assert_raise(ArgumentError, "Accepted #{opts.inspect}") do
        @parser.record_line :record, opts
      end
    end

    # Verify that our default separator is tabs
    tabs = nil
    assert_nothing_raised do
      tabs = @parser.record_line :tabs, :fields => [:name, :first, :second]
    end

    # Make sure out tab line gets matched
    tabshould = {:record_type => :tabs, :name => "tab", :first => "separated", :second => "content"}
    assert_nothing_raised do
      assert_equal(tabshould, @parser.handle_record_line(tabrecord, tabs))
    end

    # Now add our space-separated record type
    spaces = nil
    assert_nothing_raised do
      spaces = @parser.record_line :spaces, :fields => [:name, :first, :second]
    end

    # Now make sure both lines parse correctly
    spaceshould = {:record_type => :spaces, :name => "space", :first => "separated", :second => "content"}

    assert_nothing_raised do
      assert_equal(tabshould, @parser.handle_record_line(tabrecord, tabs))
      assert_equal(spaceshould, @parser.handle_record_line(spacerecord, spaces))
    end
  end

  def test_to_line
    @parser.text_line :comment, :match => /^#/
    @parser.text_line :blank, :match => /^\s*$/
    @parser.record_line :record, :fields => %w{name one two}, :joiner => "\t"

    johnny = {:record_type => :record, :name => "johnny", :one => "home",
      :two => "yay"}
    bill = {:record_type => :record, :name => "bill", :one => "work",
      :two => "boo"}

    records = {
      :comment => {:record_type => :comment, :line => "# This is a file"},
      :blank => {:record_type => :blank, :line => ""},
      :johnny => johnny,
      :bill => bill
    }

    lines = {
      :comment => "# This is a file",
      :blank => "",
      :johnny => "johnny	home	yay",
      :bill => "bill	work	boo"
    }

    records.each do |name, details|
      result = nil
      assert_nothing_raised do
        result = @parser.to_line(details)
      end

      assert_equal(lines[name], result)
    end
    order = [:comment, :blank, :johnny, :bill]

    file = order.collect { |name| lines[name] }.join("\n")

    ordered_records = order.collect { |name| records[name] }

    # Make sure we default to a trailing separator
    assert_equal(true, @parser.trailing_separator, "Did not default to a trailing separtor")

    # Start without a trailing separator
    @parser.trailing_separator = false
    assert_nothing_raised do
      assert_equal(file, @parser.to_file(ordered_records))
    end

    # Now with a trailing separator
    file += "\n"
    @parser.trailing_separator = true
    assert_nothing_raised do
      assert_equal(file, @parser.to_file(ordered_records))
    end

    # Now try it with a different separator, so we're not just catching
    # defaults
    file.gsub!("\n", "\t")
    @parser.line_separator = "\t"
    assert_nothing_raised do
      assert_equal(file, @parser.to_file(ordered_records))
    end
  end

  # Make sure fields that are marked absent get replaced with the appropriate
  # string.
  def test_absent_fields
    record = nil
    assert_nothing_raised do
      record = @parser.record_line :record, :fields => %w{one two three},
        :optional => %w{two three}
    end
    assert_equal("", record.absent, "Did not set a default absent string")

    result = nil
    assert_nothing_raised do

      result = @parser.to_line(
        :record_type => :record,

        :one => "a", :two => :absent, :three => "b")
    end

    assert_equal("a  b", result, "Absent was not correctly replaced")

    # Now try using a different replacement character
    record.absent = "*" # Because cron is a pain in my ass
    assert_nothing_raised do
      result = @parser.to_line(:record_type => :record, :one => "a", :two => :absent, :three => "b")
    end

    assert_equal("a * b", result, "Absent was not correctly replaced")

    # Make sure we deal correctly with the string 'absent'
    assert_nothing_raised do

      result = @parser.to_line(
        :record_type => :record,

        :one => "a", :two => "b", :three => 'absent')
    end

    assert_equal("a b absent", result, "Replaced string 'absent'")

    # And, of course, make sure we can swap things around.
    assert_nothing_raised do

      result = @parser.to_line(
        :record_type => :record,

        :one => "a", :two => "b", :three => :absent)
    end

    assert_equal("a b *", result, "Absent was not correctly replaced")
  end

  # Make sure we can specify a different join character than split character
  def test_split_join_record_line
    check = proc do |start, record, final|
      # Check parsing first
      result = @parser.parse_line(start)
      [:one, :two].each do |param|

        assert_equal(
          record[param], result[param],

          "Did not correctly parse #{start.inspect}")
      end

      # And generating
      assert_equal(final, @parser.to_line(result), "Did not correctly generate #{final.inspect} from #{record.inspect}")
    end

    # First try it with symmetric characters
    @parser.record_line :symmetric, :fields => %w{one two},
      :separator => " "

    check.call "a b", {:one => "a", :two => "b"}, "a b"
    @parser.clear_records

    # Now assymetric but both strings
    @parser.record_line :asymmetric, :fields => %w{one two},
      :separator => "\t", :joiner => " "

    check.call "a\tb", {:one => "a", :two => "b"}, "a b"
    @parser.clear_records

    # And assymmetric with a regex
    @parser.record_line :asymmetric2, :fields => %w{one two},
      :separator => /\s+/, :joiner => " "

    check.call "a\tb", {:one => "a", :two => "b"}, "a b"
    check.call "a b", {:one => "a", :two => "b"}, "a b"
  end

  # Make sure we correctly regenerate files.
  def test_to_file
    @parser.text_line :comment, :match => /^#/
    @parser.text_line :blank, :match => /^\s*$/
    @parser.record_line :record, :fields => %w{name one two}

    text = "# This is a comment

johnny one two
billy three four\n"

#         Just parse and generate, to make sure it's isomorphic.
assert_nothing_raised do
  assert_equal(text, @parser.to_file(@parser.parse(text)),
    "parsing was not isomorphic")
    end
  end

  def test_valid_attrs
    @parser.record_line :record, :fields => %w{one two three}


      assert(
        @parser.valid_attr?(:record, :one),

      "one was considered invalid")


        assert(
          @parser.valid_attr?(:record, :ensure),

      "ensure was considered invalid")


        assert(
          ! @parser.valid_attr?(:record, :four),

      "four was considered valid")
  end

  def test_record_blocks
    options = nil
    assert_nothing_raised do
      # Just do a simple test
      options = @parser.record_line :record,
        :fields => %w{name alias info} do |line|
        line = line.dup
        ret = {}
        if line.sub!(/(\w+)\s*/, '')
          ret[:name] = $1
        else
          return nil
        end

        if line.sub!(/(#.+)/, '')
          desc = $1.sub(/^#\s*/, '')
          ret[:description] = desc unless desc == ""
        end

        ret[:alias] = line.split(/\s+/) if line != ""

        return ret
      end
    end

    values = {
      :name => "tcpmux",
      :description => "TCP port service multiplexer",
      :alias => ["sink"]
    }

    {

      "tcpmux      " => [:name],
      "tcpmux" => [:name],
      "tcpmux      sink" => [:name, :port, :protocols, :alias],
      "tcpmux      # TCP port service multiplexer" =>
        [:name, :description, :port, :protocols],
      "tcpmux      sink         # TCP port service multiplexer" =>
        [:name, :description, :port, :alias, :protocols],
      "tcpmux      sink null    # TCP port service multiplexer" =>
        [:name, :description, :port, :alias, :protocols],
    }.each do |line, should|
      result = nil
      assert_nothing_raised do
        result = @parser.handle_record_line(line, options)
      end
      assert(result, "Did not get a result back for '#{line}'")
      should.each do |field|
        if field == :alias and line =~ /null/
          assert_equal(%w{sink null}, result[field], "Field #{field} was not right in '#{line}'")
        else
          assert_equal(values[field], result[field], "Field #{field} was not right in '#{line}'")
        end
      end
    end


  end

  # Make sure we correctly handle optional fields.  We'll skip this
  # functionality until we really know we need it.
  def test_optional_fields
    assert_nothing_raised do
      @parser.record_line :record,
        :fields => %w{one two three four},
        :optional => %w{three four},
        :absent => "*",
        :separator => " " # A single space
    end

    { "a b c d" => [],
      "a b * d" => [:three],
      "a b * *" => [:three, :four],
      "a b c *" => [:four]
    }.each do |line, absentees|
      record = nil
      assert_nothing_raised do
        record = @parser.parse_line(line)
      end

      # Absent field is :absent, not "*" inside the record
      absentees.each do |absentee|
        assert_equal(:absent, record[absentee])
      end

      # Now regenerate the line
      newline = nil
      assert_nothing_raised do
        newline = @parser.to_line(record)
      end

      # And make sure they're equal
      assert_equal(line, newline)
    end

    # Now make sure it pukes if we don't provide the required fields
    assert_raise(ArgumentError) do
      @parser.to_line(:record_type => :record, :one => "yay")
    end
  end

  def test_record_rts
    # Start with the default
    assert_nothing_raised do
      @parser.record_line :record,
        :fields => %w{one two three four},
        :optional => %w{three four}
    end


      assert_equal(
        "a b  ",

      @parser.to_line(:record_type => :record, :one => "a", :two => "b")
    )

    # Now say yes to removing
    @parser.clear_records
    assert_nothing_raised do
      @parser.record_line :record,
        :fields => %w{one two three four},
        :optional => %w{three four},
        :rts => true
    end


      assert_equal(
        "a b",

      @parser.to_line(:record_type => :record, :one => "a", :two => "b")
    )

    # Lastly, try a regex
    @parser.clear_records
    assert_nothing_raised do
      @parser.record_line :record,
        :fields => %w{one two three four},
        :optional => %w{three four},
        :absent => "*",
        :rts => /[ *]+$/
    end


      assert_equal(
        "a b",

      @parser.to_line(:record_type => :record, :one => "a", :two => "b")
    )
  end

  # Make sure the last field can contain the separator, as crontabs do, and
  # that we roll them all up by default.
  def test_field_rollups
    @parser.record_line :yes, :fields => %w{name one two}

    result = nil
    assert_nothing_raised do
      result = @parser.send(:parse_line, "Name One Two Three")
    end

      assert_equal(
        "Two Three", result[:two],

      "Did not roll up last fields by default")

    @parser = FParser.new
    assert_nothing_raised("Could not create record that rolls up fields") do
      @parser.record_line :no, :fields => %w{name one two}, :rollup => false
    end

    result = nil
    assert_nothing_raised do
      result = @parser.send(:parse_line, "Name One Two Three")
    end

      assert_equal(
        "Two", result[:two],

      "Rolled up last fields when rollup => false")
  end

  def test_text_blocks
    record = nil
    assert_nothing_raised do
      record = @parser.text_line :name, :match => %r{^#} do |line|
        {:line => line.upcase}
      end
    end


      assert(
        record.respond_to?(:process),

      "Block was not used with text line")

    assert_equal("YAYNESS", record.process("yayness")[:line],
      "Did not call process method")
  end

  def test_hooks
    record = nil
    # First try it with a normal record
    assert_nothing_raised("Could not set hooks") do
      record = @parser.record_line :yay, :fields => %w{one two},
        :post_parse => proc { |hash| hash[:posted] = true },
        :pre_gen => proc { |hash| hash[:one] = hash[:one].upcase },
        :to_line => proc { |hash| "# Line\n" + join(hash) }
    end

    assert(record.respond_to?(:post_parse), "did not create method for post-hook")
    assert(record.respond_to?(:pre_gen), "did not create method for pre-hook")

    result = nil
    assert_nothing_raised("Could not process line with hooks") do
      result = @parser.parse_line("one two")
    end

    assert(result[:posted], "Did not run post-hook")
    old_result = result

    # Now make sure our pre-gen hook is called
    assert_nothing_raised("Could not generate line with hooks") do
      result = @parser.to_line(result)
    end
    assert_equal("# Line\nONE two", result, "did not call pre-gen hook")
    assert_equal("one", old_result[:one], "passed original hash to pre hook")
  end
end

class TestUtilFileRecord < Test::Unit::TestCase
  include PuppetTest
  include PuppetTest::FileParsing

  Record = Puppet::Util::FileParsing::FileRecord
  def test_new_filerecord
    [   [:fake, {}],
      [nil, ]
    ].each do |args|
      assert_raise(ArgumentError, "Did not fail on #{args.inspect}") do
        Record.new(*args)
      end
    end

    # Make sure the fields get turned into symbols
    record = nil
    assert_nothing_raised do
      record = Record.new(:record, :fields => %w{one two})
    end
    assert_equal([:one, :two], record.fields, "Did not symbolize fields")

    # Make sure we fail on invalid fields
    [:record_type, :target, :on_disk].each do |field|
      assert_raise(ArgumentError, "Did not fail on invalid field #{field}") {
        Record.new(:record, :fields => [field])
      }
    end
  end

  def test_defaults
    record = Record.new(:text, :match => %r{^#})
    [:absent, :separator, :joiner, :optional].each do |field|
      assert_nil(record.send(field), "#{field} was not nil")
    end

    record = Record.new(:record, :fields => %w{fields})
    {:absent => "", :separator => /\s+/, :joiner => " ", :optional => []}.each do |field, default|
      assert_equal(default, record.send(field), "#{field} was not default")
    end
  end

  def test_block
    record = nil
    assert_nothing_raised("Could not pass a block when creating record") do
      record = Record.new(:record, :fields => %w{one}) do |line|
        return line.upcase
      end
    end

    line = "This is a line"


      assert(
        record.respond_to?(:process),

      "Record did not define :process method")


        assert_equal(
          line.upcase, record.process(line),

      "Record did not process line correctly")
  end

  # Make sure we can declare that we want the block to be instance-eval'ed instead of
  # defining the 'process' method.
  def test_instance_block
    record = nil
    assert_nothing_raised("Could not pass a block when creating record") do
      record = Record.new(:record, :block_eval => :instance, :fields => %w{one}) do
        def process(line)
          line.upcase
        end

        def to_line(details)
          details.upcase
        end
      end
    end

    assert(record.respond_to?(:process), "Block was not instance-eval'ed and process was not defined")
    assert(record.respond_to?(:to_line), "Block was not instance-eval'ed and to_line was not defined")

    line = "some text"
    assert_equal(line.upcase, record.process(line), "Instance-eval'ed record did not call :process correctly")
    assert_equal(line.upcase, record.to_line(line), "Instance-eval'ed record did not call :to_line correctly")
  end
end


