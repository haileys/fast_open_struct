require "set"

class FastOpenStruct
  class << self
  private
    alias_method :__new, :new
    private :__new

    def __create_class(keys)
      cls = Class.new self do
        attr_accessor(*keys)
      end
      __be_serializable cls
    end

    def inherited(subclass)
      class << subclass
        alias_method :new, :__new
        public :new
      end
    end
    
    private
    
    def __be_serializable(klass)
      last = constants.map { |const|
        m = /\ACACHED_(\d+)\z/.match(const)
        m ? m[1].to_i : 0
      }.max
      
      const_set :"CACHED_#{last + 1}", klass
    end
  end

  @cache = {}
  @@ivar_for_names = {}
  @@ivar_for_setters = {}

  def self.new(table = {})
    keys = table.each_pair.map { |key, _| key.intern }.sort
    if cached = @cache[keys]
      cached.new table
    else
      (@cache[keys] = __create_class(keys)).new table
    end
  end

  def initialize(table = {})
    table.each_pair do |k, v|
      instance_variable_set __ivar_for_name__(k), v
    end
  end

  def [](name)
    ivar = __ivar_for_name__(name)
    instance_variable_defined?(ivar) ? instance_variable_get(ivar) : nil
  end

  def []=(name, value)
    instance_variable_set __ivar_for_name__(name), value
    value
  end

  def delete_field(name)
    value = self[name]
    remove_instance_variable __ivar_for_name__(name)
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
    other_ivars = other.instance_variables
    return false if (ivars - other_ivars).any? || (ivars.length != other_ivars.length)
    ivars.all? { |ivar| instance_variable_get(ivar) == other.instance_variable_get(ivar) }
  end

  def eql?(other)
    return false unless other.is_a? FastOpenStruct
    ivars = instance_variables
    other_ivars = other.instance_variables
    return false if (ivars - other_ivars).any? || (ivars.length != other_ivars.length)
    ivars.all? { |ivar| instance_variable_get(ivar).eql? other.instance_variable_get(ivar) }
  end

  def inspect
    str = "#<#{__apparent_class__}"
    str.slice!(/::CACHED_\d+\z/)
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

  EQ = "=".freeze

  def method_missing(sym, *args)
    if args.size == 0
      ivar = __ivar_for_name__(sym)
      instance_variable_defined?(ivar) ? instance_variable_get(ivar) : nil
    elsif args.size == 1 and sym[-1] == EQ
      instance_variable_set __ivar_for_setter__(sym), args[0]
    else
      super
    end
  end

  def respond_to?(sym)
    if sym[-1] == EQ
      respond_to?(sym[0...-1])
    elsif instance_variable_defined?(__ivar_for_name__(sym))
      true
    else
      super
    end
  end

private
  def __ivar_for_name__(name)
    @@ivar_for_names[name] ||= :"@#{name}"
  end

  def __ivar_for_setter__(name)
    @@ivar_for_setters[name] ||= :"@#{name[0...-1]}"
  end

  def __apparent_class__
    klass = self.class
    klass = klass.superclass until klass.name
    klass
  end
end
