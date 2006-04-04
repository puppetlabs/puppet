# Test the yumrepo type

if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppettest'
require 'puppet/type/yumrepo'
require 'puppet'
require 'test/unit'

class TestYumRepo < Test::Unit::TestCase
	include TestPuppet

    def test_parse
        fakedata("data/types/yumrepos").each { |file|
            next unless file =~ /\.repo$/
            repo = make_repo(file)
            Puppet.info "Parsing %s" % file
            assert_nothing_raised {
                repo.retrieve
            }
            # Lame tests that we actually parsed something in
            assert ! repo[:descr].empty?
            assert ! repo[:repoid].empty?
        }
    end

    def test_create
        file = "#{tempfile()}.repo"
        values = {
            :repoid => "base",
            :descr => "Fedora Core $releasever - $basearch - Base",
            :baseurl => "http://example.com/yum/$releasever/$basearch/os/",
            :enabled => "1",
            :gpgcheck => "1",
            :gpgkey => "file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora"
        }
        repo = make_repo(file, values)
        assert_apply(repo)
        text = Puppet::FileType.filetype(:flat).new(repo.path).read
        assert_equal(CREATE_EXP, text)
    end

    def make_repo(file, hash={})
        hash[:repodir] = File::dirname(file)
        hash[:name]  = File::basename(file, ".repo")
        Puppet.type(:yumrepo).create(hash)
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
