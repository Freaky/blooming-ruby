# Blooming Ruby

Yet another Ruby [bloom filter](https://en.wikipedia.org/wiki/Bloom_filter),
and a new bit array implementation, including a speedy JRuby-specific version.

This was extracted from an experiment in leaked password list processing,
before I moved on to Golomb Compressed Sets, and might be worth extracting
into a proper gem at some point.

## Synopsis

### BitArray

There's also a `bit_array_jruby` which uses `java.util.BitSet` under the hood.

```ruby
require 'blooming/bit_array'

# Array of 128 bits
ba = Blooming::BitArray.new(128)
ba.set!(1).set!(2).flip!(1).flip!(2).none? # true
ba.set!(1).set!(2).cardinality # => 2
ba.set?(1) # => true
ba.to_s # => raw bits
ba.each.to_a # => [false, true, true, false, false, ...]

ba2 = BitArray.new(ba.to_s) # a second BitArray identical to the first
ba2.clear! # and now it's empty
```

### BloomFilter

Split into two classes - a flexible calculator for parameters, and the
filter itself.

```ruby
require 'blooming/bloom_filter_params'
require 'blooming/bloom_filter' # Implied by above

# Size a filter for 1,000 items with a 0.0001 false-positive rate
bfp = Blooming::BloomFilterParams.new(n: 1000, p: 0.0001)
bf = bf.to_filter

bf.add "foo"
bf << "bar"
bf.include? "foo" # => true
bf.add? "foo" # => false
bf.add? "baz" # => true
bf.add? "baz" # => false
bf.estimate_count # => 3-ish
bf.count # => alias for above
bf.empty? # => false
bf.clear!
bf.empty? # => true
1000.times { |i| bf << i }
bf.saturated?  # => true (adding more items violates desired false-positive rate)
bf.full? # => true (alias)
```

