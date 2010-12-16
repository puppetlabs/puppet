#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppettest/support/utils'
require 'fileutils'
require 'mocha'

class TestFile < Test::Unit::TestCase
  include PuppetTest::Support::Utils
  include PuppetTest::FileTesting

  def mkfile(hash)
    file = nil
    assert_nothing_raised {
      file = Puppet::Type.type(:file).new(hash)
    }
    file
  end

  def mktestfile
    tmpfile = tempfile
    File.open(tmpfile, "w") { |f| f.puts rand(100) }
    @@tmpfiles.push tmpfile
    mkfile(:name => tmpfile)
  end

  def setup
    super
    @file = Puppet::Type.type(:file)
    $method = @method_name
    Puppet[:filetimeout] = -1
    Facter.stubs(:to_hash).returns({})
  end

  def teardown
    system("rm -rf #{Puppet[:statefile]}")
    super
  end

  def initstorage
    Puppet::Util::Storage.init
    Puppet::Util::Storage.load
  end

  def clearstorage
    Puppet::Util::Storage.store
    Puppet::Util::Storage.clear
  end

  def test_owner
    file = mktestfile

    users = {}
    count = 0

    # collect five users
    Etc.passwd { |passwd|
      if count > 5
        break
      else
        count += 1
      end
      users[passwd.uid] = passwd.name
    }

    fake = {}
    # find a fake user
    while true
      a = rand(1000)
      begin
        Etc.getpwuid(a)
      rescue
        fake[a] = "fakeuser"
        break
      end
    end

    uid, name = users.shift
    us = {}
    us[uid] = name
    users.each { |uid, name|
      assert_apply(file)
      assert_nothing_raised {
        file[:owner] = name
      }
      assert_nothing_raised {
        file.retrieve
      }
      assert_apply(file)
    }
  end

  def test_group
    file = mktestfile
    [%x{groups}.chomp.split(/ /), Process.groups].flatten.each { |group|
      assert_nothing_raised {
        file[:group] = group
      }
      assert(file.property(:group))
      assert(file.property(:group).should)
    }
  end

  def test_groups_fails_when_invalid
    assert_raise(Puppet::Error, "did not fail when the group was empty") do
      Puppet::Type.type(:file).new :path => "/some/file", :group => ""
    end
  end

  if Puppet.features.root?
    def test_createasuser
      dir = tmpdir

      user = nonrootuser
      path = File.join(tmpdir, "createusertesting")
      @@tmpfiles << path

      file = nil
      assert_nothing_raised {

              file = Puppet::Type.type(:file).new(
                
          :path => path,
          :owner => user.name,
          :ensure => "file",
        
          :mode => "755"
        )
      }

      comp = mk_catalog("createusertest", file)

      assert_events([:file_created], comp)
    end

    def test_nofollowlinks
      basedir = tempfile
      Dir.mkdir(basedir)
      file = File.join(basedir, "file")
      link = File.join(basedir, "link")

      File.open(file, "w", 0644) { |f| f.puts "yayness"; f.flush }
      File.symlink(file, link)

      # First test 'user'
      user = nonrootuser

      inituser = File.lstat(link).uid
      File.lchown(inituser, nil, link)

      obj = nil
      assert_nothing_raised {

              obj = Puppet::Type.type(:file).new(
                
          :title => link,
        
          :owner => user.name
        )
      }
      obj.retrieve

      # Make sure it defaults to managing the link
      assert_events([:file_changed], obj)
      assert_equal(user.uid, File.lstat(link).uid)
      assert_equal(inituser, File.stat(file).uid)
      File.chown(inituser, nil, file)
      File.lchown(inituser, nil, link)

      # Try following
      obj[:links] = :follow
      assert_events([:file_changed], obj)
      assert_equal(user.uid, File.stat(file).uid)
      assert_equal(inituser, File.lstat(link).uid)

      # And then explicitly managing
      File.chown(inituser, nil, file)
      File.lchown(inituser, nil, link)
      obj[:links] = :manage
      assert_events([:file_changed], obj)
      assert_equal(user.uid, File.lstat(link).uid)
      assert_equal(inituser, File.stat(file).uid)

      obj.delete(:owner)
      obj[:links] = :follow

      # And then test 'group'
      group = nonrootgroup

      initgroup = File.stat(file).gid
      obj[:group] = group.name

      obj[:links] = :follow
      assert_events([:file_changed], obj)
      assert_equal(group.gid, File.stat(file).gid)
      File.chown(nil, initgroup, file)
      File.lchown(nil, initgroup, link)

      obj[:links] = :manage
      assert_events([:file_changed], obj)
      assert_equal(group.gid, File.lstat(link).gid)
      assert_equal(initgroup, File.stat(file).gid)
    end

    def test_ownerasroot
      file = mktestfile

      users = {}
      count = 0

      # collect five users
      Etc.passwd { |passwd|
        if count > 5
          break
        else
          count += 1
        end
        next if passwd.uid < 0
        users[passwd.uid] = passwd.name
      }

      fake = {}
      # find a fake user
      while true
        a = rand(1000)
        begin
          Etc.getpwuid(a)
        rescue
          fake[a] = "fakeuser"
          break
        end
      end

      users.each { |uid, name|
        assert_nothing_raised {
          file[:owner] = name
        }
        assert_apply(file)
        currentvalue = file.retrieve
        assert(file.insync?(currentvalue))
        assert_nothing_raised {
          file[:owner] = uid
        }
        assert_apply(file)
        currentvalue = file.retrieve
        # make sure changing to number doesn't cause a sync
        assert(file.insync?(currentvalue))
      }

      # We no longer raise an error here, because we check at run time
      #fake.each { |uid, name|
      #    assert_raise(Puppet::Error) {
      #        file[:owner] = name
      #    }
      #    assert_raise(Puppet::Error) {
      #        file[:owner] = uid
      #    }
      #}
    end

    def test_groupasroot
      file = mktestfile
      [%x{groups}.chomp.split(/ /), Process.groups].flatten.each { |group|
        next unless Puppet::Util.gid(group) # grr.
        assert_nothing_raised {
          file[:group] = group
        }
        assert(file.property(:group))
        assert(file.property(:group).should)
        assert_apply(file)
        currentvalue = file.retrieve
        assert(file.insync?(currentvalue))
        assert_nothing_raised {
          file.delete(:group)
        }
      }
    end

    if Facter.value(:operatingsystem) == "Darwin"
      def test_sillyowner
        file = tempfile
        File.open(file, "w") { |f| f.puts "" }
        File.chown(-2, nil, file)

        assert(File.stat(file).uid > 120000, "eh?")
        user = nonrootuser

              obj = Puppet::Type.newfile(
                
          :path => file,
        
          :owner => user.name
        )

        assert_apply(obj)

        assert_equal(user.uid, File.stat(file).uid)
      end
    end
  else
    $stderr.puts "Run as root for complete owner and group testing"
  end

  def test_create
    %w{a b c d}.collect { |name| tempfile + name.to_s }.each { |path|
      file =nil
      assert_nothing_raised {

              file = Puppet::Type.type(:file).new(
                
          :name => path,
        
          :ensure => "file"
        )
      }
      assert_events([:file_created], file)
      assert_events([], file)
      assert(FileTest.file?(path), "File does not exist")
      @@tmpfiles.push path
    }
  end

  def test_create_dir
    basedir = tempfile
    Dir.mkdir(basedir)
    %w{a b c d}.collect { |name| "#{basedir}/#{name}" }.each { |path|
      file = nil
      assert_nothing_raised {

              file = Puppet::Type.type(:file).new(
                
          :name => path,
        
          :ensure => "directory"
        )
      }
      assert(! FileTest.directory?(path), "Directory #{path} already exists")
      assert_events([:directory_created], file)
      assert_events([], file)
      assert(FileTest.directory?(path))
      @@tmpfiles.push path
    }
  end

  def test_modes
    file = mktestfile
    # Set it to something else initially
    File.chmod(0775, file.title)
    [0644,0755,0777,0641].each { |mode|
      assert_nothing_raised {
        file[:mode] = mode
      }
      assert_events([:mode_changed], file)
      assert_events([], file)

      assert_nothing_raised {
        file.delete(:mode)
      }
    }
  end

  def cyclefile(path)
    # i had problems with using :name instead of :path
    [:name,:path].each { |param|
      file = nil
      changes = nil
      comp = nil
      trans = nil

      initstorage
      assert_nothing_raised {

              file = Puppet::Type.type(:file).new(
                
          param => path,
          :recurse => true,
        
          :checksum => "md5"
        )
      }
      comp = Puppet::Type.type(:component).new(
        :name => "component"
      )
      comp.push file
      assert_nothing_raised {
        trans = comp.evaluate
      }
      assert_nothing_raised {
        trans.evaluate
      }
      clearstorage
      Puppet::Type.allclear
    }
  end

  def test_filetype_retrieval
    file = nil

    # Verify it retrieves files of type directory
    assert_nothing_raised {

            file = Puppet::Type.type(:file).new(
                
        :name => tmpdir,
        
        :check => :type
      )
    }

    assert_equal("directory", file.property(:type).retrieve)

    # And then check files
    assert_nothing_raised {

            file = Puppet::Type.type(:file).new(
                
        :name => tempfile,
        
        :ensure => "file"
      )
    }

    assert_apply(file)
    file[:check] = "type"
    assert_apply(file)

    assert_equal("file", file.property(:type).retrieve)
  end

  def test_path
    dir = tempfile

    path = File.join(dir, "subdir")

    assert_nothing_raised("Could not make file") {
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "w") { |f| f.puts "yayness" }
    }

    file = nil
    dirobj = nil
    assert_nothing_raised("Could not make file object") {

            dirobj = Puppet::Type.type(:file).new(
                
        :path => dir,
        :recurse => true,
        
        :check => %w{mode owner group}
      )
    }
    catalog = mk_catalog dirobj
    transaction = Puppet::Transaction.new(catalog)
    transaction.eval_generate(dirobj)

    #assert_nothing_raised {
    #    dirobj.eval_generate
    #}

    file = catalog.resource(:file, path)

    assert(file, "Could not retrieve file object")

    assert_equal("/#{file.ref}", file.path)
  end

  def test_autorequire
    basedir = tempfile
    subfile = File.join(basedir, "subfile")


          baseobj = Puppet::Type.type(:file).new(
                
      :name => basedir,
        
      :ensure => "directory"
    )


          subobj = Puppet::Type.type(:file).new(
                
      :name => subfile,
        
      :ensure => "file"
    )
    catalog = mk_catalog(baseobj, subobj)
    edge = nil
    assert_nothing_raised do
      edge = subobj.autorequire.shift
    end
    assert_equal(baseobj, edge.source, "file did not require its parent dir")
    assert_equal(subobj, edge.target, "file did not require its parent dir")
  end

  # Unfortunately, I know this fails
  def disabled_test_recursivemkdir
    path = tempfile
    subpath = File.join(path, "this", "is", "a", "dir")
    file = nil
    assert_nothing_raised {

            file = Puppet::Type.type(:file).new(
                
        :name => subpath,
        :ensure => "directory",
        
        :recurse => true
      )
    }

    comp = mk_catalog("yay", file)
    comp.finalize
    assert_apply(comp)
    #assert_events([:directory_created], comp)

    assert(FileTest.directory?(subpath), "Did not create directory")
  end

  # Make sure that content updates the checksum on the same run
  def test_checksumchange_for_content
    dest = tempfile
    File.open(dest, "w") { |f| f.puts "yayness" }

    file = nil
    assert_nothing_raised {

            file = Puppet::Type.type(:file).new(
                
        :name => dest,
        :checksum => "md5",
        :content => "This is some content",
        
        :backup => false
      )
    }

    file.retrieve

    assert_events([:content_changed], file)
    file.retrieve
    assert_events([], file)
  end

  # Make sure that content updates the checksum on the same run
  def test_checksumchange_for_ensure
    dest = tempfile

    file = nil
    assert_nothing_raised {

            file = Puppet::Type.type(:file).new(
                
        :name => dest,
        :checksum => "md5",
        
        :ensure => "file"
      )
    }

    file.retrieve

    assert_events([:file_created], file)
    file.retrieve
    assert_events([], file)
  end

  def test_nameandpath
    path = tempfile

    file = nil
    assert_nothing_raised {

            file = Puppet::Type.type(:file).new(
                
        :title => "fileness",
        :path => path,
        
        :content => "this is some content"
      )
    }

    assert_apply(file)

    assert(FileTest.exists?(path))
  end

  # Make sure that a missing group isn't fatal at object instantiation time.
  def test_missinggroup
    file = nil
    assert_nothing_raised {

            file = Puppet::Type.type(:file).new(
                
        :path => tempfile,
        
        :group => "fakegroup"
      )
    }

    assert(file.property(:group), "Group property failed")
  end

  def test_modecreation
    path = tempfile

          file = Puppet::Type.type(:file).new(
                
      :path => path,
      :ensure => "file",
        
      :mode => "0777"
    )
    assert_equal("777", file.should(:mode), "Mode did not get set correctly")
    assert_apply(file)
    assert_equal(0777, File.stat(path).mode & 007777, "file mode is incorrect")
    File.unlink(path)
    file[:ensure] = "directory"
    assert_apply(file)
    assert_equal(0777, File.stat(path).mode & 007777, "directory mode is incorrect")
  end

  # If both 'ensure' and 'content' are used, make sure that all of the other
  # properties are handled correctly.
  def test_contentwithmode
    path = tempfile

    file = nil
    assert_nothing_raised {

            file = Puppet::Type.type(:file).new(
                
        :path => path,
        :ensure => "file",
        :content => "some text\n",
        
        :mode => 0755
      )
    }

    assert_apply(file)
    assert_equal("%o" % 0755, "%o" % (File.stat(path).mode & 007777))
  end

  def test_replacefilewithlink
    path = tempfile
    link = tempfile

    File.open(path, "w") { |f| f.puts "yay" }
    File.open(link, "w") { |f| f.puts "a file" }

    file = nil
    assert_nothing_raised {

            file = Puppet::Type.type(:file).new(
                
        :ensure => path,
        :path => link,
        
        :backup => false
      )
    }

    assert_events([:link_created], file)

    assert(FileTest.symlink?(link), "Link was not created")

    assert_equal(path, File.readlink(link), "Link was created incorrectly")
  end

  def test_file_with_spaces
    dir = tempfile
    Dir.mkdir(dir)
    source = File.join(dir, "file spaces")
    dest = File.join(dir, "another space")

    File.open(source, "w") { |f| f.puts :yay }

          obj = Puppet::Type.type(:file).new(
                
      :path => dest,
        
      :source => source
    )
    assert(obj, "Did not create file")

    assert_apply(obj)

    assert(FileTest.exists?(dest), "File did not get created")
  end

  # Testing #274.  Make sure target can be used without 'ensure'.
  def test_target_without_ensure
    source = tempfile
    dest = tempfile
    File.open(source, "w") { |f| f.puts "funtest" }

    obj = nil
    assert_nothing_raised {
      obj = Puppet::Type.newfile(:path => dest, :target => source)
    }

    assert_apply(obj)
  end

  def test_autorequire_owner_and_group
    file = tempfile
    comp = nil
    user = nil
    group =nil
    home = nil
    ogroup = nil
    assert_nothing_raised {

            user = Puppet::Type.type(:user).new(
                
        :name => "pptestu",
        :home => file,
        
        :gid => "pptestg"
      )

            home = Puppet::Type.type(:file).new(
                
        :path => file,
        :owner => "pptestu",
        :group => "pptestg",
        
        :ensure => "directory"
      )
      group = Puppet::Type.type(:group).new(
        :name => "pptestg"
      )
      comp = mk_catalog(user, group, home)
    }

    # Now make sure we get a relationship for each of these
    rels = nil
    assert_nothing_raised { rels = home.autorequire }
    assert(rels.detect { |e| e.source == user }, "owner was not autorequired")
    assert(rels.detect { |e| e.source == group }, "group was not autorequired")
  end

  # Testing #309 -- //my/file => /my/file
  def test_slash_deduplication
    ["/my/////file/for//testing", "/my/file/for/testing///",
      "/my/file/for/testing"].each do |path|
      file = nil
      assert_nothing_raised do
        file = Puppet::Type.newfile(:path => path)
      end

      assert_equal("/my/file/for/testing", file[:path])
    end
  end

  if Process.uid == 0
  # Testing #364.
  def test_writing_in_directories_with_no_write_access
    # Make a directory that our user does not have access to
    dir = tempfile
    Dir.mkdir(dir)

    # Get a fake user
    user = nonrootuser
    # and group
    group = nonrootgroup

    # First try putting a file in there
    path = File.join(dir, "file")
    file = Puppet::Type.newfile :path => path, :owner => user.name, :group => group.name, :content => "testing"

    # Make sure we can create it
    assert_apply(file)
    assert(FileTest.exists?(path), "File did not get created")
    # And that it's owned correctly
    assert_equal(user.uid, File.stat(path).uid, "File has the wrong owner")
    assert_equal(group.gid, File.stat(path).gid, "File has the wrong group")

    assert_equal("testing", File.read(path), "file has the wrong content")

    # Now make a dir
    subpath = File.join(dir, "subdir")
    subdir = Puppet::Type.newfile :path => subpath, :owner => user.name, :group => group.name, :ensure => :directory
    # Make sure we can create it
    assert_apply(subdir)
    assert(FileTest.directory?(subpath), "File did not get created")
    # And that it's owned correctly
    assert_equal(user.uid, File.stat(subpath).uid, "File has the wrong owner")
    assert_equal(group.gid, File.stat(subpath).gid, "File has the wrong group")

    assert_equal("testing", File.read(path), "file has the wrong content")
  end
  end

  # #366
  def test_replace_aliases
    file = Puppet::Type.newfile :path => tempfile
    file[:replace] = :yes
    assert_equal(:true, file[:replace], ":replace did not alias :true to :yes")
    file[:replace] = :no
    assert_equal(:false, file[:replace], ":replace did not alias :false to :no")
  end

  def test_pathbuilder
    dir = tempfile
    Dir.mkdir(dir)
    file = File.join(dir, "file")
    File.open(file, "w") { |f| f.puts "" }
    obj = Puppet::Type.newfile :path => dir, :recurse => true, :mode => 0755
    catalog = mk_catalog obj
    transaction = Puppet::Transaction.new(catalog)

    assert_equal("/#{obj.ref}", obj.path)

    list = transaction.eval_generate(obj)
    fileobj = catalog.resource(:file, file)
    assert(fileobj, "did not generate file object")
    assert_equal("/#{fileobj.ref}", fileobj.path, "did not generate correct subfile path")
  end

  # Testing #403
  def test_removal_with_content_set
    path = tempfile
    File.open(path, "w") { |f| f.puts "yay" }
    file = Puppet::Type.newfile(:name => path, :ensure => :absent, :content => "foo", :backup => false)

    assert_apply(file)
    assert(! FileTest.exists?(path), "File was not removed")
  end

  # Testing #438
  def test_creating_properties_conflict
    file = tempfile
    first = tempfile
    second = tempfile
    params = [:content, :source, :target]
    params.each do |param|
      assert_nothing_raised("#{param} conflicted with ensure") do
        Puppet::Type.newfile(:path => file, param => first, :ensure => :file)
      end
      params.each do |other|
        next if other == param
        assert_raise(Puppet::Error, "#{param} and #{other} did not conflict") do
          Puppet::Type.newfile(:path => file, other => first, param => second)
        end
      end
    end
  end

  # Testing #508
  if Process.uid == 0
  def test_files_replace_with_right_attrs
    source = tempfile
    File.open(source, "w") { |f|
      f.puts "some text"
    }
    File.chmod(0755, source)
    user = nonrootuser
    group = nonrootgroup
    path = tempfile
    good = {:uid => user.uid, :gid => group.gid, :mode => 0640}

    run = Proc.new do |obj, msg|
      assert_apply(obj)
      stat = File.stat(obj[:path])
      good.each do |should, sval|
        if should == :mode
          current = filemode(obj[:path])
        else
          current = stat.send(should)
        end
        assert_equal(sval, current, "Attr #{should} was not correct #{msg}")
      end
    end


          file = Puppet::Type.newfile(
        :path => path, :owner => user.name,
        
      :group => group.name, :mode => 0640, :backup => false)
    {:source => source, :content => "some content"}.each do |attr, value|
      file[attr] = value
      # First create the file
      run.call(file, "upon creation with #{attr}")

      # Now change something so that we replace the file
      case attr
      when :source
          File.open(source, "w") { |f| f.puts "some different text" }
      when :content; file[:content] = "something completely different"
      else
        raise "invalid attr #{attr}"
      end

      # Run it again
      run.call(file, "after modification with #{attr}")

      # Now remove the file and the attr
      file.delete(attr)
      File.unlink(path)
    end
  end
  end

  def test_root_dir_is_named_correctly
    obj = Puppet::Type.newfile(:path => '/', :mode => 0755)
    assert_equal("/", obj.title, "/ directory was changed to empty string")
  end

end
