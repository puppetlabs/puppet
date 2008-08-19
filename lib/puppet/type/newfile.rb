Puppet::Type.newtype(:newfile) do
    newparam(:path, :namevar => true) do
        desc "The file path."
    end

    newproperty(:ensure) do
        desc "What type the file should be."

        newvalue(:absent) { provider.destroy }
        newvalue(:file) { provider.mkfile }
        newvalue(:directory) {provider.mkdir }
        newvalue(:link) {provider.mklink}

        def retrieve
            provider.type
        end
    end

    newproperty(:content) do
        desc "The file content."
    end

    newproperty(:owner) do
        desc "The file owner."
    end

    newproperty(:group) do
        desc "The file group."
    end

    newproperty(:mode) do
        desc "The file mode."
    end

    newproperty(:type) do
        desc "The read-only file type."
    end
end
