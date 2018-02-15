#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'

describe Puppet::Transaction::Report do
  before :each do
    # Enable persistence during tests
    Puppet::Transaction::Persistence.any_instance.stubs(:enabled?).returns(true)
  end

  describe "when using the indirector" do
    after do
      Puppet.settings.stubs(:use)
    end

    it "should be able to delegate to the :processor terminus" do
      Puppet::Transaction::Report.indirection.stubs(:terminus_class).returns :processor

      terminus = Puppet::Transaction::Report.indirection.terminus(:processor)

      Facter.stubs(:value).returns "host.domain.com"

      report = Puppet::Transaction::Report.new

      terminus.expects(:process).with(report)

      Puppet::Transaction::Report.indirection.save(report)
    end
  end

  describe "when dumping to YAML" do
    it "should not contain TagSet objects" do
      resource = Puppet::Resource.new(:notify, "Hello")
      ral_resource = resource.to_ral
      status = Puppet::Resource::Status.new(ral_resource)

      log = Puppet::Util::Log.new(:level => :info, :message => "foo")

      report = Puppet::Transaction::Report.new
      report.add_resource_status(status)
      report << log

      expect(YAML.dump(report)).to_not match('Puppet::Util::TagSet')
    end
  end

  describe "inference checking" do
    include PuppetSpec::Files
    require 'puppet/configurer'

    def run_catalogs(resources1, resources2, noop1 = false, noop2 = false, &block)
      last_run_report = nil
      Puppet::Transaction::Report.indirection.expects(:save).twice.with do |report, x|
        last_run_report = report
        true
      end

      Puppet[:report] = true
      Puppet[:noop] = noop1

      configurer = Puppet::Configurer.new
      configurer.run :catalog => new_catalog(resources1)

      yield block if block
      last_report = last_run_report

      Puppet[:noop] = noop2

      configurer = Puppet::Configurer.new
      configurer.run :catalog => new_catalog(resources2)

      expect(last_report).not_to eq(last_run_report)

      return last_run_report
    end

    def new_blank_catalog
      Puppet::Resource::Catalog.new("testing", Puppet.lookup(:environments).get(Puppet[:environment]))
    end

    def new_catalog(resources = [])
      new_cat = new_blank_catalog
      [resources].flatten.each do |resource|
        new_cat.add_resource(resource)
      end
      new_cat
    end

    def get_cc_count(report)
      report.metrics["resources"].values.each do |v|
        if v[0] == "corrective_change"
          return v[2]
        end
      end
      return nil
    end

    describe "for agent runs that contain" do
      it "notifies with catalog change" do
        report = run_catalogs(Puppet::Type.type(:notify).new(:title => "testing",
                                                             :message => "foo"),
                              Puppet::Type.type(:notify).new(:title => "testing",
                                                             :message => "foobar"))

        expect(report.status).to eq("changed")

        rs = report.resource_statuses["Notify[testing]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(false)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "notifies with no catalog change" do
        report = run_catalogs(Puppet::Type.type(:notify).new(:title => "testing",
                                                             :message => "foo"),
                              Puppet::Type.type(:notify).new(:title => "testing",
                                                             :message => "foo"))

        expect(report.status).to eq("changed")

        rs = report.resource_statuses["Notify[testing]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(false)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "new file resource" do
        file = tmpfile("test_file")
        report = run_catalogs([],
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"))

        expect(report.status).to eq("changed")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(false)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "removal of a file resource" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              [])

        expect(report.status).to eq("unchanged")
        expect(report.resource_statuses["File[#{file}]"]).to eq(nil)
        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "file with a title change" do
        file1 = tmpfile("test_file")
        file2 = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file1,
                                                           :content => "mystuff"),
                              Puppet::Type.type(:file).new(:title => file2,
                                                           :content => "mystuff"))

        expect(report.status).to eq("changed")

        expect(report.resource_statuses["File[#{file1}]"]).to eq(nil)

        rs = report.resource_statuses["File[#{file2}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(false)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "file with no catalog change" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"))

        expect(report.status).to eq("unchanged")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(0)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "file with a new parameter" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff",
                                                           :loglevel => :debug))

        expect(report.status).to eq("unchanged")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(0)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "file with a removed parameter" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff",
                                                           :loglevel => :debug),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"))

        expect(report.status).to eq("unchanged")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(0)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "file with a property no longer managed" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              Puppet::Type.type(:file).new(:title => file))

        expect(report.status).to eq("unchanged")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(0)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "file with no catalog change, but file changed between runs" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff")) do
          File.open(file, 'w') do |f|
            f.puts "some content"
          end
        end

        expect(report.status).to eq("changed")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(true)
        expect(rs.corrective_change).to eq(true)

        expect(report.corrective_change).to eq(true)
        expect(get_cc_count(report)).to eq(1)
      end

      it "file with catalog change, but file changed between runs that matched catalog change" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "some content")) do
          File.open(file, 'w') do |f|
            f.write "some content"
          end
        end

        expect(report.status).to eq("unchanged")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(0)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "file with catalog change, but file changed between runs that did not match catalog change" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff1"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff2")) do
          File.open(file, 'w') do |f|
            f.write "some content"
          end
        end

        expect(report.status).to eq("changed")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(true)
        expect(rs.corrective_change).to eq(true)

        expect(report.corrective_change).to eq(true)
        expect(get_cc_count(report)).to eq(1)
      end

      it "file with catalog change" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff1"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff2"))

        expect(report.status).to eq("changed")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(false)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "file with ensure property set to present" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :ensure => :present),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :ensure => :present))

        expect(report.status).to eq("unchanged")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(0)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "file with ensure property change file => absent" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :ensure => :file),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :ensure => :absent))

        expect(report.status).to eq("changed")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(false)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "file with ensure property change present => absent" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :ensure => :present),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :ensure => :absent))

        expect(report.status).to eq("changed")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(false)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "link with ensure property change present => absent", :unless => Puppet.features.microsoft_windows? do
        file = tmpfile("test_file")
        FileUtils.symlink(file, tmpfile("test_link"))

        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :ensure => :present),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :ensure => :absent))

        expect(report.status).to eq("changed")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(false)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "file with ensure property change absent => present" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :ensure => :absent),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :ensure => :present))

        expect(report.status).to eq("changed")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(false)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "new resource in catalog" do
        file = tmpfile("test_file")
        report = run_catalogs([],
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff asdf"))

        expect(report.status).to eq("changed")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(false)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "exec with idempotence issue", :unless => Puppet.features.microsoft_windows? do
        report = run_catalogs(Puppet::Type.type(:exec).new(:title => "exec1",
                                                           :command => "/bin/echo foo"),
                              Puppet::Type.type(:exec).new(:title => "exec1",
                                                           :command => "/bin/echo foo"))

        expect(report.status).to eq("changed")

        # Of note here, is that the main idempotence issues lives in 'returns'
        rs = report.resource_statuses["Exec[exec1]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(true)
        expect(rs.corrective_change).to eq(true)

        expect(report.corrective_change).to eq(true)
        expect(get_cc_count(report)).to eq(1)
      end

      it "exec with no idempotence issue", :unless => Puppet.features.microsoft_windows? do
        report = run_catalogs(Puppet::Type.type(:exec).new(:title => "exec1",
                                                           :command => "echo foo",
                                                           :path => "/bin",
                                                           :unless => "ls"),
                              Puppet::Type.type(:exec).new(:title => "exec1",
                                                           :command => "echo foo",
                                                           :path => "/bin",
                                                           :unless => "ls"))

        expect(report.status).to eq("unchanged")

        # Of note here, is that the main idempotence issues lives in 'returns'
        rs = report.resource_statuses["Exec[exec1]"]
        expect(rs.events.size).to eq(0)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "noop on second run, file with no catalog change, but file changed between runs" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              false, true) do
          File.open(file, 'w') do |f|
            f.puts "some content"
          end
        end

        expect(report.status).to eq("unchanged")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events[0].corrective_change).to eq(true)
        expect(rs.events.size).to eq(1)
        expect(rs.corrective_change).to eq(true)

        expect(report.corrective_change).to eq(true)
        expect(get_cc_count(report)).to eq(1)
      end

      it "noop on all subsequent runs, file with no catalog change, but file changed between run 1 and 2" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              false, true) do
          File.open(file, 'w') do |f|
            f.puts "some content"
          end
        end

        expect(report.status).to eq("unchanged")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events[0].corrective_change).to eq(true)
        expect(rs.events.size).to eq(1)
        expect(rs.corrective_change).to eq(true)

        expect(report.corrective_change).to eq(true)
        expect(get_cc_count(report)).to eq(1)

        # Simply run the catalog twice again, but this time both runs are noop to
        # test if the corrective field is still set.
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              true, true)

        expect(report.status).to eq("unchanged")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events[0].corrective_change).to eq(true)
        expect(rs.events.size).to eq(1)
        expect(rs.corrective_change).to eq(true)

        expect(report.corrective_change).to eq(true)
        expect(get_cc_count(report)).to eq(1)
      end

      it "noop on first run, file with no catalog change, but file changed between runs" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              true, false) do
          File.open(file, 'w') do |f|
            f.puts "some content"
          end
        end

        expect(report.status).to eq("changed")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events[0].corrective_change).to eq(true)
        expect(rs.events.size).to eq(1)
        expect(rs.corrective_change).to eq(true)

        expect(report.corrective_change).to eq(true)
        expect(get_cc_count(report)).to eq(1)
      end

      it "noop on both runs, file with no catalog change, but file changed between runs" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              true, true) do
          File.open(file, 'w') do |f|
            f.puts "some content"
          end
        end

        expect(report.status).to eq("unchanged")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(true)
        expect(rs.corrective_change).to eq(true)

        expect(report.corrective_change).to eq(true)
        expect(get_cc_count(report)).to eq(1)
      end

      it "noop on 4 runs, file with no catalog change, but file changed between runs 1 and 2" do
        file = tmpfile("test_file")
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              true, true) do
          File.open(file, 'w') do |f|
            f.puts "some content"
          end
        end

        expect(report.status).to eq("unchanged")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(true)
        expect(rs.corrective_change).to eq(true)

        expect(report.corrective_change).to eq(true)
        expect(get_cc_count(report)).to eq(1)

        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "mystuff"),
                              true, true)

        expect(report.status).to eq("unchanged")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(true)
        expect(rs.corrective_change).to eq(true)

        expect(report.corrective_change).to eq(true)
        expect(get_cc_count(report)).to eq(1)
      end

      it "noop on both runs, file already exists but with catalog change each time" do
        file = tmpfile("test_file")

        File.open(file, 'w') do |f|
          f.puts "some content"
        end

        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "a"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "b"),
                              true, true)

        expect(report.status).to eq("unchanged")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(false)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "file failure should not return corrective_change" do
        # Making the path a child path (with no parent) forces a failure
        file = tmpfile("test_file") + "/foo"
        report = run_catalogs(Puppet::Type.type(:file).new(:title => file,
                                                           :content => "a"),
                              Puppet::Type.type(:file).new(:title => file,
                                                           :content => "b"),
                              false, false)

        expect(report.status).to eq("failed")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(false)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end

      it "file skipped with file change between runs will not show corrective_change" do
        # Making the path a child path (with no parent) forces a failure
        file = tmpfile("test_file") + "/foo"

        resources1 = [
          Puppet::Type.type(:file).new(:title => file,
                                       :content => "a",
                                       :notify => "Notify['foo']"),
          Puppet::Type.type(:notify).new(:title => "foo")
        ]
        resources2 = [
          Puppet::Type.type(:file).new(:title => file,
                                       :content => "a",
                                       :notify => "Notify[foo]"),
          Puppet::Type.type(:notify).new(:title => "foo",
                                         :message => "foo")
        ]

        report = run_catalogs(resources1, resources2, false, false)

        expect(report.status).to eq("failed")

        rs = report.resource_statuses["File[#{file}]"]
        expect(rs.events.size).to eq(1)
        expect(rs.events[0].corrective_change).to eq(false)
        expect(rs.corrective_change).to eq(false)

        rs = report.resource_statuses["Notify[foo]"]
        expect(rs.events.size).to eq(0)
        expect(rs.corrective_change).to eq(false)

        expect(report.corrective_change).to eq(false)
        expect(get_cc_count(report)).to eq(0)
      end
    end
  end
end
