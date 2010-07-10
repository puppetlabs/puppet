require 'puppettest'

module PuppetTest::FileTesting
  include PuppetTest
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
      redo if set.include?(item)

      ret.push item
    }
    ret
  end

  def mkranddirsandfiles(dirs = nil,files = nil,depth = 3)
    return if depth < 0

    dirs ||= %w{This Is A Set Of Directories}

    files ||= %w{and this is a set of files}

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
    list
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

    fromlist.sort.zip(tolist.sort).each { |a,b|
      assert_equal(a, b, "Fromfile #{a} with length #{fromlist.length} does not match tofile #{b} with length #{tolist.length}")
    }
    #assert_equal(fromlist,tolist)

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
        next unless yield path
        checked += 1
      end
    }
  end

  def delete_random_files(dir)
    deleted = []
    random_files(dir) { |file|
      stat = File.stat(file)
      begin
        if stat.ftype == "directory"
          false
        else
          deleted << file
          File.unlink(file)
          true
        end
      rescue => detail
        # we probably won't be able to open our own secured files
        puts detail
        false
      end
    }

    deleted
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
    added
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
    modded
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
    modded
  end

  def conffile
    exampledir("root/etc/configfile")
  end
end

