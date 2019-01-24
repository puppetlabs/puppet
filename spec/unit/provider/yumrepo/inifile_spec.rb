require 'spec_helper'
require 'puppet_spec/files'

describe Puppet::Type.type(:yumrepo).provider(:inifile) do
  include PuppetSpec::Files

  after(:each) do
    described_class.clear
  end

  describe "enumerating all yum repo files" do
    it "reads all files in the directories specified by reposdir" do
      expect(described_class).to receive(:reposdir).and_return(['/etc/yum.repos.d'])

      expect(Dir).to receive(:glob).with("/etc/yum.repos.d/*.repo").and_return(['/etc/yum.repos.d/first.repo', '/etc/yum.repos.d/second.repo'])

      actual = described_class.repofiles
      expect(actual).to include("/etc/yum.repos.d/first.repo")
      expect(actual).to include("/etc/yum.repos.d/second.repo")
    end

    it "includes '/etc/yum.conf' as the first element" do
      expect(described_class).to receive(:reposdir).and_return([])

      actual = described_class.repofiles
      expect(actual[0]).to eq "/etc/yum.conf"
    end
  end

  describe "generating the virtual inifile" do
    let(:files) { ['/etc/yum.repos.d/first.repo', '/etc/yum.repos.d/second.repo', '/etc/yum.conf'] }
    let(:collection) { double('virtual inifile') }

    before do
      described_class.clear
      expect(Puppet::Util::IniConfig::FileCollection).to receive(:new).and_return(collection)
    end

    it "reads all files in the directories specified by self.repofiles" do
      expect(described_class).to receive(:repofiles).and_return(files)

      files.each do |file|
        allow(Puppet::FileSystem).to receive(:file?).with(file).and_return(true)
        expect(collection).to receive(:read).with(file)
      end
      described_class.virtual_inifile
    end

    it "ignores repofile entries that are not files" do
      expect(described_class).to receive(:repofiles).and_return(files)

      allow(Puppet::FileSystem).to receive(:file?).with('/etc/yum.repos.d/first.repo').and_return(true)
      allow(Puppet::FileSystem).to receive(:file?).with('/etc/yum.repos.d/second.repo').and_return(false)
      allow(Puppet::FileSystem).to receive(:file?).with('/etc/yum.conf').and_return(true)

      expect(collection).to receive(:read).with('/etc/yum.repos.d/first.repo').once
      expect(collection).not_to receive(:read).with('/etc/yum.repos.d/second.repo')
      expect(collection).to receive(:read).with('/etc/yum.conf').once
      described_class.virtual_inifile
    end
  end

  describe 'creating provider instances' do
    let(:virtual_inifile) { double('virtual inifile') }

    before :each do
      allow(described_class).to receive(:virtual_inifile).and_return(virtual_inifile)
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
      expect(virtual_inifile).to receive(:each_section).and_yield(main_section).and_yield(updates_section)

      instances = described_class.instances
      expect(instances).to have(1).items
      expect(instances[0].name).to eq 'updates'
    end

    it "creates provider instances for every non-main section that was found" do
      expect(virtual_inifile).to receive(:each_section).and_yield(main_section).and_yield(updates_section)

      sect = described_class.instances.first
      expect(sect.name).to eq 'updates'
      expect(sect.descr).to eq 'Some long description of the repo'
      expect(sect.enabled).to eq '1'
    end
  end

  describe "retrieving a section from the inifile" do
    let(:collection) { double('ini file collection') }
    let(:ini_section) { double('ini file section') }

    before do
      allow(described_class).to receive(:virtual_inifile).and_return(collection)
    end

    describe "and the requested section exists" do
      before do
        allow(collection).to receive(:[]).with('updates').and_return(ini_section)
      end

      it "returns the existing section" do
        expect(described_class.section('updates')).to eq ini_section
      end

      it "doesn't create a new section" do
        expect(collection).not_to receive(:add_section)
        described_class.section('updates')
      end
    end

    describe "and the requested section doesn't exist" do
      it "creates a section in the preferred repodir" do
        allow(described_class).to receive(:reposdir).and_return(['/etc/yum.repos.d', '/etc/alternate.repos.d'])
        expect(collection).to receive(:[]).with('updates')
        expect(collection).to receive(:add_section).with('updates', '/etc/alternate.repos.d/updates.repo')

        described_class.section('updates')
      end

      it "creates a section in yum.conf if no repodirs exist" do
        allow(described_class).to receive(:reposdir).and_return([])
        expect(collection).to receive(:[]).with('updates')
        expect(collection).to receive(:add_section).with('updates', '/etc/yum.conf')

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
      double('inifile puppetlabs section', :name => 'puppetlabs-products')
    end

    before do
      type_instance.provider = provider
      allow(described_class).to receive(:section).with('puppetlabs-products').and_return(section)
    end

    describe "methods used by ensurable" do
      it "#create sets the yumrepo properties on the according section" do
        expect(section).to receive(:[]=).with('baseurl', 'http://yum.puppetlabs.com/el/6/products/$basearch')
        expect(section).to receive(:[]=).with('name', 'Puppet Labs Products El 6 - $basearch')
        expect(section).to receive(:[]=).with('enabled', '1')
        expect(section).to receive(:[]=).with('gpgcheck', '1')
        expect(section).to receive(:[]=).with('gpgkey', 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs')

        provider.create
      end

      it "#exists? checks if the repo has been marked as present" do
        allow(described_class).to receive(:section).and_return(double(:[]= => nil))
        provider.create
        expect(provider).to be_exist
      end

      it "#destroy deletes the associated ini file section" do
        expect(described_class).to receive(:section).and_return(section)
        expect(section).to receive(:destroy=).with(true)
        provider.destroy
      end
    end

    describe "getting properties" do
      it "maps the 'descr' property to the 'name' INI property" do
        expect(section).to receive(:[]).with('name').and_return('Some rather long description of the repository')
        expect(provider.descr).to eq 'Some rather long description of the repository'
      end

      it "gets the property from the INI section" do
        expect(section).to receive(:[]).with('enabled').and_return('1')
        expect(provider.enabled).to eq '1'
      end

      it "sets the property as :absent if the INI property is nil" do
        expect(section).to receive(:[]).with('exclude').and_return(nil)
        expect(provider.exclude).to eq :absent
      end
    end

    describe "setting properties" do
      it "maps the 'descr' property to the 'name' INI property" do
        expect(section).to receive(:[]=).with('name', 'Some rather long description of the repository')
        provider.descr = 'Some rather long description of the repository'
      end

      it "sets the property on the INI section" do
        expect(section).to receive(:[]=).with('enabled', '0')
        provider.enabled = '0'
      end

      it "sets the section field to nil when the specified value is absent" do
        expect(section).to receive(:[]=).with('exclude', nil)
        provider.exclude = :absent
      end
    end
  end

  describe 'reposdir' do
    let(:defaults) { ['/etc/yum.repos.d', '/etc/yum/repos.d'] }

    before do
      allow(Puppet::FileSystem).to receive(:exist?).with('/etc/yum.repos.d').and_return(true)
      allow(Puppet::FileSystem).to receive(:exist?).with('/etc/yum/repos.d').and_return(true)
    end

    it "returns the default directories if yum.conf doesn't contain a `reposdir` entry" do
      allow(described_class).to receive(:find_conf_value).with('reposdir', '/etc/yum.conf')
      expect(described_class.reposdir('/etc/yum.conf')).to eq(defaults)
    end

    it "includes the directory specified by the yum.conf 'reposdir' entry when the directory is present" do
      expect(Puppet::FileSystem).to receive(:exist?).with("/etc/yum/extra.repos.d").and_return(true)

      expect(described_class).to receive(:find_conf_value).with('reposdir', '/etc/yum.conf').and_return("/etc/yum/extra.repos.d")
      expect(described_class.reposdir('/etc/yum.conf')).to include("/etc/yum/extra.repos.d")
    end

    it "includes the directory if the value is split by whitespace" do
      expect(Puppet::FileSystem).to receive(:exist?).with("/etc/yum/extra.repos.d").and_return(true)
      expect(Puppet::FileSystem).to receive(:exist?).with("/etc/yum/misc.repos.d").and_return(true)

      expect(described_class).to receive(:find_conf_value).with('reposdir', '/etc/yum.conf').and_return("/etc/yum/extra.repos.d /etc/yum/misc.repos.d")
      expect(described_class.reposdir('/etc/yum.conf')).to include("/etc/yum/extra.repos.d", "/etc/yum/misc.repos.d")
    end

    it "includes the directory if the value is split by new lines" do
      expect(Puppet::FileSystem).to receive(:exist?).with("/etc/yum/extra.repos.d").and_return(true)
      expect(Puppet::FileSystem).to receive(:exist?).with("/etc/yum/misc.repos.d").and_return(true)

      expect(described_class).to receive(:find_conf_value).with('reposdir', '/etc/yum.conf').and_return("/etc/yum/extra.repos.d\n/etc/yum/misc.repos.d")
      expect(described_class.reposdir('/etc/yum.conf')).to include("/etc/yum/extra.repos.d", "/etc/yum/misc.repos.d")
    end

    it "doesn't include the directory specified by the yum.conf 'reposdir' entry when the directory is absent" do
      expect(Puppet::FileSystem).to receive(:exist?).with("/etc/yum/extra.repos.d").and_return(false)

      expect(described_class).to receive(:find_conf_value).with('reposdir', '/etc/yum.conf').and_return("/etc/yum/extra.repos.d")
      expect(described_class.reposdir('/etc/yum.conf')).not_to include("/etc/yum/extra.repos.d")
    end

    it "logs a warning and returns an empty array if none of the specified repo directories exist" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(false)

      allow(described_class).to receive(:find_conf_value).with('reposdir', '/etc/yum.conf')
      expect(Puppet).to receive(:debug).with('No yum directories were found on the local filesystem')
      expect(described_class.reposdir('/etc/yum.conf')).to be_empty
    end
  end

  describe "looking up a conf value" do
    describe "and the file doesn't exist" do
      it "returns nil" do
        allow(Puppet::FileSystem).to receive(:exist?).and_return(false)
        expect(described_class.find_conf_value('reposdir')).to be_nil
      end
    end

    describe "and the file exists" do
      let(:pfile) { double('yum.conf physical file') }
      let(:sect ) { double('ini section') }

      before do
        allow(Puppet::FileSystem).to receive(:exist?).with('/etc/yum.conf').and_return(true)
        allow(Puppet::Util::IniConfig::PhysicalFile).to receive(:new).with('/etc/yum.conf').and_return(pfile)
        expect(pfile).to receive(:read)
      end

      it "creates a PhysicalFile to parse the given file" do
        expect(pfile).to receive(:get_section)
        described_class.find_conf_value('reposdir')
      end

      it "returns nil if the file exists but the 'main' section doesn't exist" do
        expect(pfile).to receive(:get_section).with('main')
        expect(described_class.find_conf_value('reposdir')).to be_nil
      end

      it "returns nil if the file exists but the INI property doesn't exist" do
        expect(pfile).to receive(:get_section).with('main').and_return(sect)
        expect(sect).to receive(:[]).with('reposdir')
        expect(described_class.find_conf_value('reposdir')).to be_nil
      end

      it "returns the value if the value is defined in the PhysicalFile" do
        expect(pfile).to receive(:get_section).with('main').and_return(sect)
        expect(sect).to receive(:[]).with('reposdir').and_return('/etc/alternate.repos.d')
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
      allow(described_class).to receive(:reposdir).and_return([@yumrepo_dir])
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
