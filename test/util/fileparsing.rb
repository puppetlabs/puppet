#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

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

    def test_lines
        parser = FParser.new

        assert_equal("\n", parser.line_separator,
            "Default separator was incorrect")

        {"\n" => ["one two\nthree four", "one two\nthree four\n"],
         "\t" => ["one two\tthree four", "one two\tthree four\t"],
        }.each do |sep, tests|
            assert_nothing_raised do
                parser.line_separator = sep
            end
            assert_equal(sep, parser.line_separator,
                "Did not set separator")

            tests.each do |test|
                assert_equal(["one two", "three four"], parser.lines(test),
                    "Incorrectly parsed %s" % test.inspect)
            end
        end
    end

    # Make sure parse calls the appropriate methods or errors out
    def test_parse
        parser = FParser.new

        parser.meta_def(:parse_line) do |line|
            line.split(/\s+/)
        end

        text = "one line\ntwo line"
        should = [%w{one line}, %w{two line}]
        ret = nil
        assert_nothing_raised do
            ret = parser.parse(text)
        end

        assert_equal(should, ret)
    end

    # Make sure we correctly handle different kinds of text lines.
    def test_text_line
        parser = FParser.new

        comment = "# this is a comment"

        # Make sure it fails if no regex is passed
        assert_raise(ArgumentError) do
            parser.text_line :comment
        end

        # define a text matching comment record
        assert_nothing_raised do
            parser.text_line :comment, :match => /^#/
        end

        # Make sure it matches
        assert_nothing_raised do
            assert_equal({:record_type => :comment, :line => comment}, 
                 parser.parse_line(comment))
        end

        # But not something else
        assert_nothing_raised do
            assert_nil(parser.parse_line("some other text"))
        end

        # Now define another type and make sure we get the right one back
        assert_nothing_raised do
            parser.text_line :blank, :match => /^\s*$/
        end

        # The comment should still match
        assert_nothing_raised do
            assert_equal({:record_type => :comment, :line => comment}, 
                 parser.parse_line(comment))
        end

        # As should our new line type
        assert_nothing_raised do
            assert_equal({:record_type => :blank, :line => ""}, 
                 parser.parse_line(""))
        end

    end

    def test_parse_line
        parser = FParser.new

        comment = "# this is a comment"

        # Make sure it fails if we don't have any record types defined
        assert_raise(Puppet::DevError) do
            parser.parse_line(comment)
        end

        # Now define a text matching comment record
        assert_nothing_raised do
            parser.text_line :comment, :match => /^#/
        end

        # And make sure we can't define another one with the same name
        assert_raise(ArgumentError) do
            parser.text_line :comment, :match => /^"/
        end

        result = nil
        assert_nothing_raised("Did not parse text line") do
            result = parser.parse_line comment
        end

        assert_equal({:record_type => :comment, :line => comment}, result)

        # Make sure we just return nil on unmatched lines.
        assert_nothing_raised("Did not parse text line") do
            result = parser.parse_line "No match for this"
        end

        assert_nil(result, "Somehow matched an empty line")

        # Now define another type of comment, and make sure both types get
        # correctly returned as comments
        assert_nothing_raised do
            parser.text_line :comment2, :match => /^"/
        end

        assert_nothing_raised("Did not parse old comment") do
            assert_equal({:record_type => :comment, :line => comment}, 
                 parser.parse_line(comment))
        end
        comment = '" another type of comment'
        assert_nothing_raised("Did not parse new comment") do
            assert_equal({:record_type => :comment2, :line => comment}, 
                 parser.parse_line(comment))
        end

        # Now define two overlapping record types and make sure we keep the
        # correct order.  We do first match, not longest match.
        assert_nothing_raised do
            parser.text_line :one, :match => /^y/
            parser.text_line :two, :match => /^yay/
        end

        assert_nothing_raised do
            assert_equal({:record_type => :one, :line => "yayness"},
                parser.parse_line("yayness"))
        end

    end

    def test_record_line
        parser = FParser.new

        tabrecord = "tab	separated	content"
        spacerecord = "space separated content"

        # Make sure we always require an appropriate set of options
        [{:separator => "\t"}, {}, {:fields => %w{record_type}}].each do |opts|
            assert_raise(ArgumentError, "Accepted %s" % opts.inspect) do
                parser.record_line :record, opts
            end
        end

        # Verify that our default separator is tabs
        tabs = nil
        assert_nothing_raised do
            tabs = parser.record_line :tabs, :fields => [:name, :first, :second]
        end

        # Make sure out tab line gets matched
        tabshould = {:record_type => :tabs, :name => "tab", :first => "separated",
                            :second => "content"}
        assert_nothing_raised do
            assert_equal(tabshould, parser.handle_record_line(tabrecord, tabs))
        end

        # Now add our space-separated record type
        spaces = nil
        assert_nothing_raised do
            spaces = parser.record_line :spaces, :fields => [:name, :first, :second]
        end

        # Now make sure both lines parse correctly
        spaceshould = {:record_type => :spaces, :name => "space",
            :first => "separated", :second => "content"}

        assert_nothing_raised do
            assert_equal(tabshould, parser.handle_record_line(tabrecord, tabs))
            assert_equal(spaceshould, parser.handle_record_line(spacerecord, spaces))
        end
    end

    def test_to_line
        parser = FParser.new

        parser.text_line :comment, :match => /^#/
        parser.text_line :blank, :match => /^\s*$/
        parser.record_line :record, :fields => %w{name one two}, :joiner => "\t"

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
                result = parser.to_line(details)
            end

            assert_equal(lines[name], result)
        end
        order = [:comment, :blank, :johnny, :bill]

        file = order.collect { |name| lines[name] }.join("\n")

        ordered_records = order.collect { |name| records[name] }

        # Make sure we default to a trailing separator
        assert_equal(true, parser.trailing_separator,
            "Did not default to a trailing separtor")

        # Start without a trailing separator
        parser.trailing_separator = false
        assert_nothing_raised do
            assert_equal(file, parser.to_file(ordered_records))
        end

        # Now with a trailing separator
        file += "\n"
        parser.trailing_separator = true
        assert_nothing_raised do
            assert_equal(file, parser.to_file(ordered_records))
        end

        # Now try it with a different separator, so we're not just catching
        # defaults
        file.gsub!("\n", "\t")
        parser.line_separator = "\t"
        assert_nothing_raised do
            assert_equal(file, parser.to_file(ordered_records))
        end
    end

    # Make sure fields that are marked absent get replaced with the appropriate
    # string.
    def test_absent_fields
        parser = FParser.new

        options = nil
        assert_nothing_raised do
            options = parser.record_line :record, :fields => %w{one two three},
                :optional => %w{two three}
        end
        assert_equal("", options[:absent], "Did not set a default absent string")

        result = nil
        assert_nothing_raised do
            result = parser.to_line(:record_type => :record,
                :one => "a", :two => :absent, :three => "b")
        end

        assert_equal("a  b", result, "Absent was not correctly replaced")

        # Now try using a different replacement character
        options[:absent] = "*" # Because cron is a pain in my ass
        assert_nothing_raised do
            result = parser.to_line(:record_type => :record,
                :one => "a", :two => :absent, :three => "b")
        end

        assert_equal("a * b", result, "Absent was not correctly replaced")

        # Make sure we deal correctly with the string 'absent'
        assert_nothing_raised do
            result = parser.to_line(:record_type => :record,
                :one => "a", :two => "b", :three => 'absent')
        end

        assert_equal("a b absent", result, "Replaced string 'absent'")

        # And, of course, make sure we can swap things around.
        assert_nothing_raised do
            result = parser.to_line(:record_type => :record,
                :one => "a", :two => "b", :three => :absent)
        end

        assert_equal("a b *", result, "Absent was not correctly replaced")
    end

    # Make sure we can specify a different join character than split character
    def test_split_join_record_line
        parser = FParser.new

        check = proc do |start, record, final|
            # Check parsing first
            result = parser.parse_line(start)
            [:one, :two].each do |param|
                assert_equal(record[param], result[param], 
                    "Did not correctly parse %s" % start.inspect)
            end

            # And generating
            assert_equal(final, parser.to_line(result),
                "Did not correctly generate %s from %s" %
                [final.inspect, record.inspect])
        end

        # First try it with symmetric characters
        parser.record_line :symmetric, :fields => %w{one two},
            :separator => " "

        check.call "a b", {:one => "a", :two => "b"}, "a b"
        parser.clear_records

        # Now assymetric but both strings
        parser.record_line :asymmetric, :fields => %w{one two},
            :separator => "\t", :joiner => " "

        check.call "a\tb", {:one => "a", :two => "b"}, "a b"
        parser.clear_records

        # And assymmetric with a regex
        parser.record_line :asymmetric2, :fields => %w{one two},
            :separator => /\s+/, :joiner => " "

        check.call "a\tb", {:one => "a", :two => "b"}, "a b"
        check.call "a b", {:one => "a", :two => "b"}, "a b"
    end

    # Make sure we correctly regenerate files.
    def test_to_file
        parser = FParser.new

        parser.text_line :comment, :match => /^#/
        parser.text_line :blank, :match => /^\s*$/
        parser.record_line :record, :fields => %w{name one two}

        text = "# This is a comment

