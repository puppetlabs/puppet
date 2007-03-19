#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/network/handler/filebucket'
require 'base64'

class TestBucket < Test::Unit::TestCase
    include PuppetTest::ServerTest

    def out
        if defined? @num
            @num += 1
        else
            @num = 1
        end

        #Puppet.err "#{Process.pid}: %s: %s" % [@num, memory()]
        #gcdebug(String)
    end

    # run through all of the files and exercise the filebucket methods
    def checkfiles(client)
        files = filelist()

        # iterate across all of the files
        files.each { |file|
            Puppet.warning file
            out
            tempdir = tempfile()
            Dir.mkdir(tempdir)
            name = File.basename(file)
            tmppath = File.join(tempdir,name)
            @@tmpfiles << tmppath

            out
            # copy the files to our tmp directory so we can modify them...
            FileUtils.cp(file, tmppath)

            # make sure the copy worked
            assert(FileTest.exists?(tmppath))

            # backup both the orig file and the tmp file
            osum = nil
            tsum = nil
            nsum = nil
            out
            assert_nothing_raised("Could not back up file") {
                osum = client.backup(file)
            }
            out
            assert_nothing_raised("Could not back up second file") {
                tsum = client.backup(tmppath)
            }
            out

            # verify you got the same sum back for both
            assert(tsum == osum)

            # modify our tmp file
            unless FileTest.writable?(tmppath)
                File.chmod(0644, tmppath)
            end
            File.open(tmppath,File::WRONLY|File::TRUNC) { |wf|
                wf.print "This is some test text\n"
            }
            out

            # back it up
            assert_nothing_raised {
                #STDERR.puts("backing up %s" % tmppath) if $debug
                nsum = client.backup(tmppath)
            }
            out

            # and verify the sum changed
            assert(tsum != nsum)

            # restore the orig
            assert_nothing_raised {
                nsum = client.restore(tmppath,tsum)
            }
            out

            # and verify it actually got restored
            contents = File.open(tmppath) { |rf|
                #STDERR.puts("reading %s" % tmppath) if $debug
                rf.read
            }
            out
            csum = Digest::MD5.hexdigest(contents)
            out
            assert(tsum == csum)
        }
    end

    # a list of files that should be on the system
    # just something to test moving files around
    def filelist
        if defined? @files
            return @files
        else
            @files = []
        end

        %w{
            who bash sh uname /etc/passwd /etc/syslog.conf /etc/hosts 
        }.each { |file|
            # if it's fully qualified, just add it
            if file =~ /^\//
                if FileTest.exists?(file)
                    @files.push file
                end
            else
                # else if it's unqualified, look for it in our path
                begin
                    path = %x{which #{file}}
                rescue => detail
                    #STDERR.puts "Could not search for binaries: %s" % detail
                    next
                end

                if path != ""
                    @files.push path.chomp
                end
            end
        }

        return @files
    end

    def setup
        super
        @bucket = tempfile()
    end

    #def teardown
    #    system("lsof -p %s" % Process.pid)
    #    super
    #end

    # test operating against the local filebucket object
    # this calls the direct server methods, which are different than the
    # Dipper methods
    def test_localserver
        files = filelist()
        server = nil
        assert_nothing_raised {
            server = Puppet::Network::Handler.filebucket.new(
                :Path => @bucket
            )
        }

        # iterate across them...
        files.each { |file|
            contents = File.open(file) { |of| of.read }

            md5 = nil

            # add a file to the repository
            assert_nothing_raised {
                #STDERR.puts("adding %s" % file) if $debug
                md5 = server.addfile(Base64.encode64(contents),file)
            }

            # and get it back again
            newcontents = nil
            assert_nothing_raised {
                #STDERR.puts("getting %s" % file) if $debug
                newcontents = Base64.decode64(server.getfile(md5))
            }

            # and then make sure they're still the same
            assert(
                contents == newcontents
            )
        }
    end

    # test with a server and a Dipper
    def test_localboth
        files = filelist()

        bucket = nil
        client = nil
        threads = []
        assert_nothing_raised {
            bucket = Puppet::Network::Handler.filebucket.new(
                :Path => @bucket
            )
        }

        #sleep(30)
        assert_nothing_raised {
            client = Puppet::Network::Client.dipper.new(
                :Bucket => bucket
            )
        }

        #4.times { checkfiles(client) }
        checkfiles(client)
    end

    # test that things work over the wire
    def test_webxmlmix
        files = filelist()

        tmpdir = File.join(tmpdir(),"tmpfiledir")
        @@tmpfiles << tmpdir
        FileUtils.mkdir_p(tmpdir)

        Puppet[:autosign] = true
        client = nil
        port = Puppet[:masterport]

        pid = mkserver(:CA => {}, :FileBucket => { :Path => @bucket})

        assert_nothing_raised {
            client = Puppet::Network::Client.dipper.new(
                :Server => "localhost",
                :Port => @@port
            )
        }

        checkfiles(client)

        unless pid
            raise "Uh, we don't have a child pid"
        end
        Process.kill("TERM", pid)
    end

    def test_no_path_duplicates
        bucket = nil
        assert_nothing_raised {
            bucket = Puppet::Network::Handler.filebucket.new(
                :Path => @bucket
            )
        }

        sum = nil
        assert_nothing_raised {
            sum = bucket.addfile("yayness", "/my/file")
        }
        assert_nothing_raised {
            bucket.addfile("yayness", "/my/file")
        }

        a, b, pathfile = bucket.class.paths(bucket.path, sum)

        assert(FileTest.exists?(pathfile), "No path file at %s" % pathfile)

        assert_equal("/my/file\n", File.read(pathfile))
    end

    # #447 -- a flat file structure just won't suffice.
    def test_deeper_filestructure
        bucket = Puppet::Network::Handler.filebucket.new(:Path => @bucket)

        text = "this is some text"
        md5 = Digest::MD5.hexdigest(text)

        olddir = File.join(@bucket, md5)
        FileUtils.mkdir_p(olddir)
        oldcontent = File.join(olddir, "contents")
        File.open(oldcontent, "w") { |f| f.print text }

        result = nil
        assert_nothing_raised("Could not retrieve content from old structure") do
            result = bucket.getfile(md5)
        end
        assert_equal(text, result, "old-style content is wrong")

        text = "and this is some new text"
        md5 = Digest::MD5.hexdigest(text)

        dirs = File.join(md5[0..7].split(""))
        dir = File.join(@bucket, dirs)
        filedir, contents, paths = bucket.class.paths(@bucket, md5)

        assert_equal(dir, filedir, "did not use a deeper file structure") 
        assert_equal(File.join(dir, "contents"), contents,
            "content path is not the deeper version")
        assert_equal(File.join(dir, "paths"), paths,
            "paths file path is not the deeper version")

        # Store our new text and make sure it gets stored in the new location
        path = "/some/fake/path"
        assert_nothing_raised("Could not store text") do
            bucket.addfile(text, path)
        end
        assert(FileTest.exists?(contents), "did not create content file")
        assert_equal(text, File.read(contents), "content is not right")
        assert(FileTest.exists?(paths), "did not create paths file")
        assert(File.read(paths).include?(path), "paths file does not contain path")

        # And make sure we get it back out again
        assert_nothing_raised("Could not retrieve new-style content") do
            result = bucket.getfile(md5)
        end
        assert_equal(text, result, "did not retrieve new content correctly")
    end

    def test_add_path
        bucket = Puppet::Network::Handler.filebucket.new(:Path => @bucket)

        file = tempfile()

        assert(! FileTest.exists?(file), "file already exists")

        path = "/some/thing"
        assert_nothing_raised("Could not add path") do
            bucket.send(:add_path, path, file)
        end
        assert_equal(path + "\n", File.read(file), "path was not added")

        assert_nothing_raised("Could not add path second time") do
            bucket.send(:add_path, path, file)
        end
        assert_equal(path + "\n", File.read(file), "path was duplicated")

        # Now try a new path
        newpath = "/another/path"
        assert_nothing_raised("Could not add path second time") do
            bucket.send(:add_path, newpath, file)
        end
        text = [path, newpath].join("\n") + "\n"
        assert_equal(text, File.read(file), "path was duplicated")

        assert_nothing_raised("Could not add path third time") do
            bucket.send(:add_path, path, file)
        end
        assert_equal(text, File.read(file), "path was duplicated")
        assert_nothing_raised("Could not add second path second time") do
            bucket.send(:add_path, newpath, file)
        end
        assert_equal(text, File.read(file), "path was duplicated")
    end
end

# $Id$
