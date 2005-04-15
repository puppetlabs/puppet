# $Id$

unless defined? BlinkTestSuite
    $VERBOSE = true

    $:.unshift File.join(Dir.getwd, '../lib')

    class BlinkTestSuite
        attr_accessor :subdir

        def BlinkTestSuite.list
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
        textdir = File.join($blinkbase,"test","parser","text")
        files = Dir.entries(File.join(textdir)).reject { |file|
            file =~ %r{\.swp}
        }.reject { |file|
            file =~ %r{\.disabled}
        }.collect { |file|
            File.join(textdir,file)
        }.find_all { |file|
            FileTest.file?(file)
        }.sort.each { |file|
            puts "Processing %s" % file
            yield file
        }
    end
end
