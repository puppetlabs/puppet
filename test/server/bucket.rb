if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
    $debug = true
else
    $debug = false
end

require 'puppet'
require 'test/unit'
require 'puppettest.rb'
require 'base64'

class TestBucket < Test::Unit::TestCase
	include ServerTest

    def out
        if defined? @num
            @num += 1
        else
            @num = 1
        end

        Puppet.err "#{Process.pid}: %s: %s" % [@num, memory()]
        GC.start
    end
    # run through all of the files and exercise the filebucket methods
    def checkfiles(client)
        files = filelist()
        #files = %w{/usr/local/bin/vim /etc/motd /etc/motd /etc/motd /etc/motd}
        #files = %w{/usr/local/bin/vim}

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
            assert_nothing_raised {
                osum = client.backup(file)
            }
            out
            assert_nothing_raised {
                tsum = client.backup(tmppath)
            }
            out

            # verify you got the same sum back for both
            assert(tsum == osum)

            # modify our tmp file
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
            who bash vim sh uname /etc/passwd /etc/syslog.conf /etc/hosts 
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
        @bucket = File.join(Puppet[:confdir], "buckettesting")

        @@tmpfiles << @bucket
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
            server = Puppet::Server::FileBucket.new(
                :Bucket => @bucket
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
            bucket = Puppet::Server::FileBucket.new(
                :Bucket => @bucket
            )
        }

        #sleep(30)
        assert_nothing_raised {
            client = Puppet::Client::Dipper.new(
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

        pid = mkserver(:CA => {}, :FileBucket => { :Bucket => @bucket})

        assert_nothing_raised {
            client = Puppet::Client::Dipper.new(
                :Server => "localhost",
                :Port => @@port
            )
        }

        checkfiles(client)

        unless pid
            raise "Uh, we don't have a child pid"
        end
        system("kill %s" % pid)
    end
end

# $Id$
