# frozen_string_literal: true

require 'java'

module Blooming
  # A array of bits implemented around java.util.BitSet
  #
  # This is thread safe only for reading.  Modifications should be protected
  # by a lock.
  class BitArray
    include Enumerable

    JavaBitSet = java.util.BitSet

    # The number of bits in the array.
    attr_reader :size

    # Create a TinyBitArray of either Integer bits (which must be a multiple of
    # 8), or directly from a String.
    def initialize(init)
      @raw = nil
      case init
      when String  then self.raw  = init
      when Integer then self.size = init
      else raise TypeError, 'initialize with String or Integer'
      end
    end

    # Set a bit at the given position.
    def set!(pos)
      # raise IndexError if pos >= size
      raw.set(pos)
      self
    end

    # Unset a bit at the given position.
    def unset!(pos)
      # raise IndexError if pos >= size
      raw.clear(pos)
      self
    end

    # Flip the bit at the given position.
    def flip!(pos)
      # raise IndexError if pos >= size
      raw.flip(pos)
      self
    end

    # Return a boolean as to whether the given position is set or unset.
    def set?(pos)
      # raise IndexError if pos >= size
      raw.get(pos)
    end

    alias [] set?

    # Set the given bit based on the truthiness of the value.
    def []=(pos, val)
      # raise IndexError if pos >= size
      if val
        set!(pos)
      else
        unset!(pos)
      end
    end

    def clear
      @raw = nil
      self
    end

    def flood
      raw.set(0, size)
      self
    end

    # Iterate over every bit.
    def each
      return enum_for(:each) unless block_given?

      size.times { |i| yield raw.get(i) }
      self
    end

    # The raw internal String backing the bit array.
    def raw
      @raw ||= JavaBitSet.new(size)
    end

    def to_s
      @raw.toByteArray.to_s
    end

    # Replace the internal String with the provided value.
    def raw=(new_bits)
      raise TypeError, 'not a String' unless new_bits.is_a? String

      @size = new_bits.bytesize * 8
      @raw  = JavaBitSet.valueOf(new_bits.to_java_bytes)
    end

    alias from_s raw=

    # Resize the bit array, zero-padding or truncating existing values.
    def size=(new_size)
      unless (new_size % 8).zero? && new_size.positive?
        raise ArgumentError, 'size must be >0, and multiple of 8'
      end

      resize_raw(new_size) if @raw

      @size = new_size
    end

    def inspect
      total = cardinality
      format('#<%<klass>s:0x%<id>x %<used>d/%<size>d bits (%<pct>.2f%% set)>',
             klass: self.class, id: object_id, used: total, size: size,
             pct: (total / size.to_f) * 100)
    end

    # Count the total number of set bits in the array.
    def cardinality
      raw.cardinality
    end

    # Determine if all bits are zero.
    def empty?
      raw.isEmpty
    end

    private

    def resize_raw(new_size)
      if new_size > @size
      else
        raw.clear(new_size, size)
      end
    end
  end
end
