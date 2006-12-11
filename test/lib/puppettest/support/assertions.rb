require 'puppettest'
require 'fileutils'

module PuppetTest

    def assert_uid_gid(uid, gid, filename)
        flunk "Must be uid 0 to run these tests" unless Process.uid == 0

        fork do 
            Puppet::SUIDManager.gid = gid
            Puppet::SUIDManager.uid = uid
            # FIXME: use the tempfile method from puppettest.rb
            system("mkfifo "+filename)
            f = File.open(filename, "w")
            f << "#{Puppet::SUIDManager.uid}\n#{Puppet::SUIDManager.gid}\n"
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

    def assert_rollback_events(events, trans, msg = nil)
        run_events(:rollback, events, trans, msg)
    end

    def assert_events(events, *items)
        trans = nil
        comp = nil
        msg = nil

        unless events.is_a? Array
            raise Puppet::DevError, "Incorrect call of assert_events"
        end
        if items[-1].is_a? String
            msg = items.pop
        end

        remove_comp = false
        # They either passed a comp or a list of items.
        if items[0].is_a? Puppet.type(:component)
            comp = items.shift
        else
            comp = newcomp(items[0].title, *items)
            remove_comp = true
        end
        msg ||= comp.title
        assert_nothing_raised("Component %s failed" % [msg]) {
            trans = comp.evaluate
        }

        run_events(:evaluate, trans, events, msg)

        if remove_comp
            Puppet.type(:component).delete(comp)
        end

        return trans
    end

    # A simpler method that just applies what we have.
    def assert_apply(*objects)
        if objects[0].is_a?(Puppet.type(:component))
            comp = objects.shift
            unless objects.empty?
                objects.each { |o| comp.push o }
            end
        else
            comp = newcomp(*objects)
        end
        trans = nil

        assert_nothing_raised("Failed to create transaction") {
            trans = comp.evaluate
        }

        events = nil
        assert_nothing_raised("Failed to evaluate transaction") {
            events = trans.evaluate.collect { |e| e.event }
        }
        trans.cleanup
        Puppet.type(:component).delete(comp)
        events
    end
end

# $Id$