johnny one two
billy three four\n"

        # Just parse and generate, to make sure it's isomorphic.
        assert_nothing_raised do
            assert_equal(text, parser.to_file(parser.parse(text)),
                "parsing was not isomorphic")
        end
    end

    def test_valid_attrs
        parser = FParser.new

        parser.record_line :record, :fields => %w{one two three}

        assert(parser.valid_attr?(:record, :one),
            "one was considered invalid")

        assert(parser.valid_attr?(:record, :ensure),
            "ensure was considered invalid")

        assert(! parser.valid_attr?(:record, :four),
            "four was considered valid")
    end

    def test_record_blocks
        parser = FParser.new

        options = nil
        assert_nothing_raised do
            # Just do a simple test
            options = parser.record_line :record,
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

                if line != ""
                    ret[:alias] = line.split(/\s+/)
                end

                return ret
            end
        end

        assert(parser.respond_to?(:handle_record_line_record),
            "Parser did not define record method")

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
                result = parser.handle_record_line(line, options)
            end
            assert(result, "Did not get a result back for '%s'" % line)
            should.each do |field|
                if field == :alias and line =~ /null/
                    assert_equal(%w{sink null}, result[field],
                        "Field %s was not right in '%s'" % [field, line])
                else
                    assert_equal(values[field], result[field],
                        "Field %s was not right in '%s'" % [field, line])
                end
            end
        end


    end

    # Make sure we correctly handle optional fields.  We'll skip this
    # functionality until we really know we need it.
    def test_optional_fields
        parser = FParser.new

        assert_nothing_raised do
            parser.record_line :record,
                :fields => %w{one two three four},
                :optional => %w{three four},
                :absent => "*",
                :separator => " " # A single space
        end

        ["a b c d", "a b * d", "a b * *", "a b c *"].each do |line|
            record = nil
            assert_nothing_raised do
                record = parser.parse_line(line)
            end

            # Now regenerate the line
            newline = nil
            assert_nothing_raised do
                newline = parser.to_line(record)
            end

            # And make sure they're equal
            assert_equal(line, newline)
        end

        # Now make sure it pukes if we don't provide the required fields
        assert_raise(ArgumentError) do
            parser.to_line(:record_type => :record, :one => "yay")
        end
    end

    def test_record_rts
        parser = FParser.new

        # Start with the default
        assert_nothing_raised do
            parser.record_line :record,
                :fields => %w{one two three four},
                :optional => %w{three four}
        end

        assert_equal("a b  ",
            parser.to_line(:record_type => :record, :one => "a", :two => "b")
        )

        # Now say yes to removing
        parser.clear_records
        assert_nothing_raised do
            parser.record_line :record,
                :fields => %w{one two three four},
                :optional => %w{three four},
                :rts => true
        end

        assert_equal("a b",
            parser.to_line(:record_type => :record, :one => "a", :two => "b")
        )

        # Lastly, try a regex
        parser.clear_records
        assert_nothing_raised do
            parser.record_line :record,
                :fields => %w{one two three four},
                :optional => %w{three four},
                :absent => "*",
                :rts => /[ *]+$/
        end

        assert_equal("a b",
            parser.to_line(:record_type => :record, :one => "a", :two => "b")
        )
    end
end

# $Id$

