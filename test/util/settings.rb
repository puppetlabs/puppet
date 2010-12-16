#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'mocha'
require 'puppettest'
require 'puppet/util/settings'
require 'puppettest/parsertesting'

class TestSettings < Test::Unit::TestCase
  include PuppetTest
  include PuppetTest::ParserTesting
  Setting = Puppet::Util::Settings::Setting
  BooleanSetting = Puppet::Util::Settings::BooleanSetting

  def setup
    super
    @config = mkconfig
  end

  def set_configs(config = nil)
    config ||= @config

      config.setdefaults(
        "main",
      :one => ["a", "one"],
      :two => ["a", "two"],
      :yay => ["/default/path", "boo"],
      :mkusers => [true, "uh, yeah"],

      :name => ["testing", "a"]
    )


      config.setdefaults(
        "section1",
      :attr => ["a", "one"],
      :attrdir => ["/another/dir", "two"],

      :attr3 => ["$attrdir/maybe", "boo"]
    )
  end

  def check_for_users
    count = Puppet::Type.type(:user).inject(0) { |c,o|
      c + 1
    }
    assert(count > 0, "Found no users")
  end

  def test_to_config
    set_configs

    newc = mkconfig
    set_configs(newc)

    # Reset all of the values, so we know they're changing.
    newc.each do |name, obj|
      next if name == :name
      newc[name] = true
    end

    newfile = tempfile
    File.open(newfile, "w") { |f|
      @config.to_config.split("\n").each do |line|
        # Uncomment the settings, so they actually take.
        if line =~ / = /
          f.puts line.sub(/^\s*#/, '')
        else
          f.puts line
        end
      end
    }

    newc.setdefaults :section, :config => [newfile, "eh"]

    assert_nothing_raised("Could not parse generated configuration") {
      newc.parse
    }

    @config.each do |name, object|
      assert_equal(@config[name], newc[name], "Parameter #{name} is not the same")
    end
  end

  def mkconfig
    c = Puppet::Util::Settings.new
    c.setdefaults :main, :noop => [false, "foo"]
    c
  end

  def test_addbools
    assert_nothing_raised {
      @config.setdefaults(:testing, :booltest => [true, "testing"])
    }

    assert(@config[:booltest])
    @config = mkconfig

    assert_nothing_raised {
      @config.setdefaults(:testing, :booltest => ["true", "testing"])
    }

    assert(@config[:booltest])

    assert_nothing_raised {
      @config[:booltest] = false
    }

    assert(! @config[:booltest], "Booltest is not false")

    assert_nothing_raised {
      @config[:booltest] = "false"
    }

    assert(! @config[:booltest], "Booltest is not false")

    assert_raise(ArgumentError) {
      @config[:booltest] = "yayness"
    }

    assert_raise(ArgumentError) {
      @config[:booltest] = "/some/file"
    }
  end

  def test_strings
    val = "this is a string"
    assert_nothing_raised {
      @config.setdefaults(:testing, :strtest => [val, "testing"])
    }

    assert_equal(val, @config[:strtest])

    # Verify that variables are interpolated
    assert_nothing_raised {
      @config.setdefaults(:testing, :another => ["another $strtest", "testing"])
    }

    assert_equal("another #{val}", @config[:another])
  end

  def test_files
    c = mkconfig

    parent = "/puppet"
    assert_nothing_raised {
      @config.setdefaults(:testing, :parentdir => [parent, "booh"])
    }

    assert_nothing_raised {
      @config.setdefaults(:testing, :child => ["$parent/child", "rah"])
    }

    assert_equal(parent, @config[:parentdir])
    assert_equal("/puppet/child", File.join(@config[:parentdir], "child"))
  end

  def test_getset
    initial = "an initial value"
    assert_raise(ArgumentError) {
      @config[:yayness] = initial
    }

    default = "this is a default"
    assert_nothing_raised {
      @config.setdefaults(:testing, :yayness => [default, "rah"])
    }

    assert_equal(default, @config[:yayness])

    assert_nothing_raised {
      @config[:yayness] = initial
    }

    assert_equal(initial, @config[:yayness])

    assert_nothing_raised {
      @config.clear
    }

    assert_equal(default, @config[:yayness], "'clear' did not remove old values")

    assert_nothing_raised {
      @config[:yayness] = "not default"
    }
    assert_equal("not default", @config[:yayness])
  end

  def test_parse_file
    text = %{
      one = this is a test
      two = another test
      owner = root
      group = root
      yay = /a/path

      [main]
  four = five
  six = seven

[section1]
  attr = value
  owner = puppet
  group = puppet
  attrdir = /some/dir
  attr3 = $attrdir/other
    }

    file = tempfile
    File.open(file, "w") { |f| f.puts text }

    result = nil
    assert_nothing_raised {
      result = @config.send(:parse_file, file)
    }

    main = result[:main]
    assert(main, "Did not get section for main")
    {
      :one => "this is a test",
      :two => "another test",
      :owner => "root",
      :group => "root",
      :yay => "/a/path",
      :four => "five",
      :six => "seven"
    }.each do |param, value|
      assert_equal(value, main[param], "Param #{param} was not set correctly in main")
    end

    section1 = result[:section1]
    assert(section1, "Did not get section1")

    {
      :attr => "value",
      :owner => "puppet",
      :group => "puppet",
      :attrdir => "/some/dir",
      :attr3 => "$attrdir/other"
    }.each do |param, value|
      assert_equal(value, section1[param], "Param #{param} was not set correctly in section1")
    end
  end

  def test_arghandling
    c = mkconfig

    assert_nothing_raised {

      @config.setdefaults(
        "testing",
        :onboolean => [true, "An on bool"],
        :offboolean => [false, "An off bool"],
        :string => ["a string", "A string arg"],

        :file => ["/path/to/file", "A file arg"]
      )
    }

    data = {
      :onboolean => [true, false],
      :offboolean => [true, false],
      :string => ["one string", "another string"],
      :file => %w{/a/file /another/file}
    }
    data.each { |param, values|
      values.each { |val|
        opt = nil
        arg = nil
        if @config.boolean?(param)
          if val
            opt = "--#{param}"
          else
            opt = "--no-#{param}"
          end
        else
          opt = "--#{param}"
          arg = val
        end

        assert_nothing_raised("Could not handle arg #{opt} with value #{val}") {

          @config.handlearg(opt, arg)
        }
      }
    }
  end

  def test_addargs

    @config.setdefaults(
      "testing",
        :onboolean => [true, "An on bool"],
        :offboolean => [false, "An off bool"],
        :string => ["a string", "A string arg"],

        :file => ["/path/to/file", "A file arg"]
        )

    should = []
    @config.each { |name, element|
      element.expects(:getopt_args).returns([name])
      should << name
    }
    result = []
    assert_nothing_raised("Add args failed") do
      @config.addargs(result)
    end
    assert_equal(should, result, "Did not call addargs correctly.")

  end

  def test_addargs_functional
    @config = Puppet::Util::Settings.new


      @config.setdefaults(
        "testing",
          :onboolean => [true, "An on bool"],

          :string => ["a string", "A string arg"]
          )
    result = []
    should = []
    assert_nothing_raised("Add args failed") do
      @config.addargs(result)
    end
    @config.each do |name, element|
      if name == :onboolean
        should << ["--onboolean", GetoptLong::NO_ARGUMENT]
        should << ["--no-onboolean", GetoptLong::NO_ARGUMENT]
      elsif name == :string
        should << ["--string", GetoptLong::REQUIRED_ARGUMENT]
      end
    end
    assert_equal(should, result, "Add args functional test failed")
  end

  def test_groupsetting
    cfile = tempfile

    group = "yayness"

    File.open(cfile, "w") do |f|
      f.puts "[main]
      group = #{group}
      "
    end

    config = mkconfig
    config.setdefaults(Puppet[:name], :group => ["puppet", "a group"], :config => [cfile, "eh"])

    assert_nothing_raised {
      config.parse
    }

    assert_equal(group, config[:group], "Group did not take")
  end

  # provide a method to modify and create files w/out specifying the info
  # already stored in a config
  def test_writingfiles
    File.umask(0022)

    path = tempfile
    mode = 0644

    config = mkconfig

    args = { :default => path, :mode => mode, :desc => "yay" }

    user = nonrootuser
    group = nonrootgroup

    if Puppet.features.root?
      args[:owner] = user.name
      args[:group] = group.name
    end

    config.setdefaults(:testing, :myfile => args)

    assert_nothing_raised {
      config.write(:myfile) do |file|
        file.puts "yay"
      end
    }

    assert_equal(mode, filemode(path), "Modes are not equal")

    # OS X is broken in how it chgrps files
    if Puppet.features.root?
      assert_equal(user.uid, File.stat(path).uid, "UIDS are not equal")

      case Facter["operatingsystem"].value
      when /BSD/, "Darwin" # nothing
      else
        assert_equal(group.gid, File.stat(path).gid, "GIDS are not equal")
      end
    end
  end

  def test_mkdir
    File.umask(0022)

    path = tempfile
    mode = 0755

    config = mkconfig

    args = { :default => path, :mode => mode, :desc => "a file" }

    user = nonrootuser
    group = nonrootgroup

    if Puppet.features.root?
      args[:owner] = user.name
      args[:group] = group.name
    end

    config.setdefaults(:testing, :mydir => args)

    assert_nothing_raised {
      config.mkdir(:mydir)
    }

    assert_equal(mode, filemode(path), "Modes are not equal")


    # OS X and *BSD is broken in how it chgrps files
    if Puppet.features.root?
      assert_equal(user.uid, File.stat(path).uid, "UIDS are not equal")

      case Facter["operatingsystem"].value
      when /BSD/, "Darwin" # nothing
      else
        assert_equal(group.gid, File.stat(path).gid, "GIDS are not equal")
      end
    end
  end

  # Make sure that tags are ignored when configuring
  def test_configs_ignore_tags
    config = mkconfig
    file = tempfile


      config.setdefaults(
        :mysection,

      :mydir => [file, "a file"]
    )

    Puppet[:tags] = "yayness"

    assert_nothing_raised {
      config.use(:mysection)
    }

    assert(FileTest.directory?(file), "Directory did not get created")


      assert_equal(
        "yayness", Puppet[:tags],

      "Tags got changed during config")
  end

  def test_configs_replace_in_url
    config = mkconfig

    config.setdefaults(:mysection, :host => ["yayness", "yay"])
    config.setdefaults(:mysection, :url => ["http://$host/rahness", "yay"])

    val = nil
    assert_nothing_raised {
      val = config[:url]
    }


      assert_equal(
        "http://yayness/rahness", val,

      "Settings got messed up")
  end

  def test_correct_type_assumptions
    file = Puppet::Util::Settings::FileSetting
    setting = Puppet::Util::Settings::Setting
    bool = Puppet::Util::Settings::BooleanSetting

    # We have to keep these ordered, unfortunately.
    [
      ["/this/is/a/file", file],
      ["true", bool],
      [true, bool],
      ["false", bool],
      ["server", setting],
      ["http://$server/yay", setting],
      ["$server/yayness", file],
      ["$server/yayness.conf", file]
    ].each do |ary|
      config = mkconfig
      value, type = ary
      name = value.to_s + "_setting"
      assert_nothing_raised {
        config.setdefaults(:yayness, name => { :default => value, :desc => name.to_s})
      }
      elem = config.setting(name)


        assert_instance_of(
          type, elem,

          "#{value.inspect} got created as wrong type")
    end
  end

  def test_parse_removes_quotes
    config = mkconfig
    config.setdefaults(:mysection, :singleq => ["single", "yay"])
    config.setdefaults(:mysection, :doubleq => ["double", "yay"])
    config.setdefaults(:mysection, :none => ["noquote", "yay"])
    config.setdefaults(:mysection, :middle => ["midquote", "yay"])

    file = tempfile
    # Set one parameter in the file
    File.open(file, "w") { |f|
      f.puts %{[main]\n
  singleq = 'one'
  doubleq = "one"
  none = one
  middle = mid"quote
}
  }

  config.setdefaults(:mysection, :config => [file, "eh"])

  assert_nothing_raised {
    config.parse
    }

    %w{singleq doubleq none}.each do |p|
      assert_equal("one", config[p], "#{p} did not match")
    end
    assert_equal('mid"quote', config["middle"], "middle did not match")
  end

  # Test that config parameters correctly call passed-in blocks when the value
  # is set.
  def test_paramblocks
    config = mkconfig

    testing = nil
    assert_nothing_raised do
      config.setdefaults :test, :blocktest => {:default => "yay", :desc => "boo", :hook => proc { |value| testing = value }}
    end
    elem = config.setting(:blocktest)

    assert_nothing_raised do
      assert_equal("yay", elem.value)
    end

    assert_nothing_raised do
      config[:blocktest] = "yaytest"
    end

    assert_nothing_raised do
      assert_equal("yaytest", elem.value)
    end
    assert_equal("yaytest", testing)

    assert_nothing_raised do
      config[:blocktest] = "another"
    end

    assert_nothing_raised do
      assert_equal("another", elem.value)
    end
    assert_equal("another", testing)

    # Now verify it works from setdefault
    assert_nothing_raised do
      config.setdefaults :test,
        :blocktest2 => {
          :default => "yay",
          :desc => "yay",
          :hook => proc { |v| testing = v }
        }
    end

    assert_equal("yay", config[:blocktest2])

    assert_nothing_raised do
      config[:blocktest2] = "footest"
    end
    assert_equal("footest", config[:blocktest2])
    assert_equal("footest", testing)
  end

  def test_no_modify_root
    config = mkconfig

      config.setdefaults(
        :yay,
      :mydir => {:default => tempfile,

        :mode => 0644,
        :owner => "root",
        :group => "service",
        :desc => "yay"
      },
      :mkusers => [false, "yay"]
    )

    assert_nothing_raised do
      config.use(:yay)
    end

    # Now enable it so they'll be added
    config[:mkusers] = true

    comp = config.to_catalog

    comp.vertices.find_all { |r| r.class.name == :user }.each do |u|
      assert(u.name != "root", "Tried to manage root user")
    end
    comp.vertices.find_all { |r| r.class.name == :group }.each do |u|
      assert(u.name != "root", "Tried to manage root group")
      assert(u.name != "wheel", "Tried to manage wheel group")
    end

#        assert(yay, "Did not find yay component")
#        yay.each do |c|
#            puts @config.ref
#        end
#        assert(! yay.find { |o| o.class.name == :user and o.name == "root" },
#            "Found root user")
#        assert(! yay.find { |o| o.class.name == :group and o.name == "root" },
#            "Found root group")
  end

  # #415
  def test_remove_trailing_spaces
    config = mkconfig
    file = tempfile
    File.open(file, "w") { |f| f.puts "rah = something " }

    config.setdefaults(:yay, :config => [file, "eh"], :rah => ["testing", "a desc"])

    assert_nothing_raised { config.parse }
    assert_equal("something", config[:rah], "did not remove trailing whitespace in parsing")
  end

  # #484
  def test_parsing_unknown_variables
    logstore
    config = mkconfig
    file = tempfile
    File.open(file, "w") { |f|
      f.puts %{[main]\n
        one = one
        two = yay
      }
    }

    config.setdefaults(:mysection, :config => [file, "eh"], :one => ["yay", "yay"])

    assert_nothing_raised("Unknown parameter threw an exception") do
      config.parse
    end
  end

  def test_multiple_interpolations

    @config.setdefaults(
      :section,
      :one => ["oneval", "yay"],
      :two => ["twoval", "yay"],

      :three => ["$one/$two", "yay"]
    )


      assert_equal(
        "oneval/twoval", @config[:three],

      "Did not interpolate multiple variables")
  end

  # Make sure we can replace ${style} var names
  def test_curly_replacements

    @config.setdefaults(
      :section,
      :one => ["oneval", "yay"],
      :two => ["twoval", "yay"],

      :three => ["$one/${two}/${one}/$two", "yay"]
    )


      assert_equal(
        "oneval/twoval/oneval/twoval", @config[:three],

      "Did not interpolate curlied variables")
  end

  # Test to make sure that we can set and get a short name
  def test_setting_short_name
    setting= nil
    assert_nothing_raised("Could not create setting") do
      setting= Setting.new :short => "n", :desc => "anything", :settings => Puppet::Util::Settings.new
    end
    assert_equal("n", setting.short, "Short value is not retained")

    assert_raise(ArgumentError,"Allowed multicharactered short names.") do
      setting= Setting.new :short => "no", :desc => "anything", :settings => Puppet::Util::Settings.new
    end
  end

  # Test to make sure that no two celements have the same short name
  def test_celement_short_name_not_duplicated
    config = mkconfig
    assert_nothing_raised("Could not create celement with short name.") do

      config.setdefaults(
        :main,

          :one => { :default => "blah", :desc => "anything", :short => "o" })
    end
    assert_nothing_raised("Could not create second celement with short name.") do

      config.setdefaults(
        :main,

          :two => { :default => "blah", :desc => "anything", :short => "i" })
    end
    assert_raise(ArgumentError, "Could create second celement with duplicate short name.") do

      config.setdefaults(
        :main,

          :three => { :default => "blah", :desc => "anything", :short => "i" })
    end
    # make sure that when the above raises an expection that the config is not included
    assert(!config.include?(:three), "Invalid configuration item was retained")
  end

  # Tell getopt which arguments are valid
  def test_get_getopt_args
    element = Setting.new :name => "foo", :desc => "anything", :settings => Puppet::Util::Settings.new
    assert_equal([["--foo", GetoptLong::REQUIRED_ARGUMENT]], element.getopt_args, "Did not produce appropriate getopt args")

    element.short = "n"
    assert_equal([["--foo", "-n", GetoptLong::REQUIRED_ARGUMENT]], element.getopt_args, "Did not produce appropriate getopt args")

    element = BooleanSetting.new :name => "foo", :desc => "anything", :settings => Puppet::Util::Settings.new

      assert_equal(
        [["--foo", GetoptLong::NO_ARGUMENT], ["--no-foo", GetoptLong::NO_ARGUMENT]],

          element.getopt_args, "Did not produce appropriate getopt args")

    element.short = "n"

      assert_equal(
        [["--foo", "-n", GetoptLong::NO_ARGUMENT],["--no-foo", GetoptLong::NO_ARGUMENT]],

          element.getopt_args, "Did not produce appropriate getopt args")
  end
end

