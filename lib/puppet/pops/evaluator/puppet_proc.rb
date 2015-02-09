class Puppet::Pops::Evaluator::PuppetProc < Proc
  def self.new(closure, &block)
    proc = super(&block)
    proc.instance_variable_set(:@closure, closure)
    proc
  end

  attr_reader :closure

  def lambda?
    false
  end

  def parameters
    @closure.parameters.map do |param|
      sym = param.name.to_sym
      if param.captures_rest
        [ :rest, sym ]
      elsif param.value
        [ :opt, sym ]
      else
        [ :req, sym ]
      end
    end
  end

  def arity
    parameters.reduce(0) do |memo, param|
      count = memo + 1
      break -count unless param[0] == :req
      count
    end
  end
end