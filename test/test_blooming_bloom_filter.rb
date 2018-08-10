# frozen_string_literal: true

require 'minitest/autorun'
require 'blooming/bloom_filter'

class TestBloomFilter < MiniTest::Test
  include Blooming

  # Default: 100 items with fp rate of 1 in a million
  def nbf(m = 2880, k = 20)
    BloomFilter.new(m: m, k: k)
  end

  def test_empty
    bf = nbf
    assert !bf.saturated?
    assert bf.empty?
    assert_equal 0.0, bf.estimate_count

    assert bf.add?('boop')
    assert !bf.add?('boop')

    assert !bf.empty?
    assert_in_delta(1, bf.estimate_count, 0.01)

    bf.clear!
    assert bf.empty?
  end

  def test_saturated
    bf = nbf

    assert !bf.saturated?

    0.upto(49) { |i| bf << i.to_s }

    assert !bf.saturated?
    assert_in_delta(50, bf.estimate_count, 1)

    50.upto(99) { |i| bf << i.to_s }

    assert_in_delta(0.5, bf.saturation, 0.02)
    assert bf.saturated?
    assert_in_delta(100, bf.estimate_count, 4)
  end

  def test_accuracy
    bf = nbf

    0.upto(99) do |i|
      assert bf.add?(i.to_s)
    end

    fp = 0
    100.upto(275) do |i|
      fp += (bf.add?(i.to_s) ? 0 : 1)
    end
    assert_in_delta(3, fp, 2)
  end
end
