require "benchmark"
include Benchmark

require_relative "../lib/fast_open_struct"
require "ostruct"

puts "Dynamic attribute lookup:"

bm 14 do |b|
  b.report "OpenStruct" do
    os = OpenStruct.new
    os.a = 1
    os.b = 2
    os.c = 3
    1_000_000.times do
      os.a
      os.b
      os.c
    end
  end

  b.report "FastOpenStruct" do
    os = FastOpenStruct.new
    os.a = 1
    os.b = 2
    os.c = 3
    1_000_000.times do
      os.a
      os.b
      os.c
    end
  end
end
