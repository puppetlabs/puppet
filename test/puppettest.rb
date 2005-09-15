# $Id$
require 'test/unit'

class TestPuppet < Test::Unit::TestCase
    def newcomp(name,*ary)
        comp = Puppet::Type::Component.new(
            :name => name
        )
        ary.each { |item| comp.push item }

        return comp
    end

    def setup
        if $0 =~ /tc_.+\.rb/
            Puppet[:loglevel] = :debug
        else
            Puppet[:logdest] = "/dev/null"
            Puppet[:httplog] = "/dev/null"
        end

        @configpath = File.join(tmpdir, self.class.to_s + "configdir")
        @oldconf = Puppet[:puppetconf]
        Puppet[:puppetconf] = @configpath
        @oldvar = Puppet[:puppetvar]
        Puppet[:puppetvar] = @configpath

        @@tmpfiles = [@configpath]
    end

    def teardown
        @@tmpfiles.each { |file|
            if FileTest.exists?(file)
                system("chmod -R 755 %s" % file)
                system("rm -rf %s" % file)
            end
        }
        @@tmpfiles.clear
        Puppet::Type.allclear
    end

    def tempfile
        File.join(self.tmpdir(), "puppetestfile%s" % rand(100))
    end

    def tmpdir
        unless defined? @tmpdir and @tmpdir
            @tmpdir = case Facter["operatingsystem"].value
            when "Darwin": "/private/tmp"
            else
                "/tmp"
            end
        end
        @tmpdir
    end

    def assert_rollback_events(trans, events, msg)
        run_events(:rollback, trans, events, msg)
    end

    def assert_events(comp, events, msg)
        trans = nil
        assert_nothing_raised("Component %s failed" % [msg]) {
            trans = comp.evaluate
        }

        run_events(:evaluate, trans, events, msg)
    end

    def run_events(type, trans, events, msg)
        case type
        when :evaluate, :rollback: # things are hunky-dory
        else
            raise Puppet::DevError, "Incorrect run_events type"
        end

        method = type

        newevents = nil
        assert_nothing_raised("Transaction %s %s failed" % [type, msg]) {
            newevents = trans.send(method).reject { |e| e.nil? }.collect { |e|
                e.event
            }
        }

        assert_equal(events, newevents, "Incorrect %s %s events" % [type, msg])

        return trans
    end

    def test_nothing
    end
end

