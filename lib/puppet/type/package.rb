#!/usr/local/bin/ruby -w

# $Id$

require 'puppet/type/state'
require 'puppet/fact'

module Puppet
    class State
        class PackageInstalled < Puppet::State
            @name = :install

            def retrieve
                #self.is = Puppet::PackageTyping[@object.format][@object.name]
                unless @parent.class.listed
                    @parent.class.getpkglist
                end
                Puppet.debug "package install state is %s" % self.is
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
                Puppet::State::PackageInstalled
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
            @listed = false

            @allowedmethods = [:types]
            @@types = nil

            def Package.clear
                @listed = false
                super
            end

            def Package.listed
                return @listed
            end

            def Package.types(array)
                unless array.is_a?(Array)
                    array = [array]
                end
                @@types = array
                Puppet.warning "Types are %s" % array.join(" ")
            end

            def Package.getpkglist
                if @@types.nil?
                    case Puppet::Fact["operatingsystem"]
                    when "SunOS": @@types = ["sunpkg"]
                    when "Linux":
                        case Puppet::Fact["distro"]
                            when "Debian": @@types = ["dpkg"]
                            when "RedHat": @@types = ["rpm"]
                            else
                                raise "No default type for " + Puppet::Fact["distro"]
                        end
                    else
                        raise "No default type for " + Puppet::Fact["operatingsystem"]
                    end
                end

                list = @@types.collect { |type|
                    if typeobj = Puppet::PackagingType[type]
                        # pull all of the objects
                        typeobj.list
                    else
                        raise "Could not find package type '%s'" % type
                    end
                }.flatten
                @listed = true
                return list
            end

            def Package.installedpkg(hash)
                # this is from code, so we don't have to do as much checking
                name = hash[:name]

                # if it already exists, modify the existing one
                if object = Package[name]
                    states = {}
                    object.states.each { |state|
                        Puppet.warning "Adding %s" % state.name.inspect
                        states[state.name] = state
                    }
                    hash.each { |var,value|
                        if states.include?(var)
                            Puppet.debug "%s is a set state" % var.inspect
                            states[var].is = value
                        else
                            Puppet.debug "%s is not a set state" % var.inspect
                            if object[var] and object[var] != value
                                Puppet.warning "Overriding %s => %s on %s with %s" %
                                    [var,object[var],name,value]
                            end

                            object[var] = value

                            # swap the values if we're a state
                            if states.include?(var)
                                Puppet.debug "Swapping %s because it's a state" % var
                                states[var].is = value
                                states[var].should = nil
                            else
                                Puppet.debug "%s is not a state" % var.inspect
                                Puppet.debug "States are %s" % states.keys.collect { |st|
                                    st.inspect
                                }.join(" ")
                            end
                        end
                    }
                    return object
                else # just create it
                    return self.new(hash)
                end
            end

            # okay, there are two ways that a package could be created...
            # either through the language, in which case the hash's values should
            # be set in 'should', or through comparing against the system, in which
            # case the hash's values should be set in 'is'
            def initialize(hash)
                super
            end

        end # Puppet::Type::Package
    end

    class PackagingType
        attr_writer :list, :install, :remove, :check

        @@types = Hash.new(false)

        def PackagingType.[](name)
            if @@types.include?(name)
                return @@types[name]
            else
                Puppet.warning name.inspect
                Puppet.warning @@types.keys.collect { |key|
                    key.inspect
                }.join(" ")
                return nil
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
                fields = [:status, :name, :install, :description]
                hash = {}

                5.times { process.gets } # throw away the header

                # now turn each returned line into a package object
                process.each { |line|
                    if match = regex.match(line)
                        hash.clear

                        fields.zip(match.captures) { |field,value|
                            hash[field] = value
                        }
                        packages.push Puppet::Type::Package.installedpkg(hash)
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
                "VERSION" => :install,
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
                    when /^$/:
                        packages.push Puppet::Type::Package.installedpkg(hash)
                        hash.clear
                    when /\s*(\w+):\s+(.+)/:
                        name = $1
                        value = $2
                        if names.include?(name)
                            hash[names[name]] = value
                        else
                            raise "Could not find %s" % name
                        end
                    when /\s+\d+.+/:
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
end
