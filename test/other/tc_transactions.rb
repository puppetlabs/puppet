if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'puppettest'
require 'test/unit'

# $Id$

class TestTransactions < Test::Unit::TestCase
    def cycle(comp)
        assert_nothing_raised {
            trans = comp.evaluate
        }
        events = nil
        assert_nothing_raised {
            events = trans.evaluate.collect { |e|
                e.event
            }
        }
        return events
    end

    def setup
        Puppet::Type.allclear
        @@tmpfiles = []
        Puppet[:loglevel] = :debug if __FILE__ == $0
        Puppet[:statefile] = "/var/tmp/puppetstate"
        @groups = %x{groups}.chomp.split(/ /)
        unless @groups.length > 1
            p @groups
            raise "You must be a member of more than one group to test this"
        end
    end

    def teardown
        Puppet::Type.allclear
        @@tmpfiles.each { |file|
            if FileTest.exists?(file)
                system("chmod -R 755 %s" % file)
                system("rm -rf %s" % file)
            end
        }
        @@tmpfiles.clear
        system("rm -f %s" % Puppet[:statefile])
        print "\n\n" if Puppet[:debug]
    end

    def newfile(hash = {})
        tmpfile = PuppetTestSuite.tempfile()
        File.open(tmpfile, "w") { |f| f.puts rand(100) }
        @@tmpfiles.push tmpfile
        hash[:name] = tmpfile
        assert_nothing_raised() {
            return Puppet::Type::PFile.new(hash)
        }
    end

    def newservice
        assert_nothing_raised() {
            return Puppet::Type::Service.new(
                :name => "sleeper",
                :path => File.join($puppetbase,"examples/root/etc/init.d"),
                :check => [:running]
            )
        }
    end

    def newcomp(name,*args)
        comp = nil
        assert_nothing_raised() {
            comp = Puppet::Component.new(:name => name)
        }

        args.each { |arg|
            assert_nothing_raised() {
                comp.push arg
            }
        }

        return comp
    end

    def test_filerollback
        transaction = nil
        file = newfile()
        states = {}
        check = [:group,:mode]
        file[:check] = check

        assert_nothing_raised() {
            file.retrieve
        }

        assert_nothing_raised() {
            check.each { |state|
                assert(file[state])
                states[state] = file[state]
            }
        }


        component = newcomp("file",file)
        assert_nothing_raised() {
            file[:group] = @groups[1]
            file[:mode] = "755"
        }
        assert_nothing_raised() {
            transaction = component.evaluate
        }
        assert_nothing_raised() {
            transaction.evaluate
        }
        assert_nothing_raised() {
            transaction.rollback
        }
        assert_nothing_raised() {
            file.retrieve
        }
        states.each { |state,value|
            assert_equal(
                value,file[state]
            )
        }
    end

    def test_servicetrans
        transaction = nil
        service = newservice()
        service[:check] = [:running]

        component = newcomp("service",service)

        assert_nothing_raised() {
            service.retrieve
        }
        state = service[:running]
        assert_nothing_raised() {
            service[:running] = 1
        }
        assert_nothing_raised() {
            transaction = component.evaluate
        }
        assert_nothing_raised() {
            transaction.evaluate
        }
        assert_nothing_raised() {
            service[:running] = 0
        }
        assert_nothing_raised() {
            transaction = component.evaluate
        }
        assert_nothing_raised() {
            transaction.evaluate
        }
    end

    def test_both
        transaction = nil
        file = newfile()
        service = newservice()
        states = {}
        check = [:group,:mode]
        file[:check] = check

        service[:running] = 1
        service.sync

        component = newcomp("both",file,service)

        # 'requires' expects an array of arrays
        service[:require] = [[file.class.name,file.name]]

        assert_nothing_raised() {
            file.retrieve
            service.retrieve
        }

        check.each { |state|
            states[state] = file[state]
        }
        assert_nothing_raised() {
            file[:group] = @groups[1]
            file[:mode] = "755"
        }
        assert_nothing_raised() {
            transaction = component.evaluate
            transaction.toplevel = true
        }

        # this should cause a restart of the service
        assert_nothing_raised() {
            transaction.evaluate
        }

        fakevent = Puppet::Event.new(
            :event => :ALL_EVENTS,
            :object => self,
            :transaction => transaction,
            :message => "yay"
        )

        sub = nil
        assert_nothing_raised() {
            sub = file.subscribers?(fakevent)
        }

        assert(sub)

        # assert we got exactly one trigger on this subscription
        # in other words, we don't want a single event to cause many
        # restarts
        # XXX i don't have a good way to retrieve this information...
        #assert_equal(1,transaction.triggercount(sub))
    end

    def test_twocomps
        transaction = nil
        file = newfile()
        service = newservice()
        states = {}
        check = [:group,:mode]
        file[:check] = check

        service[:running] = 1
        service.sync

        fcomp = newcomp("file",file)
        scomp = newcomp("service",service)

        component = newcomp("both",fcomp,scomp)

        # 'requires' expects an array of arrays
        #component[:require] = [[file.class.name,file.name]]
        service[:require] = [[fcomp.class.name,fcomp.name]]

        assert_nothing_raised() {
            file.retrieve
            service.retrieve
        }

        check.each { |state|
            states[state] = file[state]
        }
        assert_nothing_raised() {
            file[:group] = @groups[1]
            file[:mode] = "755"
        }
        assert_nothing_raised() {
            transaction = component.evaluate
            transaction.toplevel = true
        }

        # this should cause a restart of the service
        assert_nothing_raised() {
            transaction.evaluate
        }

        fakevent = Puppet::Event.new(
            :event => :ALL_EVENTS,
            :object => self,
            :transaction => transaction,
            :message => "yay"
        )

        sub = nil
        assert_nothing_raised() {
            sub = fcomp.subscribers?(fakevent)
        }

        assert(sub)

        # assert we got exactly one trigger on this subscription
        # XXX this doesn't work, because the sub is being triggered in
        # a contained transaction, not this one
        #assert_equal(1,transaction.triggercount(sub))
    end

end
