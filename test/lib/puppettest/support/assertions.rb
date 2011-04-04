require 'puppettest/support/utils'
require 'fileutils'

module PuppetTest
  include PuppetTest::Support::Utils
  def assert_logged(level, regex, msg = nil)
    # Skip verifying logs that we're not supposed to send.
    return unless Puppet::Util::Log.sendlevel?(level)
    r = @logs.detect { |l| l.level == level and l.message =~ regex }
    @logs.clear
    assert(r, msg)
  end

  def assert_uid_gid(uid, gid, filename)
    flunk "Must be uid 0 to run these tests" unless Process.uid == 0

    fork do
      Puppet::Util::SUIDManager.gid = gid
      Puppet::Util::SUIDManager.uid = uid
      # FIXME: use the tempfile method from puppettest.rb
      system("mkfifo #{filename}")
      f = File.open(filename, "w")
      f << "#{Puppet::Util::SUIDManager.uid}\n#{Puppet::Util::SUIDManager.gid}\n"
      yield if block_given?
    end

    # avoid a race.
    true while !File.exists? filename

    f = File.open(filename, "r")

    a = f.readlines
    assert_equal(uid, a[0].chomp.to_i, "UID was incorrect")
    assert_equal(gid, a[1].chomp.to_i, "GID was incorrect")
    FileUtils.rm(filename)
  end

  def assert_events(events, *resources)
    trans = nil
    comp = nil
    msg = nil

    raise Puppet::DevError, "Incorrect call of assert_events" unless events.is_a? Array
    msg = resources.pop if resources[-1].is_a? String

    config = resources2catalog(*resources)
    transaction = Puppet::Transaction.new(config)

    transaction.evaluate
    newevents = transaction.events.
      reject { |e| ['failure', 'audit'].include? e.status }.
      collect { |e| e.name }

    assert_equal(events, newevents, "Incorrect evaluate #{msg} events")

    transaction
  end

  # A simpler method that just applies what we have.
  def assert_apply(*resources)
    config = resources2catalog(*resources)

    events = nil
    assert_nothing_raised("Failed to evaluate") {
      events = config.apply.events
    }
    events
  end
end
