#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppet'
require 'puppet/network/client'
require 'puppettest'
require 'socket'
require 'facter'

class TestFileBucketExe < Test::Unit::TestCase
    include PuppetTest::ExeTest

    def test_local
        basedir = tempfile()
        FileUtils.mkdir_p(basedir)

        bucket = tempfile
        file = tempfile
        text = "somet ext"
        md5 = Digest::MD5.hexdigest(text)
        File.open(file, "w") { |f| f.print text }
        out = %x{filebucket --confdir #{basedir} --vardir #{basedir} --bucket #{bucket} backup #{file}}

        outfile, outmd5 = out.chomp.split(": ")

        assert_equal(0, $?, "filebucket did not run successfully")

        assert_equal(file, outfile, "did not output correct file name")
        assert_equal(md5, outmd5, "did not output correct md5 sum")

        dipper = Puppet::Network::Client.dipper.new(:Path => bucket)

        newtext = nil
        assert_nothing_raised("Could not get file from bucket") do
            newtext = dipper.getfile(md5)
        end

        assert_equal(text, newtext, "did not get correct file from md5 sum")

        out = %x{filebucket --confdir #{basedir} --vardir #{basedir} --bucket #{bucket} get #{md5}}
        assert_equal(0, $?, "filebucket did not run successfully")
        assert_equal(text, out, "did not get correct text back from filebucket")

        File.open(file, "w") { |f| f.puts "some other txt" }
        out = %x{filebucket --confdir #{basedir} --vardir #{basedir} --bucket #{bucket} restore #{file} #{md5}}
        assert_equal(0, $?, "filebucket did not run successfully")
        assert_equal(text, File.read(file), "file was not restored")
    end
end

