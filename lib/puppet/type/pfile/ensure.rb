module Puppet
    Puppet.type(:file).ensurable do
        require 'etc'
        desc "Whether to create files that don't currently exist.
            Possible values are *absent*, *present* (equivalent to *file*),
            **file**/*directory*.  Specifying 'absent' will delete the file,
            although currently this will not recursively delete directories.
            
            This is the only element with an *ensure* state that does not have
            a default value."

        # Most 'ensure' states have a default, but with files we, um, don't.
        nodefault

        newvalue(:absent) do
            File.unlink(@parent[:path])
        end

        aliasvalue(:false, :absent)

        newvalue(:file) do
            # Make sure we're not managing the content some other way
            if state = @parent.state(:content) or state = @parent.state(:source)
                state.sync
            else
                @parent.write(false) { |f| f.flush }
                mode = @parent.should(:mode)
            end
            return :file_created
        end

        aliasvalue(:present, :file)

        newvalue(:directory) do
            mode = @parent.should(:mode)
            parent = File.dirname(@parent[:path])
            unless FileTest.exists? parent
                raise Puppet::Error,
                    "Cannot create %s; parent directory %s does not exist" %
                        [@parent[:path], parent]
            end
            Puppet::Util.asuser(@parent.asuser()) {
                if mode
                    Puppet::Util.withumask(000) do
                        Dir.mkdir(@parent[:path],mode)
                    end
                else
                    Dir.mkdir(@parent[:path])
                end
            }
            @parent.setchecksum
            return :directory_created
        end

        def check
            basedir = File.dirname(@parent[:path])

            if ! FileTest.exists?(basedir)
                raise Puppet::Error,
                    "Can not create %s; parent directory does not exist" %
                    @parent.name
            elsif ! FileTest.directory?(basedir)
                raise Puppet::Error,
                    "Can not create %s; %s is not a directory" %
                    [@parent.name, dirname]
            end
        end

        def retrieve
            if stat = @parent.stat(false)
                @is = stat.ftype.intern
            else
                if self.should == :false
                    @is = :false
                else
                    @is = :absent
                end
            end

            #self.debug "'exists' state is %s" % self.is
        end


        # We can mostly rely on the superclass method, but we want other states
        # to take precedence over 'ensure' if they are present.
#        def sync
#            # XXX This is a bad idea, because it almost guarantees bugs if we
#            # introduce more states to manage content, but anything else is just
#            # about as bad.
#            event = nil
#            #if state = @parent.state(:source) or state = @parent.state(:content)
#            #    event = state.sync
#            #else
#                event = super
#                @parent.setchecksum
#            #end
#            return event
#        end
    end
end

# $Id$
