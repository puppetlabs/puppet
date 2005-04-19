if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $blinkbase = "../.."
end

require 'blink'
require 'blink/type/typegen/filetype'
require 'blink/type/typegen/filerecord'
require 'test/unit'

# $Id$

class TestFileType < Test::Unit::TestCase
    def setup
        Blink[:debug] = 1

        @passwdtype = Blink::Type::FileType["passwd"]
        if @passwdtype.nil?
            assert_nothing_raised() {
                @passwdtype = Blink::Type::FileType.newtype(
                    :name => "passwd",
                    :recordsplit => ":",
                    :fields => %w{name password uid gid gcos home shell},
                    :namevar => "name"
                )
            }
        end
    end

    def test_passwd1_nochange
        file = nil
        type = nil
        assert_nothing_raised() {
            file = @passwdtype.new("/etc/passwd")
        }
        assert_nothing_raised() {
            file.retrieve
        }

        assert(file.insync?)

        contents = ""
        ::File.open("/etc/passwd") { |ofile|
            ofile.each { |line|
                contents += line
            }
        }

        assert_equal(
            contents,
            file.to_s
        )

    end

    def test_passwd2_change
        file = nil
        type = nil
        Kernel.system("cp /etc/passwd /tmp/oparsepasswd")
        assert_nothing_raised() {
            file = @passwdtype.new("/tmp/oparsepasswd")
        }
        assert_nothing_raised() {
            file.retrieve
        }

        assert(file.insync?)

        assert_nothing_raised() {
            file.add { |obj|
                obj["name"] = "yaytest"
                obj["password"] = "x"
                obj["uid"] = "10000"
                obj["gid"] = "10000"
                obj["home"] = "/home/yaytest"
                obj["gcos"] = "The Yaytest"
                obj["shell"] = "/bin/sh"
            }
        }

        assert(!file.insync?)

        assert_nothing_raised() {
            file.sync
        }

        assert(file.insync?)

        assert_nothing_raised() {
            file.delete("bin")
        }

        assert(!file.insync?)

        assert_nothing_raised() {
            file.sync
        }

        assert(file.insync?)

        Kernel.system("rm /tmp/oparsepasswd")
    end
end
