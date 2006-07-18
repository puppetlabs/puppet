#!/usr/bin/ruby

if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'facter'

require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/client'
require 'puppet/rails'
require 'test/unit'
require 'puppettest'

class TestInterpreter < Test::Unit::TestCase
	include TestPuppet
	include ServerTest
    AST = Puppet::Parser::AST

    # create a simple manifest that uses nodes to create a file
    def mknodemanifest(node, file)
        createdfile = tempfile()

        File.open(file, "w") { |f|
            f.puts "node %s { file { \"%s\": ensure => file, mode => 755 } }\n" %
                [node, createdfile]
        }

        return [file, createdfile]
    end

    def test_simple
        file = tempfile()
        File.open(file, "w") { |f|
            f.puts "file { \"/etc\": owner => root }"
        }
        assert_nothing_raised {
            Puppet::Parser::Interpreter.new(:Manifest => file)
        }
    end

    def test_reloadfiles
        hostname = Facter["hostname"].value

        file = tempfile()

        # Create a first version
        createdfile = mknodemanifest(hostname, file)

        interp = nil
        assert_nothing_raised {
            interp = Puppet::Parser::Interpreter.new(:Manifest => file)
        }

        config = nil
        assert_nothing_raised {
            config = interp.run(hostname, {})
        }
        sleep(1)

        # Now create a new file
        createdfile = mknodemanifest(hostname, file)

        newconfig = nil
        assert_nothing_raised {
            newconfig = interp.run(hostname, {})
        }

        assert(config != newconfig, "Configs are somehow the same")
    end

    if defined? ActiveRecord
    def test_hoststorage
        assert_nothing_raised {
            Puppet[:storeconfigs] = true
        }

        file = tempfile()
        File.open(file, "w") { |f|
            f.puts "file { \"/etc\": owner => root }"
        }

        interp = nil
        assert_nothing_raised {
            interp = Puppet::Parser::Interpreter.new(
                :Manifest => file,
                :UseNodes => false,
                :ForkSave => false
            )
        }

        facts = {}
        Facter.each { |fact, val| facts[fact] = val }

        objects = nil
        assert_nothing_raised {
            objects = interp.run(facts["hostname"], facts)
        }

        obj = Puppet::Rails::Host.find_by_name(facts["hostname"])
        assert(obj, "Could not find host object")
    end
    else
        $stderr.puts "No ActiveRecord -- skipping collection tests"
    end

    if Facter["domain"].value == "madstop.com"
    begin
        require 'ldap'
        $haveldap = true
    rescue LoadError
        $stderr.puts "Missing ldap; skipping ldap source tests"
        $haveldap = false
    end

    # Only test ldap stuff on luke's network, since that's the only place we
    # have data for.
    if $haveldap
    def ldapconnect

        @ldap = LDAP::Conn.new("ldap", 389)
        @ldap.set_option( LDAP::LDAP_OPT_PROTOCOL_VERSION, 3 )
        @ldap.simple_bind("", "")

        return @ldap
    end

    def ldaphost(node)
        parent = nil
        classes = nil
        @ldap.search( "ou=hosts, dc=madstop, dc=com", 2,
            "(&(objectclass=puppetclient)(cn=%s))" % node
        ) do |entry|
            parent = entry.vals("parentnode").shift
            classes = entry.vals("puppetclass") || []
        end

        return parent, classes
    end

    def test_ldapnodes
        Puppet[:ldapbase] = "ou=hosts, dc=madstop, dc=com"
        Puppet[:ldapnodes] = true

        ldapconnect()
        file = tempfile()
        files = []
        parentfile = tempfile() + "-parent"
        files << parentfile
        hostname = Facter["hostname"].value
        lparent, lclasses = ldaphost(Facter["hostname"].value)
        assert(lclasses, "Did not retrieve info from ldap")
        File.open(file, "w") { |f|
            f.puts "node #{lparent} {
    file { \"#{parentfile}\": ensure => file }
}"

            lclasses.each { |klass|
                kfile = tempfile() + "-klass"
                files << kfile
                f.puts "class #{klass} { file { \"#{kfile}\": ensure => file } }"
            }
        }
        interp = nil
        assert_nothing_raised {
            interp = Puppet::Parser::Interpreter.new(
                :Manifest => file
            )
        }

        parent = nil
        classes = nil
        # First make sure we get the default node for unknown hosts
        dparent, dclasses = ldaphost("default")

        assert_nothing_raised {
            parent, classes = interp.nodesearch("nosuchhostokay")
        }

        assert_equal(dparent, parent, "Default parent node did not match")
        assert_equal(dclasses, classes, "Default parent class list did not match")

        # Now look for our normal host
        assert_nothing_raised {
            parent, classes = interp.nodesearch_ldap(hostname)
        }

        assert_equal(lparent, parent, "Parent node did not match")
        assert_equal(lclasses, classes, "Class list did not match")

        objects = nil
        assert_nothing_raised {
            objects = interp.run(hostname, Puppet::Client::MasterClient.facts)
        }

        comp = nil
        assert_nothing_raised {
            comp = objects.to_type
        }

        assert_apply(comp)
        files.each { |cfile|
            @@tmpfiles << cfile
            assert(FileTest.exists?(cfile), "Did not make %s" % cfile)
        }
    end

    if Process.uid == 0 and Facter["hostname"].value == "culain"
    def test_ldapreconnect
        Puppet[:ldapbase] = "ou=hosts, dc=madstop, dc=com"
        Puppet[:ldapnodes] = true

        interp = nil
        assert_nothing_raised {
            interp = Puppet::Parser::Interpreter.new(
                :Manifest => mktestmanifest()
            )
        }
        hostname = "culain.madstop.com"

        # look for our host
        assert_nothing_raised {
            parent, classes = interp.nodesearch_ldap(hostname)
        }

        # Now restart ldap
        system("/etc/init.d/slapd restart 2>/dev/null >/dev/null")
        sleep(1)

        # and look again
        assert_nothing_raised {
            parent, classes = interp.nodesearch_ldap(hostname)
        }

        # Now stop ldap
        system("/etc/init.d/slapd stop 2>/dev/null >/dev/null")
        cleanup do
            system("/etc/init.d/slapd start 2>/dev/null >/dev/null")
        end

        # And make sure we actually fail here
        assert_raise(Puppet::Error) {
            parent, classes = interp.nodesearch_ldap(hostname)
        }
    end
    else
        $stderr.puts "Run as root for ldap reconnect tests"
    end
    end
    else
        $stderr.puts "Not in madstop.com; skipping ldap tests"
    end

    # Make sure searchnode behaves as we expect.
    def test_nodesearch
        # First create a fake nodesearch algorithm
        i = 0
        Puppet::Parser::Interpreter.send(:define_method, "nodesearch_fake") do |node|
            return nil, nil if node == "default"
            i += 1
            case i
            when 1: return nil, nil
            when 2: return "#{node}parent", nil
            when 3: return nil, ["#{node}class"]
            when 4: return nil, ["#{node}class", "nother#{node}"]
            when 5: return "other#{node}parent", ["#{node}class", "nother#{node}"]
            else
                puts "huh: %s" % i
            end
        end
        interp = nil
        assert_nothing_raised {
            interp = Puppet::Parser::Interpreter.new(
                :Manifest => mktestmanifest(),
                :NodeSources => [:fake]
            )
        }
        # Make sure it behaves correctly for all forms
        5.times do |j|
            parent, classes = interp.nodesearch("mynode")

            # Basically, just make sure that if we have either or both,
            # we get a result back.
            unless i == 1
                assert(parent || classes,
                    "Did not get node info on pass #{i}")
            end
        end
    end
end
