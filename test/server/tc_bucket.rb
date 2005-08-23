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

# $Id$
class TestBucket < Test::Unit::TestCase
    def filelist
        files = []
            #/etc/passwd /etc/syslog.conf /etc/hosts
        %w{
            who /tmp/bigfile sh uname /etc/passwd /etc/syslog.conf /etc/hosts 
        }.each { |file|
            if file =~ /^\//
                if FileTest.exists?(file)
                    files.push file
                end
            else
                begin
                    path = %x{which #{file}}
                rescue => detail
                    #STDERR.puts "Could not search for binaries: %s" % detail
                    next
                end

                if path != ""
                    files.push path.chomp
                end
            end
        }

        return files
    end

    def setup
        if __FILE__ == $0
            Puppet[:loglevel] = :debug
        end

        @bucket = File::SEPARATOR + File.join("tmp","filebuckettesting")

        @@tmppids = []
        @@tmpfiles = [@bucket]
    end

    def teardown
        @@tmpfiles.each { |file|
            if FileTest.exists?(file)
                system("rm -rf %s" % file)
            end
        }
        @@tmppids.each { |pid|
            system("kill -INT %s" % pid)
        }
    end

    def test_localserver
        files = filelist()
        server =nil
        assert_nothing_raised {
            server = Puppet::Server::FileBucket.new(
                :Bucket => @bucket
            )
        }
        files.each { |file|
            contents = File.open(file) { |of| of.read }

            md5 = nil
            assert_nothing_raised {
                #STDERR.puts("adding %s" % file) if $debug
                md5 = server.addfile(Base64.encode64(contents),file)
            }
            newcontents = nil
            assert_nothing_raised {
                #STDERR.puts("getting %s" % file) if $debug
                newcontents = Base64.decode64(server.getfile(md5))
            }

            assert(
                contents == newcontents
            )
        }
    end

    def test_localboth
        files = filelist()

        tmpdir = File.join(@bucket,"tmpfiledir")
        Puppet.recmkdir(tmpdir)

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
        files.each { |file|
            name = File.basename(file)
            tmppath = File.join(tmpdir,name)

            # copy the files to our tmp directory so we can modify them...
            #STDERR.puts("copying %s" % file) if $debug
            File.open(tmppath,File::WRONLY|File::TRUNC|File::CREAT) { |wf|
                File.open(file) { |rf|
                    wf.print(rf.read)
                }
            }

            assert(FileTest.exists?(tmppath))

            osum = nil
            tsum = nil
            nsum = nil
            assert_nothing_raised {
                #STDERR.puts("backing up %s" % file) if $debug
                osum = client.backup(file)
            }
            assert_nothing_raised {
                #STDERR.puts("backing up %s" % tmppath) if $debug
                tsum = client.backup(tmppath)
            }

            assert(tsum == osum)

            File.open(tmppath,File::WRONLY|File::TRUNC) { |wf|
                wf.print "This is some test text\n"
            }
            assert_nothing_raised {
                #STDERR.puts("backing up %s" % tmppath) if $debug
                nsum = client.backup(tmppath)
            }

            assert(tsum != nsum)

            assert_nothing_raised {
                #STDERR.puts("restoring %s" % tmppath) if $debug
                nsum = client.restore(tmppath,tsum)
            }

            contents = File.open(tmppath) { |rf|
                #STDERR.puts("reading %s" % tmppath) if $debug
                rf.read
            }
            csum = Digest::MD5.hexdigest(contents)
            assert(tsum == csum)
        }
    end

    def test_webxmlmix
        files = filelist()

        tmpdir = File.join(@bucket,"tmpfiledir")
        Puppet.recmkdir(tmpdir)

        server = nil
        client = nil
        port = Puppet::Server::FileBucket::DEFAULTPORT
        serverthread = nil
        pid = fork {
            server = Puppet::Server.new(
                :Port => port,
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :FileBucket => {
                        :Bucket => @bucket,
                    }
                }
            )
            trap(:INT) { server.shutdown }
            trap(:TERM) { server.shutdown }
            server.start
        }
        @@tmppids << pid
        sleep 3

        assert_nothing_raised {
            client = Puppet::Client::Dipper.new(
                :Server => "localhost",
                :Port => port
            )
        }
        files.each { |file|
            name = File.basename(file)
            tmppath = File.join(tmpdir,name)

            # copy the files to our tmp directory so we can modify them...
            #STDERR.puts("copying %s" % file) if $debug
            File.open(tmppath,File::WRONLY|File::TRUNC|File::CREAT) { |wf|
                File.open(file) { |rf|
                    wf.print(rf.read)
                }
            }

            assert(FileTest.exists?(tmppath))

            osum = nil
            tsum = nil
            nsum = nil
            assert_nothing_raised {
                #STDERR.puts("backing up %s" % file) if $debug
                osum = client.backup(file)
            }
            assert_nothing_raised {
                #STDERR.puts("backing up %s" % tmppath) if $debug
                tsum = client.backup(tmppath)
            }

            assert(tsum == osum)

            File.open(tmppath,File::WRONLY|File::TRUNC) { |wf|
                wf.print "This is some test text\n"
            }
            assert_nothing_raised {
                #STDERR.puts("backing up %s" % tmppath) if $debug
                nsum = client.backup(tmppath)
            }

            assert(tsum != nsum)

            assert_nothing_raised {
                #STDERR.puts("restoring %s" % tmppath) if $debug
                nsum = client.restore(tmppath,tsum)
            }

            assert_equal(tsum, nsum)

            contents = File.open(tmppath) { |rf|
                #STDERR.puts("reading %s" % tmppath) if $debug
                rf.read
            }
            csum = Digest::MD5.hexdigest(contents)
            assert(tsum == csum)
        }

        unless pid
            raise "Uh, we don't have a child pid"
        end
        system("kill %s" % pid)
    end
end
