require 'test/unit'

$:.unshift(File.dirname(__FILE__) + '/../lib/')
require 'deep_merge'

# Assume strings have a blank? method
# as they do when ActiveSupport is included.
module StringBlank
  def blank?
    size == 0
  end
end

class TestDeepMerge < Test::Unit::TestCase

  def setup
  end

  # show that Hash object has deep merge capabilities in form of three methods:
  #   ko_deep_merge! # uses '--' knockout and overwrites unmergeable
  #   deep_merge! # overwrites unmergeable
  #   deep_merge # skips unmergeable
  def test_hash_deep_merge
    x = {}
    assert x.respond_to?('deep_merge!'.to_sym)
    hash_src  = {'id' => [3,4,5]}
    hash_dest = {'id' => [1,2,3]}
    assert hash_dest.ko_deep_merge!(hash_src)
    assert_equal({'id' => [1,2,3,4,5]}, hash_dest)

    hash_src  = {'id' => [3,4,5]}
    hash_dest = {'id' => [1,2,3]}
    assert hash_dest.deep_merge!(hash_src)
    assert_equal({'id' => [1,2,3,4,5]}, hash_dest)

    hash_src  = {'id' => 'xxx'}
    hash_dest = {'id' => [1,2,3]}
    assert hash_dest.deep_merge(hash_src)
    assert_equal({'id' => [1,2,3]}, hash_dest)
  end

  FIELD_KNOCKOUT_PREFIX = DeepMerge::DEFAULT_FIELD_KNOCKOUT_PREFIX

  # tests DeepMerge::deep_merge! function
  def test_deep_merge
    # merge tests (moving from basic to more complex)

    # test merging an hash w/array into blank hash
    hash_src = {'id' => '2'}
    hash_dst = {}
    DeepMerge::deep_merge!(hash_src.dup, hash_dst, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal hash_src, hash_dst

    # test merging an hash w/array into blank hash
    hash_src = {'region' => {'id' => ['227', '2']}}
    hash_dst = {}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal hash_src, hash_dst

    # merge from empty hash
    hash_src = {}
    hash_dst = {"property" => ["2","4"]}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => ["2","4"]}, hash_dst)

    # merge to empty hash
    hash_src = {"property" => ["2","4"]}
    hash_dst = {}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => ["2","4"]}, hash_dst)

    # simple string overwrite
    hash_src = {"name" => "value"}
    hash_dst = {"name" => "value1"}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"name" => "value"}, hash_dst)

    # simple string overwrite of empty hash
    hash_src = {"name" => "value"}
    hash_dst = {}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal(hash_src, hash_dst)

    # hashes holding array
    hash_src = {"property" => ["1","3"]}
    hash_dst = {"property" => ["2","4"]}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal(["2","4","1","3"], hash_dst['property'])

    # hashes holding array (sorted)
    hash_src = {"property" => ["1","3"]}
    hash_dst = {"property" => ["2","4"]}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:sort_merged_arrays => true})
    assert_equal(["1","2","3","4"].sort, hash_dst['property'])

    # hashes holding hashes holding arrays (array with duplicate elements is merged with dest then src
    hash_src = {"property" => {"bedroom_count" => ["1", "2"], "bathroom_count" => ["1", "4+"]}}
    hash_dst = {"property" => {"bedroom_count" => ["3", "2"], "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => {"bedroom_count" => ["3","2","1"], "bathroom_count" => ["2", "1", "4+"]}}, hash_dst)

    # hash holding hash holding array v string (string is overwritten by array)
    hash_src = {"property" => {"bedroom_count" => ["1", "2"], "bathroom_count" => ["1", "4+"]}}
    hash_dst = {"property" => {"bedroom_count" => "3", "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => {"bedroom_count" => ["1", "2"], "bathroom_count" => ["2","1","4+"]}}, hash_dst)

    # hash holding hash holding array v string (string is NOT overwritten by array)
    hash_src = {"property" => {"bedroom_count" => ["1", "2"], "bathroom_count" => ["1", "4+"]}}
    hash_dst = {"property" => {"bedroom_count" => "3", "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:preserve_unmergeables => true})
    assert_equal({"property" => {"bedroom_count" => "3", "bathroom_count" => ["2","1","4+"]}}, hash_dst)

    # hash holding hash holding string v array (array is overwritten by string)
    hash_src = {"property" => {"bedroom_count" => "3", "bathroom_count" => ["1", "4+"]}}
    hash_dst = {"property" => {"bedroom_count" => ["1", "2"], "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => {"bedroom_count" => "3", "bathroom_count" => ["2","1","4+"]}}, hash_dst)

    # hash holding hash holding string v array (array does NOT overwrite string)
    hash_src = {"property" => {"bedroom_count" => "3", "bathroom_count" => ["1", "4+"]}}
    hash_dst = {"property" => {"bedroom_count" => ["1", "2"], "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:preserve_unmergeables => true})
    assert_equal({"property" => {"bedroom_count" => ["1", "2"], "bathroom_count" => ["2","1","4+"]}}, hash_dst)

    # hash holding hash holding hash v array (array is overwritten by hash)
    hash_src = {"property" => {"bedroom_count" => {"king_bed" => 3, "queen_bed" => 1}, "bathroom_count" => ["1", "4+"]}}
    hash_dst = {"property" => {"bedroom_count" => ["1", "2"], "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => {"bedroom_count" => {"king_bed" => 3, "queen_bed" => 1}, "bathroom_count" => ["2","1","4+"]}}, hash_dst)

    # hash holding hash holding hash v array (array is NOT overwritten by hash)
    hash_src = {"property" => {"bedroom_count" => {"king_bed" => 3, "queen_bed" => 1}, "bathroom_count" => ["1", "4+"]}}
    hash_dst = {"property" => {"bedroom_count" => ["1", "2"], "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:preserve_unmergeables => true})
    assert_equal({"property" => {"bedroom_count" => ["1", "2"], "bathroom_count" => ["2","1","4+"]}}, hash_dst)

    # 3 hash layers holding integers (integers are overwritten by source)
    hash_src = {"property" => {"bedroom_count" => {"king_bed" => 3, "queen_bed" => 1}, "bathroom_count" => ["1", "4+"]}}
    hash_dst = {"property" => {"bedroom_count" => {"king_bed" => 2, "queen_bed" => 4}, "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => {"bedroom_count" => {"king_bed" => 3, "queen_bed" => 1}, "bathroom_count" => ["2","1","4+"]}}, hash_dst)

    # 3 hash layers holding arrays of int (arrays are merged)
    hash_src = {"property" => {"bedroom_count" => {"king_bed" => [3], "queen_bed" => [1]}, "bathroom_count" => ["1", "4+"]}}
    hash_dst = {"property" => {"bedroom_count" => {"king_bed" => [2], "queen_bed" => [4]}, "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => {"bedroom_count" => {"king_bed" => [2,3], "queen_bed" => [4,1]}, "bathroom_count" => ["2","1","4+"]}}, hash_dst)

    # 1 hash overwriting 3 hash layers holding arrays of int
    hash_src = {"property" => "1"}
    hash_dst = {"property" => {"bedroom_count" => {"king_bed" => [2], "queen_bed" => [4]}, "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => "1"}, hash_dst)

    # 1 hash NOT overwriting 3 hash layers holding arrays of int
    hash_src = {"property" => "1"}
    hash_dst = {"property" => {"bedroom_count" => {"king_bed" => [2], "queen_bed" => [4]}, "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:preserve_unmergeables => true})
    assert_equal({"property" => {"bedroom_count" => {"king_bed" => [2], "queen_bed" => [4]}, "bathroom_count" => ["2"]}}, hash_dst)

    # 3 hash layers holding arrays of int (arrays are merged) but second hash's array is overwritten
    hash_src = {"property" => {"bedroom_count" => {"king_bed" => [3], "queen_bed" => [1]}, "bathroom_count" => "1"}}
    hash_dst = {"property" => {"bedroom_count" => {"king_bed" => [2], "queen_bed" => [4]}, "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => {"bedroom_count" => {"king_bed" => [2,3], "queen_bed" => [4,1]}, "bathroom_count" => "1"}}, hash_dst)

    # 3 hash layers holding arrays of int (arrays are merged) but second hash's array is NOT overwritten
    hash_src = {"property" => {"bedroom_count" => {"king_bed" => [3], "queen_bed" => [1]}, "bathroom_count" => "1"}}
    hash_dst = {"property" => {"bedroom_count" => {"king_bed" => [2], "queen_bed" => [4]}, "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:preserve_unmergeables => true})
    assert_equal({"property" => {"bedroom_count" => {"king_bed" => [2,3], "queen_bed" => [4,1]}, "bathroom_count" => ["2"]}}, hash_dst)

    # 3 hash layers holding arrays of int, but one holds int. This one overwrites, but the rest merge
    hash_src = {"property" => {"bedroom_count" => {"king_bed" => 3, "queen_bed" => [1]}, "bathroom_count" => ["1"]}}
    hash_dst = {"property" => {"bedroom_count" => {"king_bed" => [2], "queen_bed" => [4]}, "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => {"bedroom_count" => {"king_bed" => 3, "queen_bed" => [4,1]}, "bathroom_count" => ["2","1"]}}, hash_dst)

    # 3 hash layers holding arrays of int, but source is incomplete.
    hash_src = {"property" => {"bedroom_count" => {"king_bed" => [3]}, "bathroom_count" => ["1"]}}
    hash_dst = {"property" => {"bedroom_count" => {"king_bed" => [2], "queen_bed" => [4]}, "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => {"bedroom_count" => {"king_bed" => [2,3], "queen_bed" => [4]}, "bathroom_count" => ["2","1"]}}, hash_dst)

    # 3 hash layers holding arrays of int, but source is shorter and has new 2nd level ints.
    hash_src = {"property" => {"bedroom_count" => {2=>3, "king_bed" => [3]}, "bathroom_count" => ["1"]}}
    hash_dst = {"property" => {"bedroom_count" => {"king_bed" => [2], "queen_bed" => [4]}, "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => {"bedroom_count" => {2=>3, "king_bed" => [2,3], "queen_bed" => [4]}, "bathroom_count" => ["2","1"]}}, hash_dst)

    # 3 hash layers holding arrays of int, but source is empty
    hash_src = {}
    hash_dst = {"property" => {"bedroom_count" => {"king_bed" => [2], "queen_bed" => [4]}, "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => {"bedroom_count" => {"king_bed" => [2], "queen_bed" => [4]}, "bathroom_count" => ["2"]}}, hash_dst)

    # 3 hash layers holding arrays of int, but dest is empty
    hash_src = {"property" => {"bedroom_count" => {2=>3, "king_bed" => [3]}, "bathroom_count" => ["1"]}}
    hash_dst = {}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => {"bedroom_count" => {2=>3, "king_bed" => [3]}, "bathroom_count" => ["1"]}}, hash_dst)

    # 3 hash layers holding arrays of int, but source includes a nil in the array
    hash_src = {"property" => {"bedroom_count" => {"king_bed" => [nil], "queen_bed" => [1, nil]}, "bathroom_count" => [nil, "1"]}}
    hash_dst = {"property" => {"bedroom_count" => {"king_bed" => [2], "queen_bed" => [4]}, "bathroom_count" => ["2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => {"bedroom_count" => {"king_bed" => [2,nil], "queen_bed" => [4, 1, nil]}, "bathroom_count" => ["2", nil, "1"]}}, hash_dst)

    # 3 hash layers holding arrays of int, but destination includes a nil in the array
    hash_src = {"property" => {"bedroom_count" => {"king_bed" => [3], "queen_bed" => [1]}, "bathroom_count" => ["1"]}}
    hash_dst = {"property" => {"bedroom_count" => {"king_bed" => [nil], "queen_bed" => [4, nil]}, "bathroom_count" => [nil,"2"]}}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"property" => {"bedroom_count" => {"king_bed" => [nil, 3], "queen_bed" => [4, nil, 1]}, "bathroom_count" => [nil, "2", "1"]}}, hash_dst)

    # test parameter management for knockout_prefix and overwrite unmergable
    assert_raise(DeepMerge::InvalidParameter) {DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => ""})}
    assert_raise(DeepMerge::InvalidParameter) {DeepMerge::deep_merge!(hash_src, hash_dst, {:preserve_unmergeables => true, :knockout_prefix => ""})}
    assert_raise(DeepMerge::InvalidParameter) {DeepMerge::deep_merge!(hash_src, hash_dst, {:preserve_unmergeables => true, :knockout_prefix => "--"})}
    assert_nothing_raised(DeepMerge::InvalidParameter) {DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => "--"})}
    assert_nothing_raised(DeepMerge::InvalidParameter) {DeepMerge::deep_merge!(hash_src, hash_dst)}
    assert_nothing_raised(DeepMerge::InvalidParameter) {DeepMerge::deep_merge!(hash_src, hash_dst, {:preserve_unmergeables => true})}

    # hash holding arrays of arrays
    hash_src = {["1", "2", "3"] => ["1", "2"]}
    hash_dst = {["4", "5"] => ["3"]}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({["1","2","3"] => ["1", "2"], ["4", "5"] => ["3"]}, hash_dst)

    # test merging of hash with blank hash, and make sure that source array split still functions
    hash_src = {'property' => {'bedroom_count' => ["1","2,3"]}}
    hash_dst = {}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({'property' => {'bedroom_count' => ["1","2","3"]}}, hash_dst)

    # test merging of hash with blank hash, and make sure that source array split does not function when turned off
    hash_src = {'property' => {'bedroom_count' => ["1","2,3"]}}
    hash_dst = {}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX})
    assert_equal({'property' => {'bedroom_count' => ["1","2,3"]}}, hash_dst)

    # test merging into a blank hash with overwrite_unmergeables turned on
    hash_src = {"action"=>"browse", "controller"=>"results"}
    hash_dst = {}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:overwrite_unmergeables => true, :knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal hash_src, hash_dst

    # KNOCKOUT_PREFIX testing
    # the next few tests are looking for correct behavior from specific real-world params/session merges
    # using the custom modifiers built for param/session merges

    [nil, ","].each do |ko_split|
      # typical params/session style hash with knockout_merge elements
      hash_params = {"property"=>{"bedroom_count"=>[FIELD_KNOCKOUT_PREFIX+"1", "2", "3"]}}
      hash_session = {"property"=>{"bedroom_count"=>["1", "2", "3"]}}
      DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ko_split})
      assert_equal({"property"=>{"bedroom_count"=>["2", "3"]}}, hash_session)

      # typical params/session style hash with knockout_merge elements
      hash_params = {"property"=>{"bedroom_count"=>[FIELD_KNOCKOUT_PREFIX+"1", "2", "3"]}}
      hash_session = {"property"=>{"bedroom_count"=>["3"]}}
      DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ko_split})
      assert_equal({"property"=>{"bedroom_count"=>["3","2"]}}, hash_session)

      # typical params/session style hash with knockout_merge elements
      hash_params = {"property"=>{"bedroom_count"=>[FIELD_KNOCKOUT_PREFIX+"1", "2", "3"]}}
      hash_session = {"property"=>{"bedroom_count"=>["4"]}}
      DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ko_split})
      assert_equal({"property"=>{"bedroom_count"=>["4","2","3"]}}, hash_session)

      # typical params/session style hash with knockout_merge elements
      hash_params = {"property"=>{"bedroom_count"=>[FIELD_KNOCKOUT_PREFIX+"1", "2", "3"]}}
      hash_session = {"property"=>{"bedroom_count"=>[FIELD_KNOCKOUT_PREFIX+"1", "4"]}}
      DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ko_split})
      assert_equal({"property"=>{"bedroom_count"=>["4","2","3"]}}, hash_session)

      # typical params/session style hash with knockout_merge elements
      hash_params = {"amenity"=>{"id"=>[FIELD_KNOCKOUT_PREFIX+"1", FIELD_KNOCKOUT_PREFIX+"2", "3", "4"]}}
      hash_session = {"amenity"=>{"id"=>["1", "2"]}}
      DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ko_split})
      assert_equal({"amenity"=>{"id"=>["3","4"]}}, hash_session)
    end

    # special params/session style hash with knockout_merge elements in form src: ["1","2"] dest:["--1,--2", "3,4"]
    hash_params = {"amenity"=>{"id"=>[FIELD_KNOCKOUT_PREFIX+"1,"+FIELD_KNOCKOUT_PREFIX+"2", "3,4"]}}
    hash_session = {"amenity"=>{"id"=>["1", "2"]}}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({"amenity"=>{"id"=>["3","4"]}}, hash_session)

    # same as previous but without ko_split value, this merge should fail
    hash_params = {"amenity"=>{"id"=>[FIELD_KNOCKOUT_PREFIX+"1,"+FIELD_KNOCKOUT_PREFIX+"2", "3,4"]}}
    hash_session = {"amenity"=>{"id"=>["1", "2"]}}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX})
    assert_equal({"amenity"=>{"id"=>["1","2","3,4"]}}, hash_session)

    # special params/session style hash with knockout_merge elements in form src: ["1","2"] dest:["--1,--2", "3,4"]
    hash_params = {"amenity"=>{"id"=>[FIELD_KNOCKOUT_PREFIX+"1,2", "3,4", "--5", "6"]}}
    hash_session = {"amenity"=>{"id"=>["1", "2"]}}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({"amenity"=>{"id"=>["2","3","4","6"]}}, hash_session)

    # special params/session style hash with knockout_merge elements in form src: ["--1,--2", "3,4", "--5", "6"] dest:["1,2", "3,4"]
    hash_params = {"amenity"=>{"id"=>["#{FIELD_KNOCKOUT_PREFIX}1,#{FIELD_KNOCKOUT_PREFIX}2", "3,4", "#{FIELD_KNOCKOUT_PREFIX}5", "6"]}}
    hash_session = {"amenity"=>{"id"=>["1", "2", "3", "4"]}}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({"amenity"=>{"id"=>["3","4","6"]}}, hash_session)


    hash_src = {"url_regions"=>[], "region"=>{"ids"=>["227,233"]}, "action"=>"browse", "task"=>"browse", "controller"=>"results"}
    hash_dst = {"region"=>{"ids"=>["227"]}}
    DeepMerge::deep_merge!(hash_src.dup, hash_dst, {:overwrite_unmergeables => true, :knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({"url_regions"=>[], "region"=>{"ids"=>["227","233"]}, "action"=>"browse", "task"=>"browse", "controller"=>"results"}, hash_dst)

    hash_src = {"region"=>{"ids"=>["--","227"], "id"=>"230"}}
    hash_dst = {"region"=>{"ids"=>["227", "233", "324", "230", "230"], "id"=>"230"}}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:overwrite_unmergeables => true, :knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({"region"=>{"ids"=>["227"], "id"=>"230"}}, hash_dst)

    hash_src = {"region"=>{"ids"=>["--","227", "232", "233"], "id"=>"232"}}
    hash_dst = {"region"=>{"ids"=>["227", "233", "324", "230", "230"], "id"=>"230"}}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:overwrite_unmergeables => true, :knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({"region"=>{"ids"=>["227", "232", "233"], "id"=>"232"}}, hash_dst)

    hash_src = {"region"=>{"ids"=>["--,227,232,233"], "id"=>"232"}}
    hash_dst = {"region"=>{"ids"=>["227", "233", "324", "230", "230"], "id"=>"230"}}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:overwrite_unmergeables => true, :knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({"region"=>{"ids"=>["227", "232", "233"], "id"=>"232"}}, hash_dst)

    hash_src = {"region"=>{"ids"=>["--,227,232","233"], "id"=>"232"}}
    hash_dst = {"region"=>{"ids"=>["227", "233", "324", "230", "230"], "id"=>"230"}}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:overwrite_unmergeables => true, :knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({"region"=>{"ids"=>["227", "232", "233"], "id"=>"232"}}, hash_dst)

    hash_src = {"region"=>{"ids"=>["--,227"], "id"=>"230"}}
    hash_dst = {"region"=>{"ids"=>["227", "233", "324", "230", "230"], "id"=>"230"}}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:overwrite_unmergeables => true, :knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({"region"=>{"ids"=>["227"], "id"=>"230"}}, hash_dst)

    hash_src = {"region"=>{"ids"=>["--,227"], "id"=>"230"}}
    hash_dst = {"region"=>{"ids"=>["227", "233", "324", "230", "230"], "id"=>"230"}, "action"=>"browse", "task"=>"browse", "controller"=>"results", "property_order_by"=>"property_type.descr"}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:overwrite_unmergeables => true, :knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({"region"=>{"ids"=>["227"], "id"=>"230"}, "action"=>"browse", "task"=>"browse",
      "controller"=>"results", "property_order_by"=>"property_type.descr"}, hash_dst)

    hash_src = {"query_uuid"=>"6386333d-389b-ab5c-8943-6f3a2aa914d7", "region"=>{"ids"=>["--,227"], "id"=>"230"}}
    hash_dst = {"query_uuid"=>"6386333d-389b-ab5c-8943-6f3a2aa914d7", "url_regions"=>[], "region"=>{"ids"=>["227", "233", "324", "230", "230"], "id"=>"230"}, "action"=>"browse", "task"=>"browse", "controller"=>"results", "property_order_by"=>"property_type.descr"}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:overwrite_unmergeables => true, :knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({"query_uuid" => "6386333d-389b-ab5c-8943-6f3a2aa914d7", "url_regions"=>[],
      "region"=>{"ids"=>["227"], "id"=>"230"}, "action"=>"browse", "task"=>"browse",
      "controller"=>"results", "property_order_by"=>"property_type.descr"}, hash_dst)

    # knock out entire dest hash if "--" is passed for source
    hash_params = {'amenity' => "--"}
    hash_session = {"amenity" => "1"}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => "--", :unpack_arrays => ","})
    assert_equal({'amenity' => ""}, hash_session)

    # knock out entire dest hash if "--" is passed for source
    hash_params = {'amenity' => ["--"]}
    hash_session = {"amenity" => "1"}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => "--", :unpack_arrays => ","})
    assert_equal({'amenity' => []}, hash_session)

    # knock out entire dest hash if "--" is passed for source
    hash_params = {'amenity' => "--"}
    hash_session = {"amenity" => ["1"]}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => "--", :unpack_arrays => ","})
    assert_equal({'amenity' => ""}, hash_session)

    # knock out entire dest hash if "--" is passed for source
    hash_params = {'amenity' => ["--"]}
    hash_session = {"amenity" => ["1"]}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => "--", :unpack_arrays => ","})
    assert_equal({'amenity' => []}, hash_session)

    # knock out entire dest hash if "--" is passed for source
    hash_params = {'amenity' => ["--"]}
    hash_session = {"amenity" => "1"}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => "--", :unpack_arrays => ","})
    assert_equal({'amenity' => []}, hash_session)

    # knock out entire dest hash if "--" is passed for source
    hash_params = {'amenity' => ["--", "2"]}
    hash_session = {'amenity' => ["1", "3", "7+"]}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => "--", :unpack_arrays => ","})
    assert_equal({'amenity' => ["2"]}, hash_session)

    # knock out entire dest hash if "--" is passed for source
    hash_params = {'amenity' => ["--", "2"]}
    hash_session = {'amenity' => "5"}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => "--", :unpack_arrays => ","})
    assert_equal({'amenity' => ['2']}, hash_session)

    # knock out entire dest hash if "--" is passed for source
    hash_params = {'amenity' => "--"}
    hash_session = {"amenity"=>{"id"=>["1", "2", "3", "4"]}}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => "--", :unpack_arrays => ","})
    assert_equal({'amenity' => ""}, hash_session)

    # knock out entire dest hash if "--" is passed for source
    hash_params = {'amenity' => ["--"]}
    hash_session = {"amenity"=>{"id"=>["1", "2", "3", "4"]}}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => "--", :unpack_arrays => ","})
    assert_equal({'amenity' => []}, hash_session)

    # knock out dest array if "--" is passed for source
    hash_params = {"region" => {'ids' => FIELD_KNOCKOUT_PREFIX}}
    hash_session = {"region"=>{"ids"=>["1", "2", "3", "4"]}}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({'region' => {'ids' => ""}}, hash_session)

    # knock out dest array but leave other elements of hash intact
    hash_params = {"region" => {'ids' => FIELD_KNOCKOUT_PREFIX}}
    hash_session = {"region"=>{"ids"=>["1", "2", "3", "4"], 'id'=>'11'}}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({'region' => {'ids' => "", 'id'=>'11'}}, hash_session)

    # knock out entire tree of dest hash
    hash_params = {"region" => FIELD_KNOCKOUT_PREFIX}
    hash_session = {"region"=>{"ids"=>["1", "2", "3", "4"], 'id'=>'11'}}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({'region' => ""}, hash_session)

    # knock out entire tree of dest hash - retaining array format
    hash_params = {"region" => {'ids' => [FIELD_KNOCKOUT_PREFIX]}}
    hash_session = {"region"=>{"ids"=>["1", "2", "3", "4"], 'id'=>'11'}}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({'region' => {'ids' => [], 'id'=>'11'}}, hash_session)

    # knock out entire tree of dest hash & replace with new content
    hash_params = {"region" => {'ids' => ["2", FIELD_KNOCKOUT_PREFIX, "6"]}}
    hash_session = {"region"=>{"ids"=>["1", "2", "3", "4"], 'id'=>'11'}}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({'region' => {'ids' => ["2", "6"], 'id'=>'11'}}, hash_session)

    # knock out entire tree of dest hash & replace with new content
    hash_params = {"region" => {'ids' => ["7", FIELD_KNOCKOUT_PREFIX, "6"]}}
    hash_session = {"region"=>{"ids"=>["1", "2", "3", "4"], 'id'=>'11'}}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({'region' => {'ids' => ["7", "6"], 'id'=>'11'}}, hash_session)

    # edge test: make sure that when we turn off knockout_prefix that all values are processed correctly
    hash_params = {"region" => {'ids' => ["7", "--", "2", "6,8"]}}
    hash_session = {"region"=>{"ids"=>["1", "2", "3", "4"], 'id'=>'11'}}
    DeepMerge::deep_merge!(hash_params, hash_session, {:unpack_arrays => ","})
    assert_equal({'region' => {'ids' => ["1", "2", "3", "4", "7", "--", "6", "8"], 'id'=>'11'}}, hash_session)

    # edge test 2: make sure that when we turn off source array split that all values are processed correctly
    hash_params = {"region" => {'ids' => ["7", "3", "--", "6,8"]}}
    hash_session = {"region"=>{"ids"=>["1", "2", "3", "4"], 'id'=>'11'}}
    DeepMerge::deep_merge!(hash_params, hash_session)
    assert_equal({'region' => {'ids' => ["1", "2", "3", "4", "7", "--", "6,8"], 'id'=>'11'}}, hash_session)

    # Example: src = {'key' => "--1"}, dst = {'key' => "1"} -> merges to {'key' => ""}
    hash_params = {"amenity"=>"--1"}
    hash_session = {"amenity"=>"1"}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX})
    assert_equal({"amenity"=>""}, hash_session)

    # Example: src = {'key' => "--1"}, dst = {'key' => "2"} -> merges to {'key' => ""}
    hash_params = {"amenity"=>"--1"}
    hash_session = {"amenity"=>"2"}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX})
    assert_equal({"amenity"=>""}, hash_session)

    # Example: src = {'key' => "--1"}, dst = {'key' => "1"} -> merges to {'key' => ""}
    hash_params = {"amenity"=>["--1"]}
    hash_session = {"amenity"=>"1"}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX})
    assert_equal({"amenity"=>[]}, hash_session)

    # Example: src = {'key' => "--1"}, dst = {'key' => "1"} -> merges to {'key' => ""}
    hash_params = {"amenity"=>["--1"]}
    hash_session = {"amenity"=>["1"]}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX})
    assert_equal({"amenity"=>[]}, hash_session)

    # Example: src = {'key' => "--1"}, dst = {'key' => "1"} -> merges to {'key' => ""}
    hash_params = {"amenity"=>"--1"}
    hash_session = {}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX})
    assert_equal({"amenity"=>""}, hash_session)


    # Example: src = {'key' => "--1"}, dst = {'key' => "1"} -> merges to {'key' => ""}
    hash_params = {"amenity"=>"--1"}
    hash_session = {"amenity"=>["1"]}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX})
    assert_equal({"amenity"=>""}, hash_session)

    #are unmerged hashes passed unmodified w/out :unpack_arrays?
    hash_params = {"amenity"=>{"id"=>["26,27"]}}
    hash_session = {}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX})
    assert_equal({"amenity"=>{"id"=>["26,27"]}}, hash_session)

    #hash should be merged
    hash_params = {"amenity"=>{"id"=>["26,27"]}}
    hash_session = {}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({"amenity"=>{"id"=>["26","27"]}}, hash_session)

    # second merge of same values should result in no change in output
    hash_params = {"amenity"=>{"id"=>["26,27"]}}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({"amenity"=>{"id"=>["26","27"]}}, hash_session)

    #hashes with knockout values are suppressed
    hash_params = {"amenity"=>{"id"=>["#{FIELD_KNOCKOUT_PREFIX}26,#{FIELD_KNOCKOUT_PREFIX}27,28"]}}
    hash_session = {}
    DeepMerge::deep_merge!(hash_params, hash_session, {:knockout_prefix => FIELD_KNOCKOUT_PREFIX, :unpack_arrays => ","})
    assert_equal({"amenity"=>{"id"=>["28"]}}, hash_session)

    hash_src= {'region' =>{'ids'=>['--']}, 'query_uuid' => 'zzz'}
    hash_dst= {'region' =>{'ids'=>['227','2','3','3']}, 'query_uuid' => 'zzz'}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => '--', :unpack_arrays => ","})
    assert_equal({'region' =>{'ids'=>[]}, 'query_uuid' => 'zzz'}, hash_dst)

    hash_src= {'region' =>{'ids'=>['--']}, 'query_uuid' => 'zzz'}
    hash_dst= {'region' =>{'ids'=>['227','2','3','3'], 'id' => '3'}, 'query_uuid' => 'zzz'}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => '--', :unpack_arrays => ","})
    assert_equal({'region' =>{'ids'=>[], 'id'=>'3'}, 'query_uuid' => 'zzz'}, hash_dst)

    hash_src= {'region' =>{'ids'=>['--']}, 'query_uuid' => 'zzz'}
    hash_dst= {'region' =>{'muni_city_id' => '2244', 'ids'=>['227','2','3','3'], 'id'=>'3'}, 'query_uuid' => 'zzz'}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => '--', :unpack_arrays => ","})
    assert_equal({'region' =>{'muni_city_id' => '2244', 'ids'=>[], 'id'=>'3'}, 'query_uuid' => 'zzz'}, hash_dst)

    hash_src= {'region' =>{'ids'=>['--'], 'id' => '5'}, 'query_uuid' => 'zzz'}
    hash_dst= {'region' =>{'muni_city_id' => '2244', 'ids'=>['227','2','3','3'], 'id'=>'3'}, 'query_uuid' => 'zzz'}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => '--', :unpack_arrays => ","})
    assert_equal({'region' =>{'muni_city_id' => '2244', 'ids'=>[], 'id'=>'5'}, 'query_uuid' => 'zzz'}, hash_dst)

    hash_src= {'region' =>{'ids'=>['--', '227'], 'id' => '5'}, 'query_uuid' => 'zzz'}
    hash_dst= {'region' =>{'muni_city_id' => '2244', 'ids'=>['227','2','3','3'], 'id'=>'3'}, 'query_uuid' => 'zzz'}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => '--', :unpack_arrays => ","})
    assert_equal({'region' =>{'muni_city_id' => '2244', 'ids'=>['227'], 'id'=>'5'}, 'query_uuid' => 'zzz'}, hash_dst)

    hash_src= {'region' =>{'muni_city_id' => '--', 'ids'=>'--', 'id'=>'5'}, 'query_uuid' => 'zzz'}
    hash_dst= {'region' =>{'muni_city_id' => '2244', 'ids'=>['227','2','3','3'], 'id'=>'3'}, 'query_uuid' => 'zzz'}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => '--', :unpack_arrays => ","})
    assert_equal({'region' =>{'muni_city_id' => '', 'ids'=>'', 'id'=>'5'}, 'query_uuid' => 'zzz'}, hash_dst)

    hash_src= {'region' =>{'muni_city_id' => '--', 'ids'=>['--'], 'id'=>'5'}, 'query_uuid' => 'zzz'}
    hash_dst= {'region' =>{'muni_city_id' => '2244', 'ids'=>['227','2','3','3'], 'id'=>'3'}, 'query_uuid' => 'zzz'}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => '--', :unpack_arrays => ","})
    assert_equal({'region' =>{'muni_city_id' => '', 'ids'=>[], 'id'=>'5'}, 'query_uuid' => 'zzz'}, hash_dst)

    hash_src= {'region' =>{'muni_city_id' => '--', 'ids'=>['--','227'], 'id'=>'5'}, 'query_uuid' => 'zzz'}
    hash_dst= {'region' =>{'muni_city_id' => '2244', 'ids'=>['227','2','3','3'], 'id'=>'3'}, 'query_uuid' => 'zzz'}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => '--', :unpack_arrays => ","})
    assert_equal({'region' =>{'muni_city_id' => '', 'ids'=>['227'], 'id'=>'5'}, 'query_uuid' => 'zzz'}, hash_dst)

    hash_src = {"muni_city_id"=>"--", "id"=>""}
    hash_dst = {"muni_city_id"=>"", "id"=>""}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => '--', :unpack_arrays => ","})
    assert_equal({"muni_city_id"=>"", "id"=>""}, hash_dst)

    hash_src = {"region"=>{"muni_city_id"=>"--", "id"=>""}}
    hash_dst = {"region"=>{"muni_city_id"=>"", "id"=>""}}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => '--', :unpack_arrays => ","})
    assert_equal({"region"=>{"muni_city_id"=>"", "id"=>""}}, hash_dst)

    hash_src = {"query_uuid"=>"a0dc3c84-ec7f-6756-bdb0-fff9157438ab", "url_regions"=>[], "region"=>{"muni_city_id"=>"--", "id"=>""}, "property"=>{"property_type_id"=>"", "search_rate_min"=>"", "search_rate_max"=>""}, "task"=>"search", "run_query"=>"Search"}
    hash_dst = {"query_uuid"=>"a0dc3c84-ec7f-6756-bdb0-fff9157438ab", "url_regions"=>[], "region"=>{"muni_city_id"=>"", "id"=>""}, "property"=>{"property_type_id"=>"", "search_rate_min"=>"", "search_rate_max"=>""}, "task"=>"search", "run_query"=>"Search"}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:knockout_prefix => '--', :unpack_arrays => ","})
    assert_equal({"query_uuid"=>"a0dc3c84-ec7f-6756-bdb0-fff9157438ab", "url_regions"=>[], "region"=>{"muni_city_id"=>"", "id"=>""}, "property"=>{"property_type_id"=>"", "search_rate_min"=>"", "search_rate_max"=>""}, "task"=>"search", "run_query"=>"Search"}, hash_dst)

    # hash of array of hashes
    hash_src = {"item" => [{"1" => "3"}, {"2" => "4"}]}
    hash_dst = {"item" => [{"3" => "5"}]}
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"item" => [{"3" => "5"}, {"1" => "3"}, {"2" => "4"}]}, hash_dst)

    ######################################
    # tests for "merge_hash_arrays" option

    hash_src = {"item" => [{"1" => "3"}]}
    hash_dst = {"item" => [{"3" => "5"}]}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:merge_hash_arrays => true})
    assert_equal({"item" => [{"3" => "5", "1" => "3"}]}, hash_dst)

    hash_src = {"item" => [{"1" => "3"}, {"2" => "4"}]}
    hash_dst = {"item" => [{"3" => "5"}]}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:merge_hash_arrays => true})
    assert_equal({"item" => [{"3" => "5", "1" => "3"}, {"2" => "4"}]}, hash_dst)

    hash_src = {"item" => [{"1" => "3"}]}
    hash_dst = {"item" => [{"3" => "5"}, {"2" => "4"}]}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:merge_hash_arrays => true})
    assert_equal({"item" => [{"3" => "5", "1" => "3"}, {"2" => "4"}]}, hash_dst)

    # if arrays contain non-hash objects, the :merge_hash_arrays option has
    # no effect.
    hash_src = {"item" => [{"1" => "3"}, "str"]}  # contains "str", non-hash
    hash_dst = {"item" => [{"3" => "5"}]}
    DeepMerge::deep_merge!(hash_src, hash_dst, {:merge_hash_arrays => true})
    assert_equal({"item" => [{"3" => "5"}, {"1" => "3"}, "str"]}, hash_dst)

    # Merging empty strings
    s1, s2 = "hello", ""
    [s1, s2].each { |s| s.extend StringBlank }
    hash_dst = {"item" => s1 }
    hash_src = {"item" => s2 }
    DeepMerge::deep_merge!(hash_src, hash_dst)
    assert_equal({"item" => ""}, hash_dst)
  end # test_deep_merge
end
