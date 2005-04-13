# $Id$

unless defined? TestSuite
    $VERBOSE = true

    $:.unshift File.join(Dir.getwd, '../lib')

    class TestSuite
        attr_accessor :subdir

        def initialize(files)
            files.collect { |file|
                if file =~ /\.rb/
                    file
                else
                    "tc_" + file + ".rb"
                end
            }.sort { |a,b|
                File.stat(a) <=> File.stat(b)
            }.each { |file|
                require file
            }
        end
    end

    def textfiles
        files = Dir.entries("text").reject { |file|
            file =~ %r{\.swp}
        }.reject { |file|
            file =~ %r{\.disabled}
        }.collect { |file|
            File.join("text",file)
        }.find_all { |file|
            FileTest.file?(file)
        }.each { |file|
            yield file
        }
    end
end

if __FILE__ == $0 # if we're executing the top-level library...
    TestSuite.new(Dir.glob("ts_*"))
end
