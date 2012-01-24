#
# I've striped down dependencies on Net::SSH and Facets to
# stay as simple as possible.
#
# Original code from Assaf Arkin in the buildr project, released under Apache
# License [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0)
#
# Licensed to Puppet Labs under one or more contributor license agreements.
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.  Puppet Labs licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may not use this file
# except in compliance with the License.  You may obtain a copy of the License
# at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.

require 'cgi'
require 'uri'
require 'net/http'
require 'net/https'
require 'tempfile'
require 'fileutils'

# show progress of download
require File.join(File.dirname(__FILE__), 'progressbar')

# Not quite open-uri, but similar. Provides read and write methods for the resource represented by the URI.
# Currently supports reads for URI::HTTP and writes for URI::SFTP. Also provides convenience methods for
# downloads and uploads.
module URI
  # Raised when trying to read/download a resource that doesn't exist.
  class NotFoundError < RuntimeError; end

  class << self
    # :call-seq:
    #   read(uri, options?) => content
    #   read(uri, options?) { |chunk| ... }
    #
    # Reads from the resource behind this URI. The first form returns the content of the resource,
    # the second form yields to the block with each chunk of content (usually more than one).
    #
    # For example:
    #   File.open "image.jpg", "w" do |file|
    #     URI.read("http://example.com/image.jpg") { |chunk| file.write chunk }
    #   end
    # Shorter version:
    #   File.open("image.jpg", "w") { |file| file.write URI.read("http://example.com/image.jpg") }
    #
    # Supported options:
    # * :modified -- Only download if file modified since this timestamp. Returns nil if not modified.
    # * :progress -- Show the progress bar while reading.
    def read(uri, options = nil, &block)
      uri = URI.parse(uri.to_s) unless URI === uri
      uri.read(options, &block)
    end

    # :call-seq:
    #   download(uri, target, options?)
    #
    # Downloads the resource to the target.
    #
    # The target may be a file name (string or task), in which case the file is created from the resource.
    # The target may also be any object that responds to +write+, e.g. File, StringIO, Pipe.
    #
    # Use the progress bar when running in verbose mode.
    def download(uri, target, options = nil)
      uri = URI.parse(uri.to_s) unless URI === uri
      uri.download(target, options)
    end
      
    # :call-seq:
    #   write(uri, content, options?)
    #   write(uri, options?) { |bytes| .. }
    #
    # Writes to the resource behind the URI. The first form writes the content from a string or an object
    # that responds to +read+ and optionally +size+. The second form writes the content by yielding to the
    # block. Each yield should return up to the specified number of bytes, the last yield returns nil.
    #
    # For example:
    #   File.open "killer-app.jar", "rb" do |file|
    #     write("sftp://localhost/jars/killer-app.jar") { |chunk| file.read(chunk) }
    #   end
    # Or:
    #   write "sftp://localhost/jars/killer-app.jar", File.read("killer-app.jar")
    #
    # Supported options:
    # * :progress -- Show the progress bar while reading.
    def write(uri, *args, &block)
      uri = URI.parse(uri.to_s) unless URI === uri
      uri.write(*args, &block)
    end
  end

  class Generic

    # :call-seq:
    #   read(options?) => content
    #   read(options?) { |chunk| ... }
    #
    # Reads from the resource behind this URI. The first form returns the content of the resource,
    # the second form yields to the block with each chunk of content (usually more than one).
    #
    # For options, see URI::read.
    def read(options = nil, &block)
      fail "This protocol doesn't support reading (yet, how about helping by implementing it?)"
    end
  
    # :call-seq:
    #   download(target, options?)
    #
    # Downloads the resource to the target.
    #
    # The target may be a file name (string or task), in which case the file is created from the resource.
    # The target may also be any object that responds to +write+, e.g. File, StringIO, Pipe.
    #
    # Use the progress bar when running in verbose mode.
    def download(target, options = {})
      case target
      when String
        # If download breaks we end up with a partial file which is
        # worse than not having a file at all, so download to temporary
        # file and then move over.
        modified = File.stat(target).mtime if File.exist?(target)
        temp = nil
        Tempfile.open(File.basename(target)) do |tf|
          tf.binmode
          read(options.merge(:modified => modified)) { |chunk| tf.write chunk }
          temp = tf
        end
        FileUtils.mkpath(File.dirname(target))
        FileUtils.move(temp.path, target)
      when File
        read(options.merge(:modified => target.mtime)) { |chunk| target.write chunk }
        target.flush
      else
        raise ArgumentError, "Expecting a target that is either a file name (string, task) or object that responds to write (file, pipe)." unless target.respond_to?(:write)
        read(options) { |chunk| target.write chunk }
        target.flush
      end
    end

    # :call-seq:
    #   write(content, options?)
    #   write(options?) { |bytes| .. }
    #
    # Writes to the resource behind the URI. The first form writes the content from a string or an object
    # that responds to +read+ and optionally +size+. The second form writes the content by yielding to the
    # block. Each yield should return up to the specified number of bytes, the last yield returns nil.
    #
    # For options, see URI::write.
    def write(*args, &block)
      options = args.pop if Hash === args.last
      options ||= {}
      if String === args.first
        ios = StringIO.new(args.first, "r")
        write(options.merge(:size => args.first.size)) { |bytes| ios.read(bytes) }
      elsif args.first.respond_to?(:read)
        size = args.first.size rescue nil
        write({ :size => size }.merge(options)) { |bytes| args.first.read(bytes) }
      elsif args.empty? && block
        write_internal(options, &block)
      else
        raise ArgumentError, "Either give me the content, or pass me a block, otherwise what would I upload?"
      end
    end

  protected

    # :call-seq:
    #   with_progress_bar(enable, file_name, size) { |progress| ... }
    #
    # Displays a progress bar while executing the block. The first argument must be true for the
    # progress bar to show (TTY output also required), as a convenient for selectively using the
    # progress bar from a single block.
    #
    # The second argument provides a filename to display, the third its size in bytes.
    #
    # The block is yielded with a progress object that implements a single method.
    # Call << for each block of bytes down/uploaded.
    def with_progress_bar(enable, file_name, size) #:nodoc:
      file_name = CGI.unescape(file_name)
      if enable && $stdout.isatty
        progress_bar = Console::ProgressBar.new(file_name, size)
        # Extend the progress bar so we can display count/total.
        class << progress_bar
          def total()
            convert_bytes(@total)
          end
        end
        # Squeeze the filename into 30 characters.
        unescaped = CGI.unescape(file_name)
        if unescaped.size > 30
          base, ext = File.basename(unescaped), File.extname(unescaped)
          truncated = "#{base[0..26-ext.to_s.size]}..#{ext}"
        else
          truncated = unescaped
        end
        progress_bar.format = "#{truncated}: %3d%% %s %s/%s %s"
        progress_bar.format_arguments = [:percentage, :bar, :bytes, :total, :stat]
        progress_bar.bar_mark = "o"

        begin
          class << progress_bar
            def <<(bytes)
              inc bytes.respond_to?(:size) ? bytes.size : bytes
            end
          end
          yield progress_bar
        ensure
          progress_bar.finish
        end
      else
        progress_bar = Object.new
        class << progress_bar
          def <<(bytes)
          end
        end
        yield progress_bar
      end
    end

    # :call-seq:
    #   proxy_uri() => URI?
    #
    # Returns the proxy server to use. Obtains the proxy from the relevant environment variable (e.g. HTTP_PROXY).
    # Supports exclusions based on host name and port number from environment variable NO_PROXY.
    def proxy_uri()
      proxy = ENV["#{scheme.upcase}_PROXY"]
      proxy = URI.parse(proxy) if String === proxy
      excludes = (ENV["NO_PROXY"] || "").split(/\s*,\s*/).compact
      excludes = excludes.map { |exclude| exclude =~ /:\d+$/ ? exclude : "#{exclude}:*" }
      return proxy unless excludes.any? { |exclude| File.fnmatch(exclude, "#{host}:#{port}") }
    end

    def write_internal(options, &block) #:nodoc:
      fail "This protocol doesn't support writing (yet, how about helping by implementing it?)"
    end
  end

  class HTTP #:nodoc:

    # See URI::Generic#read
    def read(options = nil, &block)
      options ||= {}
      connect do |http|
        puts "Requesting #{self}" if Rake.application.options.verbose
        headers = { 'If-Modified-Since' => CGI.rfc1123_date(options[:modified].utc) } if options[:modified]
        request = Net::HTTP::Get.new(request_uri.empty? ? '/' : request_uri, headers)
        request.basic_auth self.user, self.password if self.user
        http.request request do |response|
          case response
          when Net::HTTPNotModified
            # No modification, nothing to do.
            puts 'Not modified since last download' if Rake.application.options.verbose
            return nil
          when Net::HTTPRedirection
            # Try to download from the new URI, handle relative redirects.
            puts "Redirected to #{response['Location']}" if Rake.application.options.verbose
            return (self + URI.parse(response['location'])).read(options, &block)
          when Net::HTTPOK
            puts "Downloading #{self}" if Rake.application.options.verbose
            result = nil
            with_progress_bar options[:progress], path.split('/').last, response.content_length do |progress|
              if block
                response.read_body do |chunk|
                  block.call chunk
                  progress << chunk
                end
              else
                result = ''
                response.read_body do |chunk|
                  result << chunk
                  progress << chunk
                end
              end
            end
            return result
          when Net::HTTPNotFound
            raise NotFoundError, "Looking for #{self} and all I got was a 404!"
          else
            raise RuntimeError, "Failed to download #{self}: #{response.message}"
          end
        end
      end
    end

  private

    def connect
      if proxy = proxy_uri
        proxy = URI.parse(proxy) if String === proxy
        http = Net::HTTP.new(host, port, proxy.host, proxy.port, proxy.user, proxy.password)
      else
        http = Net::HTTP.new(host, port)
      end
      if self.instance_of? URI::HTTPS
        cacert = "downloads/#{RubyInstaller::Certificate.file}"
        http.use_ssl = true
        if File.exist?(cacert)
          http.ca_file = cacert
        else
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end
      yield http
    end
  end  
end
