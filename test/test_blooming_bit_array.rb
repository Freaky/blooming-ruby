# frozen_string_literal: true

require 'minitest/autorun'
require 'blooming/bit_array'

class TestBitArray < MiniTest::Test
  include Blooming
  def ba(arg)
    BitArray.new(arg)
  end

  def test_empty
    assert ba(128).none?
  end

  def test_full
    b = ba(128)
    128.times { |i| b.set!(i) }
    assert b.all?
  end

  def test_set
    assert ba(128).set!(42).one?
  end

  def test_unset
    assert ba(128).set!(42).unset!(42).none?
  end

  def test_flip
    assert ba(128).flip!(42).one?
    assert ba(128).flip!(42).flip!(42).none?
  end

  def test_cardinality
    assert_equal 3, ba(128).set!(1).set!(2).set!(42).cardinality
  end

  def test_each
    b = ba(128)

    enum = b.each
    assert !enum.next

    b.each { |x| assert !x }
  end

  def test_flood
    assert ba(128).flood.all?
  end

  def test_clear
    assert ba(128).flood.clear.none?
  end

  def test_size_expand
    b = ba(128).set!(42).set!(127)
    b.size = 256
    assert_equal 256, b.size
    assert_equal 2, b.cardinality
    assert !b.set?(41)
    assert b.set?(42)
    assert !b.set?(43)
    assert b.set?(127)
    assert b.set!(255).set?(255)
    assert_equal 3, b.cardinality
    assert_raises(IndexError) { b[256] }
  end

  def test_size_truncate
    b = ba(128).set!(42).set!(127)
    b.size = 64
    assert_equal 64, b.size
    assert_equal 1, b.cardinality
    assert !b.set?(41)
    assert b.set?(42)
    assert !b.set?(43)
    assert b.set!(63).set?(63)
    assert_raises(IndexError) { b[64] }
  end

  def test_unaligned_error
    assert_raises(ArgumentError) { ba(127) }
  end

  def test_out_of_bounds
    b = ba(128)
    i = 256
    assert_raises(IndexError) { b[i] }
    assert_raises(IndexError) { b[i] = true }
    assert_raises(IndexError) { b.set!(i) }
    assert_raises(IndexError) { b.flip!(i) }
    assert_raises(IndexError) { b.unset!(i) }
    assert_raises(IndexError) { b.set?(i) }
  end

  def test_random
    16.times do
      size = rand(8..(1024 * 16))
      size -= size % 8

      a = Array.new(size, false)
      b = ba(size)

      (4 * size).times do
        pos = rand(size)
        case rand(5)
        when 0
          a[pos] = false
          b[pos] = false
        when 1
          a[pos] = true
          b[pos] = true
        when 3
          a[pos] = !a[pos]
          b.flip!(pos)
        when 4
          assert_equal a[pos], b[pos]
        end
      end

      assert_equal a, b.to_a
      assert_equal [a.map { |x| x ? '1' : '0' }.join].pack('b*'), b.to_s
    end
  end

  def test_serialization
    a = Array.new(1024) { rand > 0.5 }
    raw = [a.map { |x| x ? '1' : '0' }.join].pack('b*')
    b = ba(raw)
    assert_equal a, b.to_a
    assert_equal raw, b.to_s
  end

  def test_inspect
    b = ba(64).set!(1)
    pattern = %r{\A#<#{b.class.name}:0x#{b.object_id.to_s(16)} 1/64 bits \(1\.56% set\)>\Z}
    assert_match(pattern, b.inspect)
  end
end
