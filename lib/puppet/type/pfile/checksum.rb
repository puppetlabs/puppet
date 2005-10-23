# Keep a copy of the file checksums, and notify when they change.

# This state never actually modifies the system, it only notices when the system
# changes on its own.
module Puppet
    class State
        class PFileChecksum < Puppet::State
            @doc = "How to check whether a file has changed.  **md5**/*lite-md5*/
                *time*/*mtime*"
            @name = :checksum
            @event = :file_modified

            @unmanaged = true

            @validtypes = %w{md5 md5lite timestamp mtime time}

            def self.validtype?(type)
                @validtypes.include?(type)
            end

            def checktype
                @checktypes[0]
            end

            def getsum(checktype)
                sum = ""
                case checktype
                when "md5", "md5lite":
                    unless FileTest.file?(@parent[:path])
                        #Puppet.info "Cannot MD5 sum directory %s" %
                        #    @parent[:path]

                        # because we cannot sum directories, just delete ourselves
                        # from the file so we won't sync
                        @parent.delete(self.name)
                        return
                    else
                        begin
                            File.open(@parent[:path]) { |file|
                                text = nil
                                if checktype == "md5"
                                    text = file.read
                                else
                                    text = file.read(512)
                                end
                                if text.nil?
                                    Puppet.info "Not checksumming empty file %s" %
                                        @parent.name
                                    sum = 0
                                else
                                    sum = Digest::MD5.hexdigest(text)
                                end
                            }
                        rescue Errno::EACCES => detail
                            Puppet.notice "Cannot checksum %s: permission denied" %
                                @parent.name
                            @parent.delete(self.class.name)
                        rescue => detail
                            Puppet.notice "Cannot checksum %s: %s" %
                                detail
                            @parent.delete(self.class.name)
                        end
                    end
                when "timestamp","mtime":
                    sum = File.stat(@parent[:path]).mtime.to_s
                when "time":
                    sum = File.stat(@parent[:path]).ctime.to_s
                else
                    raise Puppet::Error, "Invalid sum type %s" % checktype
                end

                return sum
            end

            # Convert from the sum type to the stored checksum.
            def shouldprocess(value)
                unless defined? @checktypes
                    @checktypes = []
                end
                unless self.class.validtype?(value)
                    raise Puppet::Error, "Invalid checksum type '%s'" % value
                end

                @checktypes << value
                state = Puppet::Storage.state(self)
                if hash = state[@parent[:path]]
                    if hash.include?(value)
                        return hash[value]
                        #Puppet.debug "Found checksum %s for %s" %
                        #    [self.should,@parent[:path]]
                    else
                        #Puppet.debug "Found checksum for %s but not of type %s" %
                        #    [@parent[:path],@checktype]
                        return :nosum
                    end
                else
                    # We can't use :notfound here, because then it'll match on
                    # non-existent files
                    return :nosum
                end
            end

            # Even though they can specify multiple checksums, the insync?
            # mechanism can really only test against one, so we'll just retrieve
            # the first specified sum type.
            def retrieve
                unless defined? @checktypes
                    @checktypes = ["md5"]
                end

                unless FileTest.exists?(@parent.name)
                    self.is = :notfound
                    return
                end

                # Just use the first allowed check type
                @is = getsum(@checktypes[0])

                # If there is no should defined, then store the current value
                # into the 'should' value, so that we're not marked as being
                # out of sync.  We don't want to generate an event the first
                # time we get a sum.
                if ! defined? @should or @should == [:nosum]
                    @should = [@is]
                    # FIXME we should support an updatechecksums-like mechanism
                    self.updatesum
                end

                #Puppet.debug "checksum state is %s" % self.is
            end


            # At this point, we don't actually modify the system, we modify
            # the stored state to reflect the current state, and then kick
            # off an event to mark any changes.
            def sync
                if @is.nil?
                    raise Puppet::Error, "Checksum state for %s is somehow nil" %
                        @parent.name
                end

                if @is == :notfound
                    self.retrieve

                    if self.insync?
                        Puppet.debug "Checksum is already in sync"
                        return nil
                    end
                    #Puppet.debug "%s(%s): after refresh, is '%s'" %
                    #    [self.class.name,@parent.name,@is]

                    # If we still can't retrieve a checksum, it means that
                    # the file still doesn't exist
                    if @is == :notfound
                        # if they're copying, then we won't worry about the file
                        # not existing yet
                        unless @parent.state(:source)
                            Puppet.warning(
                                "File %s does not exist -- cannot checksum" %
                                @parent.name
                            )
                        end
                        return nil
                    end
                end

                # If the sums are different, then return an event.
                if self.updatesum
                    return :file_modified
                else
                    return nil
                end
            end

            # Store the new sum to the state db.
            def updatesum
                result = false
                state = Puppet::Storage.state(self)
                unless state.include?(@parent.name)
                    Puppet.debug "Initializing state hash for %s" %
                        @parent.name

                    state[@parent.name] = Hash.new
                end

                if @is.is_a?(Symbol)
                    error = Puppet::Error.new("%s has invalid checksum" %
                        @parent.name)
                    raise error
                #elsif @should == :notfound
                #    error = Puppet::Error.new("%s has invalid 'should' checksum" %
                #        @parent.name)
                #    raise error
                end

                # if we're replacing, vs. updating
                if state[@parent.name].include?(@checktypes[0])
                    unless defined? @should
                        raise Puppet::Error.new(
                            ("@should is not initialized for %s, even though we " +
                            "found a checksum") % @parent[:path]
                        )
                    end
                    Puppet.debug "Replacing %s checksum %s with %s" %
                        [@parent.name, state[@parent.name][@checktypes[0]],@is]
                    #Puppet.debug "@is: %s; @should: %s" % [@is,@should]
                    result = true
                else
                    Puppet.debug "Creating checksum %s for %s of type %s" %
                        [self.is,@parent.name,@checktypes[0]]
                    result = false
                end
                state[@parent.name][@checktypes[0]] = @is
                return result
            end
        end
    end
end

# $Id$
