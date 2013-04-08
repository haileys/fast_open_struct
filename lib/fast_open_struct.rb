require 'fast_open_struct.so'

class FastOpenStruct
  def delete_field(name)
    raise "Not implemented"
  end

  def ==(other)
    return false unless other.is_a? FastOpenStruct
    self.to_h == other.to_h
  end

  def eql?(other)
    return false unless other.is_a? FastOpenStruct
    self.to_h.eql? other.to_h
  end

  def inspect
    return "#<#{self.class.name}>" if size == 0
    "#<#{self.class.name} " + each_pair.map{|k, v| "#{k}=#{v.inspect}" }.join(', ') + '>'
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
end
