require 'spec_helper'
require 'puppet_spec/files'

describe Puppet::Type.type(:yumrepo).provider(:inifile) do

  include PuppetSpec::Files

  after(:each) do
    described_class.clear
  end

  describe "enumerating all yum repo files" do
    it "reads all files in the directories specified by reposdir" do
      described_class.expects(:reposdir).returns ['/etc/yum.repos.d']

      Dir.expects(:glob).with("/etc/yum.repos.d/*.repo").returns(['/etc/yum.repos.d/first.repo', '/etc/yum.repos.d/second.repo'])

      actual = described_class.repofiles
      expect(actual).to include("/etc/yum.repos.d/first.repo")
      expect(actual).to include("/etc/yum.repos.d/second.repo")
    end

    it "includes '/etc/yum.conf' as the first element" do
      described_class.expects(:reposdir).returns []

      actual = described_class.repofiles
      expect(actual[0]).to eq "/etc/yum.conf"
    end
  end

  describe "generating the virtual inifile" do
    let(:files) { ['/etc/yum.repos.d/first.repo', '/etc/yum.repos.d/second.repo', '/etc/yum.conf'] }
    let(:collection) { mock('virtual inifile') }

    before do
      described_class.clear
      Puppet::Util::IniConfig::FileCollection.expects(:new).returns collection
    end

    it "reads all files in the directories specified by self.repofiles" do
      described_class.expects(:repofiles).returns(files)

      files.each do |file|
        Puppet::FileSystem.stubs(:file?).with(file).returns true
        collection.expects(:read).with(file)
      end
      described_class.virtual_inifile
    end

    it "ignores repofile entries that are not files" do
      described_class.expects(:repofiles).returns(files)

      Puppet::FileSystem.stubs(:file?).with('/etc/yum.repos.d/first.repo').returns true
      Puppet::FileSystem.stubs(:file?).with('/etc/yum.repos.d/second.repo').returns false
      Puppet::FileSystem.stubs(:file?).with('/etc/yum.conf').returns true

      collection.expects(:read).with('/etc/yum.repos.d/first.repo').once
      collection.expects(:read).with('/etc/yum.repos.d/second.repo').never
      collection.expects(:read).with('/etc/yum.conf').once
      described_class.virtual_inifile
    end
  end

  describe 'creating provider instances' do
    let(:virtual_inifile) { stub('virtual inifile') }

    before :each do
      described_class.stubs(:virtual_inifile).returns(virtual_inifile)
    end

    let(:main_section) do
      sect = Puppet::Util::IniConfig::Section.new('main', '/some/imaginary/file')
      sect.entries << ['distroverpkg', 'centos-release']
      sect.entries << ['plugins', '1']

      sect
    end

    let(:updates_section) do
      sect = Puppet::Util::IniConfig::Section.new('updates', '/some/imaginary/file')
      sect.entries << ['name', 'Some long description of the repo']
      sect.entries << ['enabled', '1']

      sect
    end

    it "ignores the main section" do
      virtual_inifile.expects(:each_section).multiple_yields(main_section, updates_section)

      instances = described_class.instances
      expect(instances).to have(1).items
      expect(instances[0].name).to eq 'updates'
    end

    it "creates provider instances for every non-main section that was found" do
      virtual_inifile.expects(:each_section).multiple_yields(main_section, updates_section)

      sect = described_class.instances.first
      expect(sect.name).to eq 'updates'
      expect(sect.descr).to eq 'Some long description of the repo'
      expect(sect.enabled).to eq '1'
    end
  end

  describe "retrieving a section from the inifile" do

    let(:collection) { stub('ini file collection') }

    let(:ini_section) { stub('ini file section') }

    before do
      described_class.stubs(:virtual_inifile).returns(collection)
    end

    describe "and the requested section exists" do
      before do
        collection.stubs(:[]).with('updates').returns ini_section
      end

      it "returns the existing section" do
        expect(described_class.section('updates')).to eq ini_section
      end

      it "doesn't create a new section" do
        collection.expects(:add_section).never
        described_class.section('updates')
      end
    end

    describe "and the requested section doesn't exist" do
      it "creates a section in the preferred repodir" do
        described_class.stubs(:reposdir).returns ['/etc/yum.repos.d', '/etc/alternate.repos.d']
        collection.expects(:[]).with('updates')
        collection.expects(:add_section).with('updates', '/etc/alternate.repos.d/updates.repo')

        described_class.section('updates')
      end

      it "creates a section in yum.conf if no repodirs exist" do
        described_class.stubs(:reposdir).returns []
        collection.expects(:[]).with('updates')
        collection.expects(:add_section).with('updates', '/etc/yum.conf')

        described_class.section('updates')
      end
    end
  end

  describe "setting and getting properties" do

    let(:type_instance) do
      Puppet::Type.type(:yumrepo).new(
        :name     => 'puppetlabs-products',
        :ensure   => :present,
        :baseurl  => 'http://yum.puppetlabs.com/el/6/products/$basearch',
        :descr    => 'Puppet Labs Products El 6 - $basearch',
        :enabled  => '1',
        :gpgcheck => '1',
        :gpgkey   => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs'
      )
    end

    let(:provider) do
      described_class.new(type_instance)
    end

    let(:section) do
      stub('inifile puppetlabs section', :name => 'puppetlabs-products')
    end

    before do
      type_instance.provider = provider
      described_class.stubs(:section).with('puppetlabs-products').returns(section)
    end

    describe "methods used by ensurable" do
      it "#create sets the yumrepo properties on the according section" do
        section.expects(:[]=).with('baseurl', 'http://yum.puppetlabs.com/el/6/products/$basearch')
        section.expects(:[]=).with('name', 'Puppet Labs Products El 6 - $basearch')
        section.expects(:[]=).with('enabled', '1')
        section.expects(:[]=).with('gpgcheck', '1')
        section.expects(:[]=).with('gpgkey', 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs')

        provider.create
      end

      it "#exists? checks if the repo has been marked as present" do
        described_class.stubs(:section).returns(stub(:[]= => nil))
        provider.create
        expect(provider).to be_exist
      end

      it "#destroy deletes the associated ini file section" do
        described_class.expects(:section).returns(section)
        section.expects(:destroy=).with(true)
        provider.destroy
      end
    end

    describe "getting properties" do
      it "maps the 'descr' property to the 'name' INI property" do
        section.expects(:[]).with('name').returns 'Some rather long description of the repository'
        expect(provider.descr).to eq 'Some rather long description of the repository'
      end

      it "gets the property from the INI section" do
        section.expects(:[]).with('enabled').returns '1'
        expect(provider.enabled).to eq '1'
      end

      it "sets the property as :absent if the INI property is nil" do
        section.expects(:[]).with('exclude').returns nil
        expect(provider.exclude).to eq :absent
      end
    end

    describe "setting properties" do
      it "maps the 'descr' property to the 'name' INI property" do
        section.expects(:[]=).with('name', 'Some rather long description of the repository')
        provider.descr = 'Some rather long description of the repository'
      end

      it "sets the property on the INI section" do
        section.expects(:[]=).with('enabled', '0')
        provider.enabled = '0'
      end

      it "sets the section field to nil when the specified value is absent" do
        section.expects(:[]=).with('exclude', nil)
        provider.exclude = :absent
      end
    end
  end

  describe 'reposdir' do
    let(:defaults) { ['/etc/yum.repos.d', '/etc/yum/repos.d'] }

    before do
      Puppet::FileSystem.stubs(:exist?).with('/etc/yum.repos.d').returns(true)
      Puppet::FileSystem.stubs(:exist?).with('/etc/yum/repos.d').returns(true)
    end

    it "returns the default directories if yum.conf doesn't contain a `reposdir` entry" do
      described_class.stubs(:find_conf_value).with('reposdir', '/etc/yum.conf')
      expect(described_class.reposdir('/etc/yum.conf')).to eq(defaults)
    end

    it "includes the directory specified by the yum.conf 'reposdir' entry when the directory is present" do
      Puppet::FileSystem.expects(:exist?).with("/etc/yum/extra.repos.d").returns(true)

      described_class.expects(:find_conf_value).with('reposdir', '/etc/yum.conf').returns "/etc/yum/extra.repos.d"
      expect(described_class.reposdir('/etc/yum.conf')).to include("/etc/yum/extra.repos.d")
    end

    it "includes the directory if the value is split by whitespace" do
      Puppet::FileSystem.expects(:exist?).with("/etc/yum/extra.repos.d").returns(true)
      Puppet::FileSystem.expects(:exist?).with("/etc/yum/misc.repos.d").returns(true)

      described_class.expects(:find_conf_value).with('reposdir', '/etc/yum.conf').returns "/etc/yum/extra.repos.d /etc/yum/misc.repos.d"
      expect(described_class.reposdir('/etc/yum.conf')).to include("/etc/yum/extra.repos.d", "/etc/yum/misc.repos.d")
    end

    it "includes the directory if the value is split by new lines" do
      Puppet::FileSystem.expects(:exist?).with("/etc/yum/extra.repos.d").returns(true)
      Puppet::FileSystem.expects(:exist?).with("/etc/yum/misc.repos.d").returns(true)

      described_class.expects(:find_conf_value).with('reposdir', '/etc/yum.conf').returns "/etc/yum/extra.repos.d\n/etc/yum/misc.repos.d"
      expect(described_class.reposdir('/etc/yum.conf')).to include("/etc/yum/extra.repos.d", "/etc/yum/misc.repos.d")
    end

    it "doesn't include the directory specified by the yum.conf 'reposdir' entry when the directory is absent" do
      Puppet::FileSystem.expects(:exist?).with("/etc/yum/extra.repos.d").returns(false)

      described_class.expects(:find_conf_value).with('reposdir', '/etc/yum.conf').returns "/etc/yum/extra.repos.d"
      expect(described_class.reposdir('/etc/yum.conf')).not_to include("/etc/yum/extra.repos.d")
    end

    it "logs a warning and returns an empty array if none of the specified repo directories exist" do
      Puppet::FileSystem.unstub(:exist?)
      Puppet::FileSystem.stubs(:exist?).returns false

      described_class.stubs(:find_conf_value).with('reposdir', '/etc/yum.conf')
      Puppet.expects(:debug).with('No yum directories were found on the local filesystem')
      expect(described_class.reposdir('/etc/yum.conf')).to be_empty
    end
  end

  describe "looking up a conf value" do
    describe "and the file doesn't exist" do
      it "returns nil" do
        Puppet::FileSystem.stubs(:exist?).returns false
        expect(described_class.find_conf_value('reposdir')).to be_nil
      end
    end

    describe "and the file exists" do
      let(:pfile) { stub('yum.conf physical file') }
      let(:sect) { stub('ini section') }

      before do
        Puppet::FileSystem.stubs(:exist?).with('/etc/yum.conf').returns true
        Puppet::Util::IniConfig::PhysicalFile.stubs(:new).with('/etc/yum.conf').returns pfile
        pfile.expects(:read)
      end

      it "creates a PhysicalFile to parse the given file" do
        pfile.expects(:get_section)
        described_class.find_conf_value('reposdir')
      end

      it "returns nil if the file exists but the 'main' section doesn't exist" do
        pfile.expects(:get_section).with('main')
        expect(described_class.find_conf_value('reposdir')).to be_nil
      end

      it "returns nil if the file exists but the INI property doesn't exist" do
        pfile.expects(:get_section).with('main').returns sect
        sect.expects(:[]).with('reposdir')
        expect(described_class.find_conf_value('reposdir')).to be_nil
      end

      it "returns the value if the value is defined in the PhysicalFile" do
        pfile.expects(:get_section).with('main').returns sect
        sect.expects(:[]).with('reposdir').returns '/etc/alternate.repos.d'
        expect(described_class.find_conf_value('reposdir')).to eq '/etc/alternate.repos.d'
      end
    end
  end

  describe "resource application after prefetch" do
    let(:type_instance) do
      Puppet::Type.type(:yumrepo).new(
          :name     => 'puppetlabs-products',
          :ensure   => :present,
          :baseurl  => 'http://yum.puppetlabs.com/el/6/products/$basearch',
          :descr    => 'Puppet Labs Products El 6 - $basearch',
          :enabled  => '1',
          :gpgcheck => '1',
          :gpgkey   => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs'
      )
    end

    let(:provider) do
      described_class.new(type_instance)
    end

    before :each do
      @yumrepo_dir = tmpdir('yumrepo_integration_specs')
      @yumrepo_conf_file = tmpfile('yumrepo_conf_file', @yumrepo_dir)
      described_class.stubs(:reposdir).returns [@yumrepo_dir]
      type_instance.provider = provider
    end

    it "preserves repo file contents that were created after prefetch" do
      provider.class.prefetch({})
      # we specifically want to create a file after prefetch has happened so that
      # none of the sections in the file exist in the prefetch cache
      repo_file = File.join(@yumrepo_dir, 'puppetlabs-products.repo')
      contents = <<-HEREDOC
[puppetlabs-products]
name=created_by_package_after_prefetch
enabled=1
failovermethod=priority
gpgcheck=0

[additional_section]
name=Extra Packages for Enterprise Linux 6 - $basearch - Debug
#baseurl=http://download.fedoraproject.org/pub/epel/6/$basearch/debug
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-debug-6&arch=$basearch
failovermethod=priority
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6
gpgcheck=1
      HEREDOC
      File.open(repo_file, 'wb') { |f| f.write(contents)}

      provider.create
      provider.flush

      expected_contents = <<-HEREDOC
[puppetlabs-products]
name=Puppet Labs Products El 6 - $basearch
enabled=1
failovermethod=priority
gpgcheck=1

baseurl=http://yum.puppetlabs.com/el/6/products/$basearch
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs
[additional_section]
name=Extra Packages for Enterprise Linux 6 - $basearch - Debug
#baseurl=http://download.fedoraproject.org/pub/epel/6/$basearch/debug
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-debug-6&arch=$basearch
failovermethod=priority
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6
gpgcheck=1
      HEREDOC
      expect(File.read(repo_file)).to eq(expected_contents)
    end

    it "does not error becuase of repo files that have been removed from disk" do
      repo_file = File.join(@yumrepo_dir, 'epel.repo')
      contents = <<-HEREDOC
[epel]
name=created_by_package_after_prefetch
enabled=1
failovermethod=priority
gpgcheck=0
      HEREDOC
      File.open(repo_file, 'wb') { |f| f.write(contents)}
      provider.class.prefetch({})
      File.delete(repo_file)

      provider.create
      provider.flush
    end
  end
end
