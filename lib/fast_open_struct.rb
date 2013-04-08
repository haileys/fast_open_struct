require "set"

class FastOpenStruct
  def initialize(table = {})
    table.each_pair do |k, v|
      instance_variable_set "@#{k}", v
    end
  end

  def [](name)
    instance_variable_get "@#{name}"
  end

  def []=(name, value)
    instance_variable_set "@#{name}", value
    value
  rescue RuntimeError
    raise TypeError, "can't modify frozen #{__apparent_class__}"
  end

  def delete_field(name)
    value = self[name]
    remove_instance_variable "@#{name}"
    value
  end

  def each_pair
    return to_enum(__method__) unless block_given?
    instance_variables.each do |ivar|
      yield ivar[1..-1].intern, instance_variable_get(ivar)
    end
    self
  end

  def ==(other)
    return false unless other.is_a? FastOpenStruct
    ivars = instance_variables
    return false if (ivars - other.instance_variables).any?
    ivars.all? { |ivar| instance_variable_get(ivar) == other.instance_variable_get(ivar) }
  end

  def eql?(other)
    return false unless other.is_a? FastOpenStruct
    ivars = instance_variables
    return false if (ivars - other.instance_variables).any?
    ivars.all? { |ivar| instance_variable_get(ivar).eql? other.instance_variable_get(ivar) }
  end

  def inspect
    str = "#<#{__apparent_class__}"
    ids = (Thread.current[:__fast_open_struct_inspect_key__] ||= Set.new)
    return str << " ...>" if ids.include? object_id
    ids << object_id
    begin
      first = true
      instance_variables.each do |ivar|
        str << "," unless first
        first = false
        str << " #{ivar[1..-1]}=#{instance_variable_get(ivar).inspect}"
      end
      str << ">"
    ensure
      ids.delete object_id
    end
  end

  def to_h
    Hash[each_pair.to_a]
  end

  def hash
    hash = 0x1337
    each_pair do |key, value|
      hash ^= key.hash ^ value.hash
    end
    hash
  end

  def method_missing(sym, *args)
    if sym[-1] == "=" and args.size == 1
      self[sym[0...-1]] = args[0]
    elsif args.size == 0 and instance_variable_defined?("@#{sym}")
      self[sym]
    else
      super
    end
  end

  def respond_to?(sym)
    if sym[-1] == "="
      respond_to?(sym[0...-1])
    elsif instance_variable_defined?("@#{sym}")
      true
    else
      super
    end
  end

private
  def __apparent_class__
    klass = self.class
    klass = klass.super until klass.name
    klass
  end
end
