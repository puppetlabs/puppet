#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/inifile'
require 'puppettest'

class TestFileType < Test::Unit::TestCase
	include PuppetTest

    def setup
        super
        @file = Puppet::IniConfig::File.new
    end
    
    def teardown
        @file = nil
        super
    end

    def test_simple
        fname = mkfile("[main]\nkey1=value1\n# Comment\nkey2=value2")
        assert_nothing_raised {
            @file.read(fname)
        }
        s = get_section('main')
        assert_entries(s, { 'key1' => 'value1', 'key2' => 'value2' })
        @file['main']['key2'] = 'newvalue2'
        @file['main']['key3'] = 'newvalue3'
        text = s.format
        assert_equal("[main]\nkey1=value1\n# Comment\nkey2=newvalue2\nkey3=newvalue3\n",
                     s.format)
    end

    def test_multi
        fmain = mkfile("[main]\nkey1=main.value1\n# Comment\nkey2=main.value2")
        fsub = mkfile("[sub1]\nkey1=sub1 value1\n\n" +
                        "[sub2]\nkey1=sub2.value1")
        main_mtime = File::stat(fmain).mtime
        assert_nothing_raised {
            @file.read(fmain)
            @file.read(fsub)
        }
        main = get_section('main')
        assert_entries(main, 
                       { 'key1' => 'main.value1', 'key2' => 'main.value2' })
        sub1 = get_section('sub1')
        assert_entries(sub1, { 'key1' => 'sub1 value1' })
        sub2 = get_section('sub2')
        assert_entries(sub2, { 'key1' => 'sub2.value1' })
        [main, sub1, sub2].each { |s| assert( !s.dirty? ) }
        sub1['key1'] = 'sub1 newvalue1'
        sub2['key2'] = 'sub2 newvalue2'
        assert(! main.dirty?)
        [sub1, sub2].each { |s| assert( s.dirty? ) }
        @file.store
        [main, sub1, sub2].each { |s| assert( !s.dirty? ) }
        assert( File.exists?(fmain) )
        assert( File.exists?(fsub) )
        assert_equal(main_mtime, File::stat(fmain).mtime)
        subtext = File.read(fsub)
        assert_equal("[sub1]\nkey1=sub1 newvalue1\n\n" +
                     "[sub2]\nkey1=sub2.value1\nkey2=sub2 newvalue2\n",
                     subtext)
    end

    def test_format_nil
        fname = mkfile("[main]\nkey1=value1\n# Comment\nkey2=value2\n" +
                       "# Comment2\n")
        assert_nothing_raised {
            @file.read(fname)
        }
        s = get_section('main')
        s['key2'] = nil
        s['key3'] = nil
        text = s.format
        assert_equal("[main]\nkey1=value1\n# Comment\n# Comment2\n",
                     s.format)
    end

    def test_whitespace
        fname = mkfile("[main]\n  key1=v1\nkey2  =v2\n")
        assert_nothing_raised {
            @file.read(fname)
        }
        s = get_section('main')
        assert_equal('v1', s['key1'])
        assert_equal('v2', s['key2'])
    end

    def assert_entries(section, hash)
        hash.each do |k, v| 
            assert_equal(v, section[k], 
                        "Expected <#{v}> for #{section.name}[#{k}] " + 
                         "but got <#{section[k]}>")
        end
    end

    def get_section(name)
        result = @file[name]
        assert_not_nil(result)
        return result
    end

    def mkfile(content)
        file = tempfile()
        File.open(file, "w") { |f| f.print(content) }
        return file
    end
end