unless defined? PuppetTestSuite
    $:.unshift File.join(Dir.getwd, '../lib')

    class PuppetTestSuite
        attr_accessor :subdir

        def self.list
            Dir.entries(".").find_all { |file|
                FileTest.directory?(file) and file !~ /^\./
            }
        end

        def initialize(name)
            unless FileTest.directory?(name)
                puts "TestSuites are directories containing test cases"
                puts "no such directory: %s" % name
                exit(65)
            end

            # load each of the files
            Dir.entries(name).collect { |file|
                File.join(name,file)
            }.find_all { |file|
                FileTest.file?(file) and file =~ /tc_.+\.rb$/
            }.sort { |a,b|
                # in the order they were modified, so the last modified files
                # are loaded and thus displayed last
                File.stat(b) <=> File.stat(a)
            }.each { |file|
                require file
            }
        end
    end

    def textfiles
        textdir = File.join($puppetbase,"examples","code")
        # only parse this one file now
        yield File.join(textdir,"head")
    end

    def failers
        textdir = File.join($puppetbase,"examples","code", "failers")
        # only parse this one file now
        files = Dir.entries(textdir).reject { |file|
            file =~ %r{\.swp}
        }.reject { |file|
            file =~ %r{\.disabled}
        }.collect { |file|
            File.join(textdir,file)
        }.find_all { |file|
            FileTest.file?(file)
        }.sort.each { |file|
            Puppet.debug "Processing %s" % file
            yield file
        }
    end

    module FileTesting
        def newcomp(name,*ary)
            comp = Puppet::Type::Component.new(
                :name => name
            )
            ary.each { |item| comp.push item }

            return comp
        end

        def cycle(comp)
            trans = nil
            assert_nothing_raised {
                trans = comp.evaluate
            }
            assert_nothing_raised {
                trans.evaluate
            }
        end

        def randlist(list)
            num = rand(4)
            if num == 0
                num = 1
            end
            set = []

            ret = []
            num.times { |index|
                item = list[rand(list.length)]
                if set.include?(item)
                    redo
                end

                ret.push item
            }
            return ret
        end

        def mkranddirsandfiles(dirs = nil,files = nil,depth = 3)
            if depth < 0
                return
            end

            unless dirs
                dirs = %w{This Is A Set Of Directories}
            end

            unless files
                files = %w{and this is a set of files}
            end

            tfiles = randlist(files)
            tdirs = randlist(dirs)

            tfiles.each { |file|
                File.open(file, "w") { |of|
                    4.times {
                        of.puts rand(100)
                    }
                }
            }

            tdirs.each { |dir|
                # it shouldn't already exist, but...
                unless FileTest.exists?(dir)
                    Dir.mkdir(dir)
                    FileUtils.cd(dir) {
                        mkranddirsandfiles(dirs,files,depth - 1)
                    }
                end
            }
        end

        def file_list(dir)
            list = nil
            FileUtils.cd(dir) {
                list = %x{find . 2>/dev/null}.chomp.split(/\n/)
            }
            return list
        end

        def assert_trees_equal(fromdir,todir)
            assert(FileTest.directory?(fromdir))
            assert(FileTest.directory?(todir))

            # verify the file list is the same
            fromlist = nil
            FileUtils.cd(fromdir) {
                fromlist = %x{find . 2>/dev/null}.chomp.split(/\n/).reject { |file|
                    ! FileTest.readable?(file)
                }.sort
            }
            tolist = file_list(todir).sort

            assert_equal(fromlist,tolist)

            # and then do some verification that the files are actually set up
            # the same
            checked = 0
            fromlist.each_with_index { |file,i|
                fromfile = File.join(fromdir,file)
                tofile = File.join(todir,file)
                fromstat = File.stat(fromfile)
                tostat = File.stat(tofile)
                [:ftype,:gid,:mode,:uid].each { |method|
                    assert_equal(
                        fromstat.send(method),
                        tostat.send(method)
                    )

                    next if fromstat.ftype == "directory"
                    if checked < 10 and i % 3 == 0
                        from = File.open(fromfile) { |f| f.read }
                        to = File.open(tofile) { |f| f.read }

                        assert_equal(from,to)
                        checked += 1
                    end
                }
            }
        end

        def random_files(dir)
            checked = 0
            list = file_list(dir)
            list.reverse.each_with_index { |file,i|
                path = File.join(dir,file)
                stat = File.stat(dir)
                if checked < 10 and (i % 3) == 2
                    unless yield path
                        next
                    end
                    checked += 1
                end
            }
        end

        def delete_random_files(dir)
            random_files(dir) { |file|
                stat = File.stat(file)
                begin
                    if stat.ftype == "directory"
                        false
                    else
                        File.unlink(file)
                        true
                    end
                rescue => detail
                    # we probably won't be able to open our own secured files
                    puts detail
                    false
                end
            }
        end

        def add_random_files(dir)
            added = []
            random_files(dir) { |file|
                stat = File.stat(file)
                begin
                    if stat.ftype == "directory"
                        name = File.join(file,"file" + rand(100).to_s)
                        File.open(name, "w") { |f|
                            f.puts rand(10)
                        }
                        added << name
                    else
                        false
                    end
                rescue => detail
                    # we probably won't be able to open our own secured files
                    puts detail
                    false
                end
            }
            return added
        end

        def modify_random_files(dir)
            modded = []
            random_files(dir) { |file|
                stat = File.stat(file)
                begin
                    if stat.ftype == "directory"
                        false
                    else
                        File.open(file, "w") { |f|
                            f.puts rand(10)
                        }
                        modded << name
                        true
                    end
                rescue => detail
                    # we probably won't be able to open our own secured files
                    puts detail
                    false
                end
            }
            return modded
        end

        def readonly_random_files(dir)
            modded = []
            random_files(dir) { |file|
                stat = File.stat(file)
                begin
                    if stat.ftype == "directory"
                        File.new(file).chmod(0111)
                    else
                        File.new(file).chmod(0000)
                    end
                    modded << file
                rescue => detail
                    # we probably won't be able to open our own secured files
                    puts detail
                    false
                end
            }
            return modded
        end
        def conffile
            File.join($puppetbase,"examples/root/etc/configfile")
        end

        def tempfile
            File.join(self.tmpdir(), "puppetestfile%s" % rand(100))
        end

    end

end
