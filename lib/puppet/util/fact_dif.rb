require 'json'

class FactDif
  def initialize(old_output, new_output, exclude_list, save_structured)
    @c_facter = JSON.parse(old_output)
    @next_facter = JSON.parse(new_output)
    @exclude_list = exclude_list
    @save_structured = save_structured
    @flat_diff = []
    @diff = {}
  end

  def difs
    search_hash(((@c_facter.to_a - @next_facter.to_a) | (@next_facter.to_a - @c_facter.to_a)).to_h)

    @flat_diff.sort_by { |a| a[0] }.each do |pair|
      fact_path = pair[0]
      value = pair[1]
      compare(fact_path, value, @c_facter)
      compare(fact_path, value, @next_facter)
    end

    @diff
  end

  private

  def search_hash(sh, path = [])
    if sh.is_a?(Hash)
      sh.each do |k, v|
        search_hash(v, path.push(k))
        path.pop
      end
    elsif sh.is_a?(Array)
      sh.each_with_index do |v, index|
        search_hash(v, path.push(index))
        path.pop
      end
    else
      @flat_diff.push([path.dup, sh])
    end
  end

  def compare(fact_path, given_value, compared_hash)
    compared_value = compared_hash.dig(*fact_path)
    if different?(compared_value, given_value) && !excluded?(fact_path.join('.'))
      fact_path = fact_path.map{|f| f.to_s.include?('.') ? "\"#{f}\"" : f}.join('.') unless @save_structured
      if compared_hash == @c_facter
        bury(*fact_path, { :new_value => given_value, :old_value => compared_value }, @diff)
      else
        bury(*fact_path, { :new_value => compared_value, :old_value => given_value }, @diff)
      end
    end
  end

  def bury(*paths, value, hash)
    if paths.count > 1
      path = paths.shift
      hash[path] = Hash.new unless hash.key?(path)
      bury(*paths, value, hash[path])
    else
      hash[*paths] = value
    end
  end

  def different?(new, old)
    if old.is_a?(String) && new.is_a?(String) && (old.include?(',') || new.include?(','))
      old_values = old.split(',')
      new_values = new.split(',')

      diff = (old_values - new_values) | (new_values - old_values)
      return diff.size.positive?
    end

    old != new
  end

  def excluded?(fact_name)
    @exclude_list.any? {|excluded_fact| fact_name =~ /#{excluded_fact}/}
  end
end
