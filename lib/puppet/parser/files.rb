require 'puppet/module'
require 'puppet/parser/parser'

# This is a silly central module for finding
# different kinds of files while parsing.  This code
# doesn't really belong in the Puppet::Module class,
# but it doesn't really belong anywhere else, either.
module Puppet::Parser::Files
    module_function

    # Return a list of manifests (as absolute filenames) that match +pat+
    # with the current directory set to +cwd+. If the first component of
    # +pat+ does not contain any wildcards and is an existing module, return
    # a list of manifests in that module matching the rest of +pat+
    # Otherwise, try to find manifests matching +pat+ relative to +cwd+
    def find_manifests(start, options = {})
        cwd = options[:cwd] || Dir.getwd
        module_name, pattern = split_file_path(start)
        begin
            if mod = Puppet::Module.find(module_name, options[:environment])
                return mod.match_manifests(pattern)
            end
        rescue Puppet::Module::InvalidName
            # Than that would be a "no."
        end
        abspat = File::expand_path(start, cwd)
        files = Dir.glob(abspat).reject { |f| FileTest.directory?(f) }
        if files.size == 0
            files = Dir.glob(abspat + ".pp").reject { |f| FileTest.directory?(f) }
        end
        return files
    end

    # Find the concrete file denoted by +file+. If +file+ is absolute,
    # return it directly. Otherwise try to find it as a template in a
    # module. If that fails, return it relative to the +templatedir+ config
    # param.
    # In all cases, an absolute path is returned, which does not
    # necessarily refer to an existing file
    def find_template(template, environment = nil)
        if template =~ /^#{File::SEPARATOR}/
            return template
        end

        if template_paths = templatepath(environment)
            # If we can find the template in :templatedir, we return that.
            template_paths.collect { |path|
                File::join(path, template)
            }.each do |f|
                return f if FileTest.exist?(f)
            end
        end

        # check in the default template dir, if there is one
        if td_file = find_template_in_module(template, environment)
            return td_file
        end

        return nil
    end

    def find_template_in_module(template, environment = nil)
        path, file = split_file_path(template)

        # Because templates don't have an assumed template name, like manifests do,
        # we treat templates with no name as being templates in the main template
        # directory.
        return nil unless file

        if mod = Puppet::Module.find(path, environment) and t = mod.template(file)
            return t
        end
        nil
    end

    # Return an array of paths by splitting the +templatedir+ config
    # parameter.
    def templatepath(environment = nil)
        dirs = Puppet.settings.value(:templatedir, environment).split(":")
        dirs.select do |p|
            File::directory?(p)
        end
    end

    # Split the path into the module and the rest of the path, or return
    # nil if the path is empty or absolute (starts with a /).
    # This method can return nil & anyone calling it needs to handle that.
    def split_file_path(path)
        path.split(File::SEPARATOR, 2) unless path =~ /^(#{File::SEPARATOR}|$)/
    end

end
