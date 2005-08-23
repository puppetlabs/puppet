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


$external = true
if ARGV[1] and ARGV[1] == "external"
    $external = true
else
    # default to external
    #$external = false
end
class TestBucket < Test::Unit::TestCase
    def debug(string)
        if $debug
            puts([Time.now,string].join(" "))
        end
    end

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
        @bucket = File::SEPARATOR + File.join("tmp","filebuckettesting")
    end

    def teardown
        system("rm -rf %s" % @bucket)
        if defined? $pid
            system("kill -9 #{$pid} 2>/dev/null")
        end
    end

    def test_localserver
        files = filelist()
        server =nil
        assert_nothing_raised {
            server = FileBucket::Bucket.new(
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
        FileBucket.mkdir(tmpdir)

        server = nil
        client = nil
        threads = []
        assert_nothing_raised {
            server = FileBucket::Bucket.new(
                :Bucket => @bucket
            )
        }

        #sleep(30)
        assert_nothing_raised {
            client = FileBucket::Dipper.new(
                :Bucket => server
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
        FileBucket.mkdir(tmpdir)

        server = nil
        client = nil
        port = FileBucket::DEFAULTPORT
        serverthread = nil
        pid = nil
        if $external
            $pid = fork {
                server = FileBucket::BucketWebserver.new(
                    :Bucket => @bucket,
                    :Port => port
                )
                trap(:INT) { server.shutdown }
                trap(:TERM) { server.shutdown }
                server.start
            }
            sleep 3
            #puts "pid is %s" % pid
            #exit
        else
            assert_nothing_raised {
                server = FileBucket::BucketWebserver.new(
                    :Bucket => @bucket,
                    :Port => port
                )
            }
            assert_nothing_raised() {
                trap(:INT) { server.shutdown }
                serverthread = Thread.new {
                    server.start
                }
            }
        end

        assert_nothing_raised {
            client = FileBucket::Dipper.new(
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

        if $external
            unless $pid
                raise "Uh, we don't have a child pid"
            end
            system("kill %s" % $pid)
        else
            server.shutdown

            # make sure everything's complete before we stop
            assert_nothing_raised() {
                serverthread.join(60)
            }
        end
    end
end
