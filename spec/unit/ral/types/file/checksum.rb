#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/type/file'

describe Puppet::Type::File, " when used with replace=>false and content" do
    before do
        @path = Tempfile.new("puppetspec")
        @path.close!()
        @path = @path.path
        @file = Puppet::Type::File.create( { :name => @path, :content => "foo", :replace => :false } )
    end

    %w{md5 md5lite timestamp time}.each do |type|
    end

    def test_checksums
        types = %w{md5 md5lite timestamp time}
        exists = "/tmp/sumtest-exists"
        nonexists = "/tmp/sumtest-nonexists"

        @@tmpfiles << exists
        @@tmpfiles << nonexists

        # try it both with files that exist and ones that don't
        files = [exists, nonexists]
        initstorage
        File.open(exists,File::CREAT|File::TRUNC|File::WRONLY) { |of|
            of.puts "initial text"
        }
        types.each { |type|
            files.each { |path|
                if Puppet[:debug]
                    Puppet.warning "Testing %s on %s" % [type,path]
                end
                file = nil
                events = nil
                # okay, we now know that we have a file...
                assert_nothing_raised() {
                    file = Puppet.type(:file).create(
                        :name => path,
                        :ensure => "file",
                        :checksum => type
                    )
                }
                trans = nil

                currentvalues = file.retrieve

                if file.title !~ /nonexists/
                    sum = file.property(:checksum)
                    assert(sum.insync?(currentvalues[sum]), "file is not in sync")
                end

                events = assert_apply(file)

                assert(events)

                assert(! events.include?(:file_changed), "File incorrectly changed")
                assert_events([], file)

                # We have to sleep because the time resolution of the time-based
                # mechanisms is greater than one second
                sleep 1 if type =~ /time/

                assert_nothing_raised() {
                    File.open(path,File::CREAT|File::TRUNC|File::WRONLY) { |of|
                        of.puts "some more text, yo"
                    }
                }
                Puppet.type(:file).clear

                # now recreate the file
                assert_nothing_raised() {
                    file = Puppet.type(:file).create(
                        :name => path,
                        :checksum => type
                    )
                }
                trans = nil

                assert_events([:file_changed], file)

                # Run it a few times to make sure we aren't getting
                # spurious changes.
                sum = nil
                assert_nothing_raised do
                    sum = file.property(:checksum).retrieve
                end
                assert(file.property(:checksum).insync?(sum),
                    "checksum is not in sync")

                sleep 1.1 if type =~ /time/
                assert_nothing_raised() {
                    File.unlink(path)
                    File.open(path,File::CREAT|File::TRUNC|File::WRONLY) { |of|
                        # We have to put a certain amount of text in here or
                        # the md5-lite test fails
                        2.times {
                            of.puts rand(100)
                        }
                        of.flush
                    }
                }
                assert_events([:file_changed], file)

                # verify that we're actually getting notified when a file changes
                assert_nothing_raised() {
                    Puppet.type(:file).clear
                }

                if path =~ /nonexists/
                    File.unlink(path)
                end
            }
        }
    end
end
