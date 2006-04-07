# Test the yumrepo type

if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppettest'
require 'puppet'
require 'test/unit'
require 'fileutils'

class TestYumRepo < Test::Unit::TestCase
	include TestPuppet

    def setup
        super
        @yumdir = tempfile()
        Dir.mkdir(@yumdir)
        @yumconf = File.join(@yumdir, "yum.conf")
        File.open(@yumconf, "w") do |f|
            f.print "[main]\nreposdir=#{@yumdir} /no/such/dir\n"
        end
        Puppet.type(:yumrepo).yumconf = @yumconf
    end

    # Modify one existing section
    def test_modify
        copy_datafiles
        devel = make_repo("development", { :descr => "New description" })
        devel.retrieve
        assert_equal("development", devel[:name])
        assert_equal('Fedora Core $releasever - Development Tree', 
                     devel.state(:descr).is)
        assert_equal('New description', 
                     devel.state(:descr).should)
        assert_apply(devel)
        inifile = Puppet.type(:yumrepo).read()
        assert_equal('New description', inifile['development']['name'])
        assert_equal('Fedora Core $releasever - $basearch - Base',
                     inifile['base']['name'])
        assert_equal(['base', 'development', 'main'],
                     all_sections(inifile))
    end

    # Create a new section
    def test_create
        values = {
            :descr => "Fedora Core $releasever - $basearch - Base",
            :baseurl => "http://example.com/yum/$releasever/$basearch/os/",
            :enabled => "1",
            :gpgcheck => "1",
            :includepkgs => "absent",
            :gpgkey => "file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora"
        }
        repo = make_repo("base", values)
        assert_apply(repo)
        inifile = Puppet.type(:yumrepo).read()
        sections = all_sections(inifile)
        assert_equal(['base', 'main'], sections)
        text = inifile["base"].format
        assert_equal(CREATE_EXP, text)
    end

    def make_repo(name, hash={})
        hash[:name] = name
        Puppet.type(:yumrepo).create(hash)
    end

    def all_sections(inifile)
        sections = []
        inifile.each_section { |section| sections << section.name }
        return sections.sort
    end

    def copy_datafiles
        fakedata("data/types/yumrepos").select { |file|
            file =~ /\.repo$/
        }.each { |src|
            dst = File::join(@yumdir, File::basename(src))
            FileUtils::copy(src, dst)
        }
    end
    
    CREATE_EXP = <<'EOF'
[base]
name=Fedora Core $releasever - $basearch - Base
baseurl=http://example.com/yum/$releasever/$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora
EOF

end        
