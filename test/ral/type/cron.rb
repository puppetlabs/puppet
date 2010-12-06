#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'

# Test cron job creation, modification, and destruction

class TestCron < Test::Unit::TestCase
  include PuppetTest

  def setup
    super

    setme

    @crontype = Puppet::Type.type(:cron)
    @provider = @crontype.defaultprovider
    if @provider.respond_to?(:filetype=)
      @provider.stubs(:filetype).returns(Puppet::Util::FileType.filetype(:ram))
    end
    @crontype = Puppet::Type.type(:cron)
  end

  def teardown
    super
    @crontype.defaultprovider = nil
  end

  def eachprovider
    @crontype.suitableprovider.each do |provider|
      yield provider
    end
  end

  # Back up the user's existing cron tab if they have one.
  def cronback
    tab = nil
    assert_nothing_raised {
      tab = Puppet::Type.type(:cron).filetype.read(@me)
    }

    @currenttab = $CHILD_STATUS == 0 ? tab : nil
  end

  # Restore the cron tab to its original form.
  def cronrestore
    assert_nothing_raised {
      if @currenttab
        @crontype.filetype.new(@me).write(@currenttab)
      else
        @crontype.filetype.new(@me).remove
      end
    }
  end

  # Create a cron job with all fields filled in.
  def mkcron(name, addargs = true)
    cron = nil
    command = "date > #{tmpdir()}/crontest#{name}"
    args = nil
    if addargs
      args = {
        :command => command,
        :name => name,
        :user => @me,
        :minute => rand(59),
        :month => "1",
        :monthday => "1",
        :hour => "1"
      }
    else
      args = {:command => command, :name => name}
    end
    assert_nothing_raised {
      cron = @crontype.new(args)
    }

    cron
  end

  # Run the cron through its paces -- install it then remove it.
  def cyclecron(cron)
    obj = Puppet::Type::Cron.cronobj(@me)

    text = obj.read
    name = cron.name
    comp = mk_catalog(name, cron)

    assert_events([:cron_created], comp)
    cron.provider.class.prefetch
    currentvalue = cron.retrieve

    assert(cron.insync?(currentvalue), "Cron is not in sync")

    assert_events([], comp)

    curtext = obj.read
    text.split("\n").each do |line|
      assert(curtext.include?(line), "Missing '#{line}'")
    end
    obj = Puppet::Type::Cron.cronobj(@me)

    cron[:ensure] = :absent

    assert_events([:cron_removed], comp)

    cron.provider.class.prefetch
    currentvalue = cron.retrieve

    assert(cron.insync?(currentvalue), "Cron is not in sync")
    assert_events([], comp)
  end

  # Test that a cron job with spaces at the end doesn't get rewritten
  def test_trailingspaces
    eachprovider do |provider|
      cron = nil
      # make the cron
      name = "yaytest"
      command = "date > /dev/null "
      assert_nothing_raised {

        cron = @crontype.new(

          :name => name,
          :command => "date > /dev/null ",
          :month => "May",

          :user => @me
        )
      }
      property = cron.send(:property, :command)
      cron.provider.command = command
      cron.provider.ensure = :present
      cron.provider.user = @me
      cron.provider.month = ["4"]
      cron.provider.class.prefetch
      currentvalue = cron.retrieve
      assert(cron.parameter(:command).insync?(currentvalue[:command]), "Property :command is not considered in sync with value #{currentvalue[:command]}")
    end
  end

  def test_makeandretrievecron
    %w{storeandretrieve a-name another-name more_naming SomeName}.each do |name|
      cron = mkcron(name)
      catalog = mk_catalog(name, cron)
      trans = assert_events([:cron_created], catalog, name)

      cron.provider.class.prefetch
      cron = nil

      assert(cron = catalog.resource(:cron, name), "Could not retrieve named cron")
      assert_instance_of(Puppet::Type.type(:cron), cron)
    end
  end

  # Do input validation testing on all of the parameters.
  def test_arguments
    values = {
      :monthday => {
        :valid => [ 1, 13, "1" ],
        :invalid => [ -1, 0, 32 ]
      },
      :weekday => {
        :valid => [ 0, 3, 6, "1", "tue", "wed",
          "Wed", "MOnday", "SaTurday" ],
        :invalid => [ -1, 8, "13", "tues", "teusday", "thurs" ]
      },
      :hour => {
        :valid => [ 0, 21, 23 ],
        :invalid => [ -1, 24 ]
      },
      :minute => {
        :valid => [ 0, 34, 59 ],
        :invalid => [ -1, 60 ]
      },
      :month => {
        :valid => [ 1, 11, 12, "mar", "March", "apr", "October", "DeCeMbEr" ],
        :invalid => [ -1, 0, 13, "marc", "sept" ]
      }
    }

    cron = mkcron("valtesting")
    values.each { |param, hash|
      # We have to test the valid ones first, because otherwise the
      # property will fail to create at all.
      [:valid, :invalid].each { |type|
        hash[type].each { |value|
          case type
          when :valid
            assert_nothing_raised {
              cron[param] = value
            }

            assert_equal([value.to_s], cron.should(param), "Cron value was not set correctly") if value.is_a?(Integer)
          when :invalid
            assert_raise(Puppet::Error, "#{value} is incorrectly a valid #{param}") {
              cron[param] = value
            }
          end

          if value.is_a?(Integer)
            value = value.to_s
            redo
          end
        }
      }
    }
  end

  # Verify that comma-separated numbers are not resulting in rewrites
  def test_comma_separated_vals_work
    eachprovider do |provider|
      cron = nil
      assert_nothing_raised {

        cron = @crontype.new(

          :command => "/bin/date > /dev/null",
          :minute => [0, 30],
          :name => "crontest",

          :provider => provider.name
        )
      }


      cron.provider.ensure = :present
      cron.provider.command = '/bin/date > /dev/null'
      cron.provider.minute = %w{0 30}
      cron.provider.class.prefetch
      currentvalue = cron.retrieve

      currentvalue.each do |name, value|
        # We're only interested in comparing minutes.
        next unless name.to_s == "minute"
        assert(cron.parameter(name).insync?(value), "Property #{name} is not considered in sync with value #{value.inspect}")
      end
    end
  end

  def test_fieldremoval
    cron = nil
    assert_nothing_raised {

      cron = @crontype.new(

        :command => "/bin/date > /dev/null",
        :minute => [0, 30],
        :name => "crontest",

        :provider => :crontab
      )
    }

    assert_events([:cron_created], cron)
    cron.provider.class.prefetch

    cron[:minute] = :absent
    assert_events([:minute_changed], cron)

    current_values = nil
    assert_nothing_raised {
      cron.provider.class.prefetch
      current_values = cron.retrieve
    }
    assert_equal(:absent, current_values[cron.property(:minute)])
  end

  def test_listing
    # Make a crontab cron for testing
    provider = @crontype.provider(:crontab)
    return unless provider.suitable?

    ft = provider.filetype
    provider.filetype = :ram
    cleanup { provider.filetype = ft }

    setme

      cron = @crontype.new(
        :name => "testing",
      :minute => [0, 30],
      :command => "/bin/testing",

      :user => @me
    )
    # Write it to our file
    assert_apply(cron)

    crons = []
    assert_nothing_raised {
      @crontype.instances.each do |cron|
        crons << cron
      end
    }

    crons.each do |cron|
      assert_instance_of(@crontype, cron, "Did not receive a real cron object")

        assert_instance_of(
          String, cron.value(:user),

          "Cron user is not a string")
    end
  end

  def verify_failonnouser
    assert_raise(Puppet::Error) do
      @crontype.retrieve("nosuchuser")
    end
  end

  def test_divisionnumbers
    cron = mkcron("divtest")
    cron[:minute] = "*/5"

    assert_apply(cron)

    cron.provider.class.prefetch
    currentvalue = cron.retrieve

    assert_equal(["*/5"], currentvalue[cron.property(:minute)])
  end

  def test_ranges
    cron = mkcron("rangetest")
    cron[:minute] = "2-4"

    assert_apply(cron)

    current_values = nil
    assert_nothing_raised {
      cron.provider.class.prefetch
      current_values = cron.retrieve
    }

    assert_equal(["2-4"], current_values[cron.property(:minute)])
  end


  def provider_set(cron, param, value)
    unless param =~ /=$/
      param = "#{param}="
    end

    cron.provider.send(param, value)
  end

  def test_value
    cron = mkcron("valuetesting", false)

    # First, test the normal properties
    [:minute, :hour, :month].each do |param|
      cron.newattr(param)
      property = cron.property(param)

      assert(property, "Did not get #{param} property")

      assert_nothing_raised {
        #                property.is = :absent
        provider_set(cron, param, :absent)
      }

      val = "*"
      assert_equal(val, cron.value(param))

      # Make sure arrays work, too
      provider_set(cron, param, ["1"])
      assert_equal(%w{1}, cron.value(param))

      # Make sure values get comma-joined
      provider_set(cron, param, %w{2 3})
      assert_equal(%w{2 3}, cron.value(param))

      # Make sure "should" values work, too
      cron[param] = "4"
      assert_equal(%w{4}, cron.value(param))

      cron[param] = ["4"]
      assert_equal(%w{4}, cron.value(param))

      cron[param] = ["4", "5"]
      assert_equal(%w{4 5}, cron.value(param))

      provider_set(cron, param, :absent)
      assert_equal(%w{4 5}, cron.value(param))
    end

    Puppet[:trace] = false

    # Now make sure that :command works correctly
    cron.delete(:command)
    cron.newattr(:command)
    property = cron.property(:command)

    assert_nothing_raised {
      provider_set(cron, :command, :absent)
    }

    param = :command
    # Make sure arrays work, too
    provider_set(cron, param, ["/bin/echo"])
    assert_equal("/bin/echo", cron.value(param))

    # Make sure values are not comma-joined
    provider_set(cron, param, %w{/bin/echo /bin/test})
    assert_equal("/bin/echo", cron.value(param))

    # Make sure "should" values work, too
    cron[param] = "/bin/echo"
    assert_equal("/bin/echo", cron.value(param))

    cron[param] = ["/bin/echo"]
    assert_equal("/bin/echo", cron.value(param))

    cron[param] = %w{/bin/echo /bin/test}
    assert_equal("/bin/echo", cron.value(param))

    provider_set(cron, param, :absent)
    assert_equal("/bin/echo", cron.value(param))
  end

  def test_multiple_users
    crons = []
    users = ["root", nonrootuser.name]
    users.each do |user|

      cron = Puppet::Type.type(:cron).new(

        :name => "testcron-#{user}",
        :user => user,
        :command => "/bin/echo",

        :minute => [0,30]
      )
      crons << cron

      assert_equal(cron.should(:user), cron.should(:target),
        "Target was not set correctly for #{user}")
    end
    provider = crons[0].provider.class

    assert_apply(*crons)

    users.each do |user|
      users.each do |other|
        next if user == other
        text = provider.target_object(other).read


          assert(
            text !~ /testcron-#{user}/,

            "#{user}'s cron job is in #{other}'s tab")
      end
    end
  end

  # Make sure the user stuff defaults correctly.
  def test_default_user
    crontab = @crontype.provider(:crontab)
    if crontab.suitable?

      inst = @crontype.new(

        :name => "something", :command => "/some/thing",

        :provider => :crontab)
      assert_equal(Etc.getpwuid(Process.uid).name, inst.should(:user), "user did not default to current user with crontab")
      assert_equal(Etc.getpwuid(Process.uid).name, inst.should(:target), "target did not default to current user with crontab")

      # Now make a new cron with a user, and make sure it gets copied
      # over

        inst = @crontype.new(
          :name => "yay", :command => "/some/thing",

          :user => "bin", :provider => :crontab)

            assert_equal(
              "bin", inst.should(:target),

              "target did not default to user with crontab")
    end
  end

  # #705 - make sure extra spaces don't screw things up
  def test_spaces_in_command
    string = "echo   multiple  spaces"
    cron = @crontype.new(:name => "space testing", :command => string)
    assert_apply(cron)

    cron = @crontype.new(:name => "space testing", :command => string)

    # Now make sure that it's correctly in sync
    cron.provider.class.prefetch("testing" => cron)
    properties = cron.retrieve
    assert_equal(string, properties[:command], "Cron did not pick up extra spaces in command")
    assert(cron.parameter(:command).insync?(properties[:command]), "Command changed with multiple spaces")
  end
end


