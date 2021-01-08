require 'json'

class FactDif
  def initialize(old_output, new_output, exclude_list = [])
    @c_facter = JSON.parse(old_output)['values']
    @next_facter = JSON.parse(new_output)['values']
    @exclude_list = exclude_list
    @diff = {}
  end

  def difs
    search_hash(@c_facter, [])

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
      compare(path, sh)
    end
  end

  def compare(fact_path, old_value)
    new_value = @next_facter.dig(*fact_path)
    if different?(new_value, old_value) && !excluded?(fact_path.join('.'))
      @diff[fact_path.join('.')] = { new_value: new_value.inspect, old_value: old_value.inspect }
    end
  end

  def different?(new, old)
    if old.is_a?(String) && new.is_a?(String)
      diff = old.split(',') - new.split(',')

      return true if diff.any?

      return false
    end

    old != new
  end

  def excluded?(fact_name)
    @exclude_list.any? {|excluded_fact| fact_name =~ /#{excluded_fact}/}
  end
end
