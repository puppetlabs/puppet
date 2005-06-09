#!/usr/local/bin/ruby -w

# $Id$

require 'blink/type/state'

module Blink
    class State
        class PackageInstalled < Blink::State
            @name = :install

            def retrieve
                self.is = Blink::PackageType[@object.format][@object.name]
                Blink.debug "package install state is %d" % self.is
            end

            def sync
                #begin
                    raise "cannot sync package states yet"
                #rescue
                #    raise "failed to sync #{@params[:file]}: #{$!}"
                #end

                #return :package_installed
            end
        end
    end

    class Type
        # packages are complicated because each package format has completely
        # different commands.  We need some way to convert specific packages
        # into the general package object...
        class Package < Type
            attr_reader :version, :format
            @states = [
                Blink::State::PackageInstalled
            ]
            @parameters = [
                :format,
                :name,
                :status,
                :version,
                :category,
                :platform,
                :root,
                :vendor,
                :description
            ]

            @name = :package
            @namevar = :name
        end # Blink::Type::Package

        class PackagingType
            attr_writer :list, :install, :remove, :check

            @@types = Hash.new(false)

            def PackagingType.[](name)
                if @@types.include?(name)
                    return @@types[name]
                else
                    raise "no such type %s" % name
                end
            end

            # whether a package is installed or not
            def [](name)
                return @packages[name]
            end

            [:list, :install, :remove, :check].each { |method|
                self.send(:define_method, method) {
                    # retrieve the variable
                    var = eval("@" + method.id2name)
                    if var.is_a?(Proc)
                        var.call()
                    else
                        raise "only blocks are supported right now"
                    end
                }
            }
            
            def initialize(name)
                if block_given?
                    yield self
                end

                @packages = Hash.new(false)
                @@types[name] = self
            end

            def retrieve
                @packages.clear()

                @packages = self.list()
            end
        end

        PackagingType.new("dpkg") { |type|
            type.list = proc {
                packages = []

                # dpkg only prints as many columns as you have available
                # which means we don't get all of the info
                # stupid stupid
                oldcol = ENV["COLUMNS"]
                ENV["COLUMNS"] = "500"

                # list out all of the packages
                open("| dpkg -l") { |process|
                    # our regex for matching dpkg output
                    regex = %r{^(\S+)\s+(\S+)\s+(\S+)\s+(.+)$}
                    fields = [:status, :name, :version, :description]
                    hash = {}

                    5.times { process.gets } # throw away the header

                    # now turn each returned line into a package object
                    process.each { |line|
                        if match = regex.match(line)
                            hash.clear

                            fields.zip(match.captures) { |field,value|
                                hash[field] = value
                            }
                            packages.push Blink::Type::Package.new(hash)
                        else
                            raise "failed to match dpkg line %s" % line
                        end
                    }
                }
                ENV["COLUMNS"] = oldcol

                return packages
            }

            # we need package retrieval mechanisms before we can have package
            # installation mechanisms...
            #type.install = proc { |pkg|
            #    raise "installation not implemented yet"
            #}

            type.remove = proc { |pkg|
                cmd = "dpkg -r %s" % pkg.name
                output = %x{#{cmd}}
                if $? != 0
                    raise output
                end
            }
        }

        PackagingType.new("sunpkg") { |type|
            type.list = proc {
                packages = []
                hash = {}
                names = {
                    "PKGINST" => :name,
                    "NAME" => nil,
                    "CATEGORY" => :category,
                    "ARCH" => :platform,
                    "VERSION" => :version,
                    "BASEDIR" => :root,
                    "HOTLINE" => nil,
                    "EMAIL" => nil,
                    "VENDOR" => :vendor,
                    "DESC" => :description,
                    "PSTAMP" => nil,
                    "INSTDATE" => nil,
                    "STATUS" => nil,
                    "FILES" => nil
                }

                # list out all of the packages
                open("| pkginfo -l") { |process|
                    # we're using the long listing, so each line is a separate piece
                    # of information
                    process.each { |line|
                        case line
                        when /^$/ then
                            packages.push Blink::Type::Package.new(hash)
                            hash.clear
                        when /\s*(\w+):\s+(.+)/
                            name = $1
                            value = $2
                            if names.include?(name)
                                hash[names[name]] = value
                            else
                                raise "Could not find %s" % name
                            end
                        when /\s+\d+.+/
                            # nothing; we're ignoring the FILES info
                        end
                    }
                }
                return packages
            }

            # we need package retrieval mechanisms before we can have package
            # installation mechanisms...
            #type.install = proc { |pkg|
            #    raise "installation not implemented yet"
            #}

            type.remove = proc { |pkg|
                cmd = "pkgrm -n %s" % pkg.name
                output = %x{#{cmd}}
                if $? != 0
                    raise output
                end
            }
        }

        # this is how we retrieve packages
        class PackageSource
            attr_accessor :uri
            attr_writer :retrieve

            @@sources = Hash.new(false)

            def PackageSource.get(file)
                type = file.sub(%r{:.+},'')
                source = nil
                if source = @@sources[type]
                    return source.retrieve(file)
                else
                    raise "Unknown package source: %s" % type
                end
            end

            def initialize(name)
                if block_given?
                    yield self
                end

                @@sources[name] = self
            end

            def retrieve(path)
                @retrieve.call(path)
            end

        end

        PackageSource.new("file") { |obj|
            obj.retrieve = proc { |path|
                # this might not work for windows...
                file = path.sub(%r{^file://},'')

                if FileTest.exists?(file)
                    return file
                else
                    raise "File %s does not exist" % file
                end
            }
        }
    end # Blink::Type
end
