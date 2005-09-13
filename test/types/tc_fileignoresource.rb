if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $:.unshift "../../../../language/trunk/lib"
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'cgi'
require 'test/unit'
require 'fileutils'
require 'puppettest'

# $Id: $

class TestFileIgnoreSources < Test::Unit::TestCase
    include FileTesting
   
    def setup
        @@tmpfiles = []
        @@tmppids = []
        Puppet[:loglevel] = :debug if __FILE__ == $0
        Puppet[:checksumfile] = File.join(Puppet[:statedir], "checksumtestfile")
        begin
            initstorage
        rescue
            system("rm -rf %s" % Puppet[:checksumfile])
        end
    end

    def teardown
        clearstorage
        Puppet::Type.allclear
        @@tmppids.each { |pid|
            system("kill -INT %s" % pid)
        }
        @@tmpfiles.each { |file|
            if FileTest.exists?(file)
                system("chmod -R 755 %s" % file)
                system("rm -rf %s" % file)
            end
        }
        @@tmpfiles.clear
        system("rm -f %s" % Puppet[:checksumfile])
    end

#This is not needed unless using md5 (correct me if I'm wrong)
    def initstorage
        Puppet::Storage.init
        Puppet::Storage.load
    end

    def clearstorage
        Puppet::Storage.store
        Puppet::Storage.clear
    end

    def test_ignore_simple_source

      #Temp directory to run tests in
        path = "/tmp/Fileignoresourcetest"
        @@tmpfiles.push path

       #source directory
        sourcedir = "sourcedir"
        sourcefile1 = "sourcefile1"
        sourcefile2 = "sourcefile2"

        frompath = File.join(path,sourcedir)
        FileUtils.mkdir_p frompath

        topath = File.join(path,"destdir")
        FileUtils.mkdir topath

       #initialize variables before block
        tofile = nil
        trans = nil

       #create source files

      File.open(File.join(frompath,sourcefile1), File::WRONLY|File::CREAT|File::APPEND) { |of|
            of.puts "yayness"
        }
      
      File.open(File.join(frompath,sourcefile2), File::WRONLY|File::CREAT|File::APPEND) { |of|
            of.puts "even yayer"
        }
      

      #makes Puppet file Object
        assert_nothing_raised {
            tofile = Puppet::Type::PFile.new(
                :name => topath,
                :source => frompath,
                :recurse => true,                             
                :ignore => "sourcefile2"                            
            )
        }

      #make a component and adds the file
        comp = Puppet::Type::Component.new(
            :name => "component"
        )
        comp.push tofile

      #make, evaluate transaction and sync the component
        assert_nothing_raised {
            trans = comp.evaluate
        }
        assert_nothing_raised {
            trans.evaluate
        }
        assert_nothing_raised {
            comp.sync
        }
      
      #topath should exist as a directory with sourcedir as a directory
        newpath = File.join(topath, sourcedir)
        assert(FileTest.exists?(newpath))
       
      #This file should exist
        assert(FileTest.exists?(File.join(newpath,sourcefile1)))

      #This file should not
        assert(!(FileTest.exists?(File.join(newpath,sourcefile2))))

       puts "we made it"
     
        Puppet::Type.allclear
      
    end

    def test_ignore_with_wildcard
    end

    def test_ignore_complex
    end


end
