$:.unshift(File.dirname(__FILE__)+"/../../lib")

require 'test/unit'
require 'fileutils'
require 'rgen/util/file_cache_map'

class FileCacheMapTest < Test::Unit::TestCase

  TestDir = File.dirname(__FILE__)+"/file_cache_map_test/testdir"
 
  def setup
    FileUtils.rm_r(Dir[TestDir+"/*"])
    # * doesn't include dot files
    FileUtils.rm_r(Dir[TestDir+"/.cache"])
    @cm = RGen::Util::FileCacheMap.new(".cache", ".test")
  end
   
  def test_nocache
    reasons = []
    assert_equal(:invalid, @cm.load_data(TestDir+"/fileA", :invalidation_reasons => reasons))
    assert_equal [:no_cachefile], reasons
  end

  def test_storeload
    keyFile = TestDir+"/fileA"  
    File.open(keyFile, "w") {|f| f.write("somedata")}
    @cm.store_data(keyFile, "valuedata")
    assert(File.exist?(TestDir+"/.cache/fileA.test"))
    assert_equal("valuedata", @cm.load_data(keyFile))
  end

  def test_storeload_subdir
    keyFile = TestDir+"/subdir/fileA"
    FileUtils.mkdir(TestDir+"/subdir")
    File.open(keyFile, "w") {|f| f.write("somedata")}
    @cm.store_data(keyFile, "valuedata")
    assert(File.exist?(TestDir+"/subdir/.cache/fileA.test"))
    assert_equal("valuedata", @cm.load_data(keyFile))
  end

  def test_storeload_postfix
    keyFile = TestDir+"/fileB.txt"  
    File.open(keyFile, "w") {|f| f.write("somedata")}
    @cm.store_data(keyFile, "valuedata")
    assert(File.exist?(TestDir+"/.cache/fileB.txt.test"))
    assert_equal("valuedata", @cm.load_data(keyFile))
  end

  def test_storeload_empty
    keyFile = TestDir+"/fileA"  
    File.open(keyFile, "w") {|f| f.write("")}
    @cm.store_data(keyFile, "valuedata")
    assert(File.exist?(TestDir+"/.cache/fileA.test"))
    assert_equal("valuedata", @cm.load_data(keyFile))
  end

  def test_corruptcache
    keyFile = TestDir+"/fileA"
    File.open(keyFile, "w") {|f| f.write("somedata")}
    @cm.store_data(keyFile, "valuedata")
    File.open(TestDir+"/.cache/fileA.test","a") {|f| f.write("more data")}
    reasons = []
    assert_equal(:invalid, @cm.load_data(keyFile, :invalidation_reasons => reasons))
    assert_equal [:cachefile_corrupted], reasons
  end  

  def test_changedcontent
    keyFile = TestDir+"/fileA"
    File.open(keyFile, "w") {|f| f.write("somedata")}
    @cm.store_data(keyFile, "valuedata")
    File.open(keyFile, "a") {|f| f.write("more data")}
    reasons = []
    assert_equal(:invalid, @cm.load_data(keyFile, :invalidation_reasons => reasons))
    assert_equal [:keyfile_changed], reasons
  end 

  def test_versioninfo
    keyFile = TestDir+"/fileA"  
    File.open(keyFile, "w") {|f| f.write("somedata")}
    @cm.version_info = "123"
    @cm.store_data(keyFile, "valuedata")
    assert(File.exist?(TestDir+"/.cache/fileA.test"))
    assert_equal("valuedata", @cm.load_data(keyFile))
  end

  def test_changed_version
    keyFile = TestDir+"/fileA"  
    File.open(keyFile, "w") {|f| f.write("somedata")}
    @cm.version_info = "123"
    @cm.store_data(keyFile, "valuedata")
    @cm.version_info = "456"
    reasons = []
    assert_equal(:invalid, @cm.load_data(keyFile, :invalidation_reasons => reasons))
    assert_equal [:keyfile_changed], reasons
  end

end


