# frozen_string_literal: true

require 'blooming/bit_array'
require 'digest/sha2'

module Blooming
  # Yet another bloom filter implementation.
  class BloomFilter
    HashFunction = Digest::SHA512
    HASH_BITS = 512

    attr_reader :m, :k

    def inspect
      format('#<%<klass>s:0x%<id>x m=%<m>d k=%<k>d filter=%<filter>s>',
             klass: self.class, id: object_id, k: k, m: m,
             filter: filter.inspect)
    end

    # Create a Bloom Filter with given parameters:
    #
    # * m = number of bits, rounded to the nearest byte
    # * k = number of hash functions
    #
    # +BloomFilterParams+ can be used to calculate from capacity, available
    # space, desired false-positive rate, etc.
    def initialize(m:, k:)
      m = Integer(m)
      k = Integer(k)

      if m < 2 ** 16
        @hashes_needed = ((k * 16) / HASH_BITS) + 1
        @unpack = "n#{k}"
      elsif m < 2 ** 32
        @hashes_needed = ((k * 32) / HASH_BITS) + 1
        @unpack = "N#{k}"
      else
        raise ArgumentError, "Huge filters are silly. Use multiple smaller ones."
      end

      raise ArgumentError, 'm must be multiple of 8' if (m % 8).nonzero?

      @m = m
      @k = k
    end

    # Determine if +key+ has (with a given probability) been seen by the filter.
    # This may return false-positives, but not false-negatives.  i.e. a +true+
    # might be a lie, a +false+ won't be.
    def include?(key)
      key_to_hashes(key).all? do |hash|
        filter.set?(hash)
      end
    end

    # Add the given +key+ to the filter.  Aliased to +add+, returns +self+ so it
    # can be chained.
    def <<(key)
      key_to_hashes(key).each { |hash| filter.set!(hash) }
      self
    end

    alias add <<

    # Add the given +key+ to the filter, returning +true+ if the item did not
    # exist.  This should be faster than combining +include?+ and +<<+ because
    # it avoids duplicating work.
    def add?(key)
      hashes = key_to_hashes(key).reject { |hash| filter.set?(hash) }
      hashes.each { |hash| filter.set!(hash) }
      hashes.any?
    end

    # Check if the filter is at its saturation point.  Adding further items will
    # increase the rate of false-positives.
    #
    # Because it requires counting the number of set bits in the filter this
    # method is quite slow.
    def saturated?
      saturation > 0.5
    end

    alias full? saturated?

    # Calculate the number of set bits as a Float value between 0 and 1.
    #
    # A bloom filter at 50% saturation (0.5) is considered full.
    #
    # Because it requires counting the number of set bits in the filter this
    # method is quite slow.
    def saturation
      filter.cardinality / filter.size.to_f
    end

    # Estimate the number of items in the filter, as a floating point value.
    #
    # Because it requires counting the number of set bits in the filter this
    # method is quite slow.
    def estimate_count
      -(m / k.to_f) * Math.log(1 - (filter.cardinality / m.to_f))
    end

    alias count estimate_count

    # Determine if the filter is empty.  Scales with the size of the filter.
    def empty?
      filter.empty?
    end

    # Empty the filter.
    def clear!
      filter.clear
    end

    # Return a binary representation of the filter.
    #
    # Note this does *not* save filter parameters.
    def to_s
      filter.to_s
    end

    # Load a filter from the provided string.
    def from_s(filter)
      unless filter.bytesize == m / 8
        raise ArgumentError,
              "expected a #{m / 8} byte filter, provided #{filter.bytesize}"
      end

      self.filter = BitArray.new(filter)
    end

    private

    def key_to_hashes(key)
      last_key = key.to_s
      hashed = Array.new(@hashes_needed) do
        last_key = HashFunction.digest(last_key)
      end.join

      hashed.unpack(@unpack).map { |x| x % m }
    end

    # The internal +Blooming::BitArray+ representing the filter.
    def filter
      @filter ||= BitArray.new(m)
    end

    # Set the internal +Blooming::BitArray+ representing the filter.
    def filter=(f)
      raise ArgumentError, 'filter size mismatch' unless f.size == m
      @filter = f
    end
  end
end
