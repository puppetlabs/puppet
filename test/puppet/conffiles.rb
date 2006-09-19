require 'puppet'
require 'puppet/config'
require 'puppettest'

class TestConfFiles < Test::Unit::TestCase
    include PuppetTest

    @@gooddata = [
        {
            "fun" => {
                "a" => "b",
                "c" => "d",
                "e" => "f"
            },
            "yay" => {
                "aa" => "bk",
                "ca" => "dk",
                "ea" => "fk"
            },
            "boo" => {
                "eb" => "fb"
            },
        },
        {
            "puppet" => {
                "yay" => "rah"
            },
            "booh" => {
                "okay" => "rah"
            },
            "back" => {
                "yayness" => "rah"
            },
        }
    ]

    def data2config(data)
        str = ""

        if data.include?("puppet")
            # because we're modifying it
            data = data.dup
            str += "[puppet]\n"
            data["puppet"].each { |var, value|
                str += "%s = %s\n" % [var, value]
            }
            data.delete("puppet")
        end

        data.each { |type, settings|
            str += "[%s]\n" % type
            settings.each { |var, value|
                str += "%s = %s\n" % [var, value]
            }
        }

        return str
    end

    def sampledata
        if block_given?
            @@gooddata.each { |hash| yield hash }
        else
            return @@gooddata[0]
        end
    end

    def test_readconfig
        path = tempfile()

        sampledata { |data|
            config = Puppet::Config.new
            data.each { |section, hash|
                hash.each { |param, value|
                    config.setdefaults(section, param => [value, value])
                }
            }
            # Write it out as a config file
            File.open(path, "w") { |f| f.print data2config(data) }
            assert_nothing_raised {
                config.parse(path)
            }

            data.each { |section, hash|
                hash.each { |var, value|
                    assert_equal(
                        data[section][var],
                        config[var],
                        "Got different values at %s/%s" % [section, var]
                    )
                }
            }
        }
    end
end

# $Id$
