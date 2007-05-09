#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'mocha'
require 'puppettest/fileparsing'
require 'puppet/util/filetype'
require 'puppet/provider/parsedfile'
require 'facter'

class TestParsedFile < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::FileParsing

    Puppet::Type.newtype(:testparsedfiletype) do
        ensurable
        newproperty(:one) do
            newvalue(:a)
            newvalue(:b)
        end
        newproperty(:two) do
            newvalue(:c)
            newvalue(:d)
        end

        newparam(:name) do
        end

        # The target should always be a property, not a parameter.
        newproperty(:target) do
            defaultto { @resource.class.defaultprovider.default_target }
        end
    end

    # A simple block to skip the complexity of a full transaction.
    def apply(model)
        [:one, :two, :ensure].each do |st|
            Puppet.info "Setting %s: %s => %s" %
                [model[:name], st, model.should(st)]
            model.provider.send(st.to_s + "=", model.should(st))
        end
    end

    def mkmodel(name, options = {})
        options[:one] ||= "a"
        options[:two] ||= "c"
        options[:name] ||= name

        model = @type.create(options)
    end

    def mkprovider(name = :parsed)
        @provider = @type.provide(name, :parent => Puppet::Provider::ParsedFile,
            :filetype => :ram, :default_target => "yayness") do
            record_line name, :fields => %w{name one two}
        end
    end

    def setup
        super
        @type = Puppet::Type.type(:testparsedfiletype)
    end

    def teardown
        if defined? @provider
            @type.unprovide(@provider.name)
            @provider = nil
        end
        super
    end

    def test_create_provider
        assert_nothing_raised do
            mkprovider
        end
    end

    def test_model_attributes
        prov = nil
        assert_nothing_raised do
            prov = mkprovider
        end

        [:one, :two, :name].each do |attr|
            assert(prov.method_defined?(attr), "Did not define %s" % attr)
        end

        # Now make sure they stay around
        fakemodel = fakemodel(:testparsedfiletype, "yay")

        file = prov.new(fakemodel)

        assert_nothing_raised do
            file.name = :yayness
        end

        # The provider converts to strings
        assert_equal(:yayness, file.name)
    end

    def test_filetype
        prov = mkprovider

        flat = Puppet::Util::FileType.filetype(:flat)
        ram = Puppet::Util::FileType.filetype(:ram)
        assert_nothing_raised do
            prov.filetype = :flat
        end

        assert_equal(flat, prov.filetype)

        assert_nothing_raised do
            prov.filetype = ram
        end
        assert_equal(ram, prov.filetype)
    end

    # Make sure we correctly create a new filetype object, but only when
    # necessary.
    def test_fileobject
        prov = mkprovider

        path = tempfile()
        obj = nil
        assert_nothing_raised do
            obj = prov.target_object(path)
        end

        # The default filetype is 'ram'
        assert_instance_of(Puppet::Util::FileType.filetype(:ram), obj)

        newobj = nil
        assert_nothing_raised do
            newobj = prov.target_object(path)
        end

        assert_equal(obj, newobj, "did not reuse file object")

        # now make sure clear does the right thing
        assert_nothing_raised do
            prov.clear
        end
        assert_nothing_raised do
            newobj = prov.target_object(path)
        end

        assert(obj != newobj, "did not reuse file object")
    end

    def test_retrieve
        prov = mkprovider

        prov.filetype = :ram

        # Override the parse method with our own
        prov.meta_def(:parse) do |text|
            return [text]
        end

        path = :yayness
        file = prov.target_object(path)
        text = "a test"
        file.write(text)

        ret = nil
        assert_nothing_raised do
            ret = prov.retrieve(path)
        end

        assert_equal([text], ret)

        # Now set the text to nil and make sure we get an empty array
        file.write(nil)
        assert_nothing_raised do
            ret = prov.retrieve(path)
        end

        assert_equal([], ret)

        # And the empty string should return an empty array
        file.write("")
        assert_nothing_raised do
            ret = prov.retrieve(path)
        end

        assert_equal([], ret)
    end

    # Verify that prefetch will parse the file, create any necessary instances,
    # and set the 'is' values appropriately.
    def test_prefetch
        prov = mkprovider

        prov.filetype = :ram
        prov.default_target = :default

        # Create a couple of demo files
        prov.target_object(:file1).write "bill b c"

        prov.target_object(:file2).write "jill b d"

        prov.target_object(:default).write "will b d"

        # Create some models for some of those demo files
        model = mkmodel "bill", :target => :file1
        default = mkmodel "will", :target => :default

        assert_nothing_raised do
            prov.prefetch
        end

        # Make sure we prefetched our models.
        assert_equal("b", model.provider.one)
        assert_equal("b", default.provider.one)
        assert_equal("d", default.provider.two)

        # Now list all of them and make sure we get everything back
        hashes = nil
        assert_nothing_raised do
            hashes = prov.list
        end

        names = nil
        assert_nothing_raised do
            names = prov.list_by_name
        end

        %w{bill jill will}.each do |name|
            assert(hashes.find { |r| r[:name] == name},
                "Did not return %s in list" % name)
            assert(names.include?(name),
                "Did not return %s in list_by_name" % name)
        end
    end

    # Make sure we can correctly prefetch on a target.
    def test_prefetch_target
        prov = mkprovider

        prov.filetype = :ram
        target = :yayness
        prov.target_object(target).write "yay b d"

        model = mkmodel "yay", :target => :yayness

        assert_nothing_raised do
            prov.prefetch_target(:yayness)
        end

        # Now make sure we correctly got the hash
        mprov = model.provider
        assert_equal("b", mprov.one)
        assert_equal("d", mprov.two)
    end

    def test_prefetch_match
        prov = mkprovider

        prov.meta_def(:match) do |record|
            # Look for matches on :one
            self.model.find do |m|
                m.should(:one).to_s == record[:one].to_s
            end
        end

        prov.filetype = :ram
        target = :yayness
        prov.target_object(target).write "foo b d"

        model = mkmodel "yay", :target => :yayness, :one => "b"

        assert_nothing_raised do
            prov.prefetch_target(:yayness)
        end

        # Now make sure we correctly got the hash
        mprov = model.provider
        assert_equal("yay", model[:name])
        assert_equal("b", mprov.one)
        assert_equal("d", mprov.two)
    end

    # We need to test that we're retrieving files from all three locations:
    # from any existing target_objects, from the default file location, and
    # from any existing model instances.
    def test_targets
        prov = mkprovider

        files = {}

        # Set the default target
        default = tempfile()
        files[:default] = default
        prov.default_target = default

        # Create a file object
        inmem = tempfile()
        files[:inmemory] = inmem
        prov.target_object(inmem).write("inmem yay ness")

        # Lastly, create a model with separate is and should values
        mtarget = tempfile()
        # istarget = tempfile()
        files[:models] = mtarget
        # files[:ismodels] = istarget
        model = mkmodel "yay", :target => mtarget
        # model.is = [:target, istarget]

        assert(model.should(:target), "Did not get a value for target")
        # assert(model.is(:target), "Did not get a value for target")

        list = nil
        assert_nothing_raised do
            list = prov.targets
        end

        files.each do |name, file|
            assert(list.include?(file), "Provider did not find %s file" % name)
        end
    end

    # Make sure that flushing behaves correctly.  This is what actually writes
    # the data out to disk.
    def test_flush
        prov = mkprovider

        prov.filetype = :ram
        prov.default_target = :yayness

        # Create some models.
        one = mkmodel "one", :one => "a", :two => "c", :target => :yayness
        two = mkmodel "two", :one => "b", :two => "d", :target => :yayness

        # Write out a file with different data.
        prov.target_object(:yayness).write "one b d\ntwo a c"

        prov.prefetch

        # Apply and flush the first model.
        assert_nothing_raised do
            apply(one)
        end
        assert_nothing_raised { one.flush }

        # Make sure it changed our file
        assert_equal(:a, one.provider.one)
        assert_equal(:c, one.provider.two)

        # And make sure it's right on disk
        assert(prov.target_object(:yayness).read.include?("one a c"),
            "Did not write out correct data")

        # Make sure the second model has not been modified
        assert_equal("a", two.provider.one, "Two was flushed early")
        assert_equal("c", two.provider.two, "Two was flushed early")

        # And on disk
        assert(prov.target_object(:yayness).read.include?("two a c"),
            "Wrote out other model")

        # Now fetch the data again and make sure we're still right
        assert_nothing_raised { prov.prefetch }
        assert_equal("a", one.provider.one)
        assert_equal("a", two.provider.one)

        # Now flush the second model and make sure it goes well
        assert_nothing_raised { apply(two) }
        assert_nothing_raised { two.flush }

        assert_equal(:b, two.provider.one)
    end

    def test_creating_file
        prov = mkprovider
        prov.clear

        prov.default_target = :basic

        model = mkmodel "yay", :target => :basic, :one => "a", :two => "c"

        assert_equal(:present, model.should(:ensure))

        apply(model)

        assert_nothing_raised do
            model.flush
        end

        assert(prov.target_object(:basic).read.include?("yay a c"),
            "Did not create file")

        # Make a change
        model.provider.one = "b"

        # Flush it
        assert_nothing_raised do
            model.flush
        end

        # And make sure our model doesn't appear twice in the file.
        assert_equal("yay b c\n",
            prov.target_object(:basic).read)
    end

    # Make sure a record can switch targets.
    def test_switching_targets
        prov = mkprovider

        prov.filetype = :ram
        prov.default_target = :first

        # Make three models, one for each target and one to switch
        first = mkmodel "first", :target => :first
        second = mkmodel "second", :target => :second
        mover = mkmodel "mover", :target => :first

        [first, second, mover].each do |m|
            assert_nothing_raised("Could not apply %s" % m[:name]) do
                apply(m)
            end
        end

        # Flush.
        [first, second, mover].each do |m|
            assert_nothing_raised do
                m.flush
            end
        end

        check = proc do |target, name|
            assert(prov.target_object(target).read.include?("%s a c" % name),
                "Did not sync %s" % name)
        end
        # Make sure the data is there
        check.call(:first, :first)
        check.call(:second, :second)
        check.call(:first, :mover)

        # Now change the target for the mover
        mover[:target] = :second

        # Apply it
        assert_nothing_raised do
            apply(mover)
        end

        # Flush
        assert_nothing_raised do
            mover.flush
        end

        # Make sure the data is there
        check.call(:first, :first)
        check.call(:second, :second)
        check.call(:second, :mover)

        # And make sure the mover is no longer in the first file
        assert(prov.target_object(:first) !~ /mover/,
            "Mover was not removed from first file")
    end

    # Make sure that 'ensure' correctly calls 'sync' on all properties.
    def test_ensure
        prov = mkprovider

        prov.filetype = :ram
        prov.default_target = :first

        # Make two models, one that starts on disk and one that doesn't
        ondisk = mkmodel "ondisk", :target => :first
        notdisk = mkmodel "notdisk", :target => :first

        prov.target_object(:first).write "ondisk a c\n"
        prov.prefetch

        assert_equal(:present, notdisk.should(:ensure),
            "Did not get default ensure value")

        # Try creating the object
        assert_nothing_raised { notdisk.provider.create() }

        # Now make sure all of the data is copied over correctly.
        notdisk.class.validproperties.each do |property|
            assert_equal(notdisk.should(property), notdisk.provider.property_hash[property],
                "%s was not copied over during creation" % property)
        end

        # Flush it to disk and make sure it got copied down
        assert_nothing_raised do
            notdisk.flush
        end

        assert(prov.target_object(:first).read =~ /^notdisk/,
            "Did not write out object to disk")
        assert(prov.target_object(:first).read =~ /^ondisk/,
            "Lost object on disk")

        # Make sure our on-disk model behaves appropriately.
        assert_equal(:present, ondisk.provider.ensure)

        # Now destroy the object
        assert_nothing_raised { notdisk.provider.destroy() }

        assert_nothing_raised { notdisk.flush }

        # And make sure it's no longer present
        assert(prov.target_object(:first).read !~ /^notdisk/,
            "Did not remove thing from disk")
        assert(prov.target_object(:first).read =~ /^ondisk/,
            "Lost object on disk")
        assert_equal(:present, ondisk.provider.ensure)
    end

    def test_absent_fields
        prov = @type.provide(:record, :parent => Puppet::Provider::ParsedFile) do
            record_line :record, :fields => %w{name one two},
                :separator => "\s"
        end
        cleanup { @type.unprovide(:record) }

        line = prov.parse_line("a  d")

        assert_equal("a", line[:name], "field name was not set")
        assert_equal(:absent, line[:one], "field one was not set to absent")

        # Now use a different provider with a non-blank "absent"
        prov = @type.provide(:cronstyle, :parent => Puppet::Provider::ParsedFile) do
            record_line :cronstyle, :fields => %w{name one two},
                :separator => "\s", :absent => "*"
        end
        cleanup { @type.unprovide(:cronstyle) }
        line = prov.parse_line("a * d")

        assert_equal("a", line[:name], "field name was not set")
        assert_equal(:absent, line[:one], "field one was not set to absent")
    end

    # This test is because in x2puppet I was having problems where multiple
    # retrievals somehow destroyed the 'is' values.
    def test_value_retrieval
        prov = mkprovider
        prov.default_target = :yayness

        prov.target_object(:yayness).write "bill a c\njill b d"

        list = @type.list

        bill = list.find { |r| r[:name] == "bill" }
        jill = list.find { |r| r[:name] == "jill" }
        assert(bill, "Could not find bill")
        assert(jill, "Could not find jill")

        prov = bill.provider

        4.times do |i|
            assert(prov.one, "Did not get a value for 'one' on try %s" % (i + 1))
        end

        # First make sure we can retrieve values multiple times from the
        # provider
        bills_values = nil
        assert_nothing_raised do
            bills_values = bill.retrieve
        end

        assert(bills_values[bill.property(:one)], 
               "Bill does not have a value for 'one'")
        assert(bills_values[bill.property(:one)], 
               "Bill does not have a value for 'one' on second try")
        assert_nothing_raised do
            bill.retrieve
        end
        assert(bills_values[bill.property(:one)], 
               "bill's value for 'one' disappeared")
    end

    # Make sure that creating a new model finds existing records in memory
    def test_initialize_finds_records
        prov = mkprovider
        prov.default_target = :yayness

        prov.target_object(:yayness).write "bill a c\njill b d"

        prov.prefetch

        # Now make a model
        bill = nil
        assert_nothing_raised do
            bill = @type.create :name => "bill"
        end

        assert_equal("a", bill.provider.one,
            "Record was not found in memory")
    end

    # Make sure invalid fields always show up as insync
    def test_invalid_fields
        prov = @type.provide(:test, :parent => Puppet::Provider::ParsedFile,
            :filetype => :ram, :default_target => :yayness) do
            record_line :test, :fields => %w{name two}
        end
        cleanup do @type.unprovide(:test) end

        bill = nil
        assert_nothing_raised do
            bill = @type.create :name => "bill",
                :one => "a", :two => "c"
        end

        assert_apply(bill)

        prov.prefetch
        current_value = nil
        assert_nothing_raised do
            current_value = bill.retrieve
        end

        assert(bill.insync?(current_value),
            "An invalid field marked the record out of sync")
    end

    # Make sure we call the prefetch hook at the right place.
    def test_prefetch_hook
        prov = @type.provide(:test, :parent => Puppet::Provider::ParsedFile,
            :filetype => :ram, :default_target => :yayness) do

            def self.prefetch_hook(records)
                records
            end

            record_line :test, :fields => %w{name two}
        end
        cleanup do @type.unprovide(:test) end

        target = "target"

        records = [{:target => "nope"}]
        targeted = {:target => "target"}
        prov.send(:instance_variable_set, "@records", records)
        prov.expects(:retrieve).with(target).returns([targeted])
        prov.expects(:target_records).with(target).returns([targeted])

        prov.expects(:prefetch_hook).with([targeted]).returns([targeted])

        prov.prefetch_target(target)
    end

    # #529
    def test_keep_content_with_target
        mkprovider
        @provider.filetype = :flat
        dpath = tempfile
        opath = tempfile
        @provider.default_target = dpath

        dtarget = @provider.target_object(dpath)
        otarget = @provider.target_object(opath)

        dtarget.write("dname a c\n")
        otarget.write("oname b d\n")

        # Now make a resource that targets elsewhat.
        res = @type.create(:name => "test", :one => "a", :two => "c",
            :target => opath)

        assert(res.property(:target), "Target is a parameter, not a property")

        assert_apply(res)

        assert_equal("oname b d\ntest a c\n", otarget.read,
            "did not get correct results in specified target")
    end
end

# $Id$

