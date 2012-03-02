require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet/util/pidlock'
require 'fileutils'

# This is *fucked* *up*
Puppet.debug = false

class TestPuppetUtilPidlock < Test::Unit::TestCase
  include PuppetTest

  def setup
    super
    @workdir = tstdir
  end

  def teardown
    super
    FileUtils.rm_rf(@workdir)
  end

  def test_00_basic_create
    l = nil
    assert_nothing_raised { l = Puppet::Util::Pidlock.new(@workdir + '/nothingmuch') }

    assert_equal Puppet::Util::Pidlock, l.class

    assert_equal @workdir + '/nothingmuch', l.lockfile
  end

  def test_10_uncontended_lock
    l = Puppet::Util::Pidlock.new(@workdir + '/test_lock')

    assert !l.locked?
    assert !l.mine?
    assert l.lock
    assert l.locked?
    assert l.mine?
    assert !l.anonymous?
    # It's OK to call lock multiple times
    assert l.lock
    assert l.unlock
    assert !l.locked?
    assert !l.mine?
  end

  def test_20_someone_elses_lock
    childpid = nil
    l = Puppet::Util::Pidlock.new(@workdir + '/someone_elses_lock')

    # First, we need a PID that's guaranteed to be (a) used, (b) someone
    # else's, and (c) around for the life of this test.
    childpid = fork { loop do; sleep 10; end }

    File.open(l.lockfile, 'w') { |fd| fd.write(childpid) }

    assert l.locked?
    assert !l.mine?
    assert !l.lock
    assert l.locked?
    assert !l.mine?
    assert !l.unlock
    assert l.locked?
    assert !l.mine?
  ensure
    Process.kill("KILL", childpid) unless childpid.nil?
  end

  def test_30_stale_lock
    # This is a bit hard to guarantee, but we need a PID that is definitely
    # unused, and will stay so for the the life of this test.  Our best
    # bet is to create a process, get it's PID, let it die, and *then*
    # lock on it.
    childpid = fork { exit }

    # Now we can't continue until we're sure that the PID is dead
    Process.wait(childpid)

    l = Puppet::Util::Pidlock.new(@workdir + '/stale_lock')

    # locked? should clear the lockfile
    File.open(l.lockfile, 'w') { |fd| fd.write(childpid) }
    assert File.exists?(l.lockfile)
    assert !l.locked?
    assert !File.exists?(l.lockfile)

    # lock should replace the lockfile with our own
    File.open(l.lockfile, 'w') { |fd| fd.write(childpid) }
    assert File.exists?(l.lockfile)
    assert l.lock
    assert l.locked?
    assert l.mine?

    # unlock should fail, and should *not* molest the existing lockfile,
    # despite it being stale
    File.open(l.lockfile, 'w') { |fd| fd.write(childpid) }
    assert File.exists?(l.lockfile)
    assert !l.unlock
    assert File.exists?(l.lockfile)
  end

  def test_40_not_locked_at_all
    l = Puppet::Util::Pidlock.new(@workdir + '/not_locked')

    assert !l.locked?
    # We can't unlock if we don't hold the lock
    assert !l.unlock
  end

  def test_50_anonymous_lock
    l = Puppet::Util::Pidlock.new(@workdir + '/anonymous_lock')

    assert !l.locked?
    assert l.lock(:anonymous => true)
    assert l.locked?
    assert l.anonymous?
    assert !l.mine?
    assert "", File.read(l.lockfile)
    assert !l.unlock
    assert l.locked?
    assert l.anonymous?
    assert l.unlock(:anonymous => true)
    assert !File.exists?(l.lockfile)
  end
end

