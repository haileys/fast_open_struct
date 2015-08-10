# based off test/ostruct/test_ostruct.rb from MRI source

# Copyright (C) 1993-2013 Yukihiro Matsumoto. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

require "test/unit"
require "fast_open_struct"

module Testable_FastOpenStruct
  def test_initialize
    h = {name: "John Smith", age: 70, pension: 300}
    assert_equal h, fast_open_struct_class.new(h).to_h
    assert_equal h, fast_open_struct_class.new(fast_open_struct_class.new(h)).to_h
    assert_equal h, fast_open_struct_class.new(Struct.new(*h.keys).new(*h.values)).to_h
  end

  def test_equality
    o1 = fast_open_struct_class.new
    o2 = fast_open_struct_class.new
    assert_equal(o1, o2)

    o1.a = 'a'
    assert_not_equal(o1, o2)

    o2.a = 'a'
    assert_equal(o1, o2)

    o1.a = 'b'
    assert_not_equal(o1, o2)

    o2.a = 'b'
    assert_equal(o1, o2)

    o2.b = 'b'
    assert_not_equal(o1, o2)

    o1.b = 'b'
    assert_equal(o1, o2)

    o2 = Object.new
    o2.instance_eval{@table = {:a => 'b'}}
    assert_not_equal(o1, o2)
  end

  def test_inspect
    foo = fast_open_struct_class.new
    assert_equal("#<#{fast_open_struct_class}>", foo.inspect)
    foo.bar = 1
    foo.baz = 2
    assert_equal("#<#{fast_open_struct_class} bar=1, baz=2>", foo.inspect)

    foo = fast_open_struct_class.new
    foo.bar = fast_open_struct_class.new
    assert_equal("#<#{fast_open_struct_class} bar=#<#{fast_open_struct_class}>>", foo.inspect)
    foo.bar.foo = foo
    assert_equal("#<#{fast_open_struct_class} bar=#<#{fast_open_struct_class} foo=#<#{fast_open_struct_class} ...>>>", foo.inspect)
  end

  def test_frozen
    o = fast_open_struct_class.new
    o.a = 'a'
    o.freeze
    assert_raise(RuntimeError) {o.b = 'b'}
    assert_not_respond_to(o, :b)
    assert_raise(RuntimeError) {o.a = 'z'}
    assert_equal('a', o.a)
    o = fast_open_struct_class.new :a => 42
    def o.frozen?; nil end
    o.freeze
    assert_raise(RuntimeError) {o.a = 1764}
  end

  def test_delete_field
    bug = '[ruby-core:33010]'
    o = fast_open_struct_class.new
    assert_not_respond_to(o, :a)
    assert_not_respond_to(o, :a=)
    o.a = 'a'
    assert_respond_to(o, :a)
    assert_respond_to(o, :a=)
    a = o.delete_field :a
    assert_not_respond_to(o, :a, bug)
    assert_not_respond_to(o, :a=, bug)
    assert_equal(a, 'a')
  end

  def test_setter
    os = fast_open_struct_class.new
    os[:foo] = :bar
    assert_equal :bar, os.foo
    os['foo'] = :baz
    assert_equal :baz, os.foo
  end

  def test_getter
    os = fast_open_struct_class.new
    os.foo = :bar
    assert_equal :bar, os.foo
    assert_equal :bar, os[:foo]
    assert_equal :bar, os['foo']
    assert_equal nil, os.bar
    assert_equal nil, os[:bar]
    assert_equal nil, os['bar']
  end

  def test_to_h
    h = {name: "John Smith", age: 70, pension: 300}
    os = fast_open_struct_class.new(h)
    to_h = os.to_h
    assert_equal(h, to_h)

    to_h[:age] = 71
    assert_equal(70, os.age)
    assert_equal(70, h[:age])

    assert_equal(h, fast_open_struct_class.new("name" => "John Smith", "age" => 70, pension: 300).to_h)
  end

  def test_each_pair
    h = {name: "John Smith", age: 70, pension: 300}
    os = fast_open_struct_class.new(h)
    assert_equal %Q!#<Enumerator: #<#{fast_open_struct_class} name="John Smith", age=70, pension=300>:each_pair>!, os.each_pair.inspect
    assert_equal [[:name, "John Smith"], [:age, 70], [:pension, 300]], os.each_pair.to_a
  end

  def test_eql_and_hash
    os1 = fast_open_struct_class.new age: 70
    os2 = fast_open_struct_class.new age: 70.0
    assert_equal os1, os2
    assert_equal false, os1.eql?(os2)
    assert_not_equal os1.hash, os2.hash
    assert_equal true, os1.eql?(os1.dup)
    assert_equal os1.hash, os1.dup.hash
  end
  
  def test_serialize
    h = {name: "John Smith", age: 70, pension: 300}
    os1 = fast_open_struct_class.new h
    os2 = fast_open_struct_class.new h
    assert_equal os2, Marshal.load(Marshal.dump(os1))
  end
end

class TC_FastOpenStruct < Test::Unit::TestCase
  include Testable_FastOpenStruct

  private

  def fast_open_struct_class
    FastOpenStruct
  end
end

class TC_SubFastOpenStruct < Test::Unit::TestCase
  class SubFastOpenStruct < FastOpenStruct; end

  include Testable_FastOpenStruct

  private

  def fast_open_struct_class
    SubFastOpenStruct
  end
end
