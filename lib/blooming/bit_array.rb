# frozen_string_literal: true

module Blooming
  # A array of bits implemented around String.
  #
  # This is thread safe only for reading.  Modifications should be protected
  # by a lock.
  class BitArray
    include Enumerable

    POPCNT_TABLE = Array.new(256) do |byte|
      c = 0
      until byte.zero?
        c += byte & 1
        byte >>= 1
      end
      c
    end.freeze

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
      byte = pos / 8
      raw.setbyte(byte, rawbyte(byte) | (1 << (pos % 8)))
      self
    end

    # Unset a bit at the given position.
    def unset!(pos)
      byte = pos / 8
      raw.setbyte(byte, rawbyte(byte) & (0xff ^ (1 << (pos % 8))))
      self
    end

    # Flip the bit at the given position.
    def flip!(pos)
      byte = pos / 8
      raw.setbyte(byte, rawbyte(byte) ^ (1 << (pos % 8)))
      self
    end

    # Return a boolean as to whether the given position is set or unset.
    def set?(pos)
      (rawbyte(pos / 8) & (1 << (pos % 8))).positive?
    end

    alias [] set?

    # Set the given bit based on the truthiness of the value.
    def []=(pos, val)
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
      @raw = ("\xff" * ((size / 8))).force_encoding('BINARY')
      self
    end

    # Iterate over every bit.
    def each
      return enum_for(:each) unless block_given?

      # This is nearly twice as fast as iterating over +set?+
      raw.each_byte do |byte|
        8.times do |i|
          yield((byte & (1 << i)).positive?)
        end
      end
      self
    end

    # The raw internal String backing the bit array.
    def raw
      @raw ||= ("\x00" * ((size / 8))).force_encoding('BINARY')
    end

    alias to_s raw

    # Replace the internal String with the provided value.
    def raw=(new_bits)
      raise TypeError, 'not a String' unless new_bits.is_a? String

      @size = new_bits.bytesize * 8
      @raw  = new_bits.force_encoding('BINARY')
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
      # About 10x faster than counting bytes directly
      raw.each_byte.inject(0) do |c, byte|
        c + POPCNT_TABLE[byte]
      end
    end

    private

    def rawbyte(i)
      ## With this line:    24797/sec
      ## Without this line: 26101/sec
      # raise(IndexError, 'negative indexes not supported') if i.negative?
      raw.getbyte(i) || raise(IndexError, 'index out of bounds')
    end

    def resize_raw(new_size)
      if new_size > @size
        raw[@size / 8] = "\x00" * ((new_size - size) / 8)
        # @raw = @raw.ljust(new_size / 8, "\x00")
      else
        raw[new_size / 8, size / 8] = ''
      end
    end
  end
end
