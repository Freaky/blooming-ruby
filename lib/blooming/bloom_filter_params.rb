
require 'blooming/bloom_filter'

module Blooming
  class BloomFilterParams
    # * m = number of bits
    # * k = number of hash functions
    # * n = capacity of filter
    # * p = false-positive rate at capacity.
    def initialize(m: nil, n: nil, k: nil, p: nil)
      self.m = m if m
      self.n = n if n
      self.k = k if k
      self.p = p if p
    end

    def p=(false_positives)
      if false_positives.is_a? Numeric && false_positives > 1
        false_positives = 1 / false_positives.to_f
      end
      @p = false_positives
    end

    attr_accessor :n, :m, :k
    attr_reader :p
    alias capacity n
    alias capacity= n=
    alias bits m
    alias bits= m=
    alias hashes k
    alias hashes= k=
    alias false_positives p
    alias false_positives= p=

    def to_params
      m = self.m
      k = self.k
      n = self.n
      fp = self.p
      case [!!m, !!k, !!n, !!fp]
      when [true, true, true, false]  # (p) from (m, n, k) ("I have a filter with these params and this many items, what's it's fp rate?")
        r = m / Float(n)
        q = Math.exp(-k / r)
        fp = (1 - q) ** k
      when [false, false, true, true] # (m, k) from (n, p) ("I have n items and want p false-positives, what do I need?")
        m = (n * Math.log(fp) / Math.log(1.0 / (2.0 ** Math.log(2.0)))).ceil
        r = m / Float(n)
        k = (Math.log(2) * r).round
        q = Math.exp(-k / r)
        fp = (1 - q) ** k
      when [true, false, true, false] # (k, p) from (m, n) ("I have n items and m bits to spend, what do I get?")
        r = m / Float(n)
        k = (Math.log(2) * r).round
        q = Math.exp(-k / r)
        fp = (1 - q) ** k
      when [true, false, false, true] # (k, n) from (m, p) ("I have m bits to spend and want x false-positives, how much can I remember?")
        n = (m * Math.log(1.0 / 2.0 ** Math.log(2)) / Math.log(fp)).ceil
        r = m / Float(n)
        k = (Math.log(2) * r).round
        q = Math.exp(-k / r)
        fp = (1 - q) ** k
      else fail NotImplementedError, "parameter combination not supported"
      end

      {m: m, n: n, k: k, p: fp}
    end

    def to_filter
      prm = to_params
      BloomFilter.new(m: prm[:m] + (prm[:m] % 8), k: prm[:k])
    end
  end
end
