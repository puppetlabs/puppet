require 'digest'
require 'fileutils'

module RGen

module Util

# Implements a cache for storing and loading data associated with arbitrary files.
# The data is stored in cache files within a subfolder of the folder where
# the associated files exists.
# The cache files are protected with a checksum and loaded data will be
# invalid in case either the associated file are the cache file has changed.
#
class FileCacheMap
  # optional program version info to be associated with the cache files
  # if the program version changes, cached data will also be invalid
  attr_accessor :version_info

  # +cache_dir+ is the name of the subfolder where cache files are created
  # +postfix+ is an extension appended to the original file name for 
  # creating the name of the cache file
  def initialize(cache_dir, postfix)
    @postfix = postfix
    @cache_dir = cache_dir
  end

  # load data associated with file +key_path+
  # returns :invalid in case either the associated file or the cache file has changed
  #
  # options:
  #  :invalidation_reasons:
  #    an array which will receive symbols indicating why the cache is invalid:
  #    :no_cachefile, :cachefile_corrupted, :keyfile_changed
  #
  def load_data(key_path, options={})
    reasons = options[:invalidation_reasons] || []
    cf = cache_file(key_path)
    result = nil
    begin
      File.open(cf, "rb") do |f|
        header = f.read(41)
        if !header
          reasons << :cachefile_corrupted
          return :invalid
        end
        checksum = header[0..39]
        data = f.read
        if calc_sha1(data) == checksum
          if calc_sha1_keydata(key_path) == data[0..39]
            result = data[41..-1]
          else
            reasons << :keyfile_changed
            result = :invalid
          end
        else
          reasons << :cachefile_corrupted
          result = :invalid
        end
      end 
    rescue Errno::ENOENT
      reasons << :no_cachefile
      result = :invalid 
    end
    result
  end

  # store data +value_data+ associated with file +key_path+
  def store_data(key_path, value_data)
    data = calc_sha1_keydata(key_path) + "\n" + value_data
    data = calc_sha1(data) + "\n" + data
    cf = cache_file(key_path)
    FileUtils.mkdir(File.dirname(cf)) rescue Errno::EEXIST
    File.open(cf, "wb") do |f|
      f.write(data)
    end 
  end

  # remove cache files which are not associated with any file in +key_paths+
  # will only remove files within +root_path+
  def clean_unused(root_path, key_paths)
    raise "key paths must be within root path" unless key_paths.all?{|p| p.index(root_path) == 0}
    used_files = key_paths.collect{|p| cache_file(p)}
    files = Dir[root_path+"/**/"+@cache_dir+"/*"+@postfix] 
    files.each do |f|
      FileUtils.rm(f) unless used_files.include?(f)
    end
  end

private
  
  def cache_file(path)
    File.dirname(path) + "/"+@cache_dir+"/" + File.basename(path) + @postfix 
  end

  def calc_sha1(data)
    sha1 = Digest::SHA1.new
    sha1.update(data)
    sha1.hexdigest
  end

  def keyData(path)
    File.read(path)+@version_info.to_s
  end

  # this method is much faster than calling +keyData+ and putting the result in +calc_sha1+
  # reason is probably that there are not so many big strings being created
  def calc_sha1_keydata(path)
    begin
      sha1 = Digest::SHA1.new
      sha1.file(path)
      sha1.update(@version_info.to_s)
      sha1.hexdigest
    rescue Errno::ENOENT
      "<missing_key_file>"
    end
  end
   
end

end

end


