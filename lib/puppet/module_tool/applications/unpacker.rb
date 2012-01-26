require 'pathname'
require 'tmpdir'

module Puppet::Module::Tool
  module Applications
    class Unpacker < Application

      def initialize(filename, options = {})
        @filename = Pathname.new(filename)
        parse_filename!
        super(options)
        @module_dir = Pathname.new(options[:dir]) + @module_name
      end

      def run
        extract_module_to_install_dir
        tag_revision

        # Return the Pathname object representing the directory where the
        # module release archive was unpacked the to, and the module release
        # name.
        @module_dir
      end

      private

      def tag_revision
        File.open("#{@module_dir}/REVISION", 'w') do |f|
          f.puts "module: #{@username}/#{@module_name}"
          f.puts "version: #{@version}"
          f.puts "url: file://#{@filename.expand_path}"
          f.puts "installed: #{Time.now}"
        end
      end

      def extract_module_to_install_dir
        delete_existing_installation_or_abort!

        build_dir = Puppet::Forge::Cache.base_path + "tmp-unpacker-#{Digest::SHA1.hexdigest(@filename.basename.to_s)}"
        build_dir.mkpath
        begin
          Puppet.notice "Installing #{@filename.basename} to #{@module_dir.expand_path}"
          unless system "tar xzf #{@filename} -C #{build_dir}"
            raise RuntimeError, "Could not extract contents of module archive."
          end
          # grab the first directory
          extracted = build_dir.children.detect { |c| c.directory? }
          FileUtils.mv extracted, @module_dir
        ensure
          build_dir.rmtree
        end
      end

      def delete_existing_installation_or_abort!
        return unless @module_dir.exist?

        if !options[:force]
          Puppet.warning "Existing module '#{@module_dir.expand_path}' found"
          response = prompt "Overwrite module installed at #{@module_dir.expand_path}? [y/N]"
          unless response =~ /y/i
            raise RuntimeError, "Aborted installation."
          end
        end

        Puppet.warning "Deleting #{@module_dir.expand_path}"
        FileUtils.rm_rf @module_dir
      end
    end
  end
end
