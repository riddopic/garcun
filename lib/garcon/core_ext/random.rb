# encoding: UTF-8
#
# Author:    Stefano Harding <riddopic@gmail.com>
# License:   Apache License, Version 2.0
# Copyright: (C) 2014-2015 Stefano Harding
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'securerandom'
require_relative 'hash'
require_relative 'string'
require_relative 'kernel'

# This library extends Array, String, Hash and other classes with randomization
# methods. Most of the methods are of one of two kinds. Either they "pick" a
# random element from the reciever or they randomly "shuffle" the reciever.
#
# The most common example is Array#shuffle, which simply randmomizes the
# order of an array's elements.
#
#   [1,2,3].shuffle  # => [2,3,1]
#
# The other methods do similar things for their respective classes.
#
# The classes are all extended via mixins which have been created within
# Ruby's Random class.
#
class Random
  class << self
    # Alias for Kernel#rand.
    alias_method :number, :rand

    public :number
  end

  # Module method to generate a random letter.
  #
  # @example
  #   Random.letter  # => "q"
  #   Random.letter  # => "r"
  #   Random.letter  # => "a"
  #
  # @return [String]
  #   A random letter
  #
  # @api public
  def self.letter
    (SecureRandom.random_number(26) +
    (SecureRandom.random_number(2) == 0 ? 65 : 97)).chr
  end

  # Random extensions for Range class.
  #
  module RangeExtensions
    # Return a random element from the range.
    #
    # @example
    #   (1..4).at_rand           # => 2
    #   (1..4).at_rand           # => 4
    #
    #   (1.5..2.5).at_rand       # => 2.06309842754533
    #   (1.5..2.5).at_rand       # => 1.74976944931541
    #
    #   ('a'..'z').at_rand       # => 'q'
    #   ('a'..'z').at_rand       # => 'f'
    #
    # @return [String]
    #   A random element from range
    #
    # @api public
    def at_rand
      first, last = first(), last()
      if first.respond_to?(:random_delta)
        begin
          first.random_delta(last, exclude_end?)
        rescue
          to_a.at_rand
        end
      else
        to_a.at_rand
      end
    end
  end

  # Random extensions fo Integer class.
  #
  module IntegerExtensions
    #
    def random_delta(last, exclude_end)
      first = self
      last -= 1 if exclude_end
      return nil if last < first
      SecureRandom.random_number(last - first + 1) + first
    end
  end

  # Random extensions for Numeric class.
  #
  module NumericExtensions
    #
    def random_delta(last, exclude_end)
      first = self
      return nil if last < first
      return nil if exclude_end && last == first
      (last - first) * SecureRandom.random_number + first
    end
  end

  # Random extensions for Array class.
  #
  module ArrayExtensions
    # Return a random element from the array.
    #
    # @example
    #   [1, 2, 3, 4].at_rand           # => 2
    #   [1, 2, 3, 4].at_rand           # => 4
    #
    def at_rand
      at(SecureRandom.random_number(size))
    end

    # Same as #at_rand, but acts in place removing a random element from the
    # array.
    #
    # @example
    #   a = [1,2,3,4]
    #   a.at_rand!       # => 2
    #   a                # => [1,3,4]
    #
    def at_rand!
      delete_at(SecureRandom.random_number(size))
    end

    # Similar to #at_rand, but will return an array of randomly picked exclusive
    # elements if given a number.
    def pick(n = nil)
      if n
        a = self.dup
        a.pick!(n)
      else
        at(SecureRandom.random_number(size))
      end
    end

    # Similar to #at_rand!, but given a number will return an array of exclusive
    # elements.
    def pick!(n = nil)
      if n
        if n > self.size
          r = self.dup
          self.replace([])
          r
        else
          r = []
          n.times { r << delete_at(SecureRandom.random_number(size)) }
          r
        end
      else
        delete_at(SecureRandom.random_number(size))
      end
    end

    # Random index.
    #
    def rand_index
      SecureRandom.random_number(size)
    end

    # Returns a random subset of an Array. If a _number_ of elements is
    # specified then returns that number of elements, otherwise returns a random
    # number of elements upto the size of the Array.
    #
    # By defualt the returned values are exclusive of each other, but if
    # _exclusive_ is set to `false`, the same values can be choosen more than
    # once.
    #
    # When _exclusive_ is <tt>true</tt> (the default) and the _number_ given is
    # greater than the size of the array, then all values are returned.
    #
    # @example
    #   [1, 2, 3, 4].rand_subset(1)        # => [2]
    #   [1, 2, 3, 4].rand_subset(4)        # => [2, 1, 3, 4]
    #   [1, 2, 3, 4].rand_subset           # => [1, 3, 4]
    #   [1, 2, 3, 4].rand_subset           # => [2, 3]
    #
    def rand_subset(number = nil, exclusive = true)
      number = SecureRandom.random_number(size) unless number
      number = number.to_int
      return sort_by{rand}.slice(0,number) if exclusive
      ri =[]; number.times { |n| ri << SecureRandom.random_number(size) }
      return values_at(*ri)
    end

    # Generates random subarrays. Uses random numbers and bit-fiddling to assure
    # performant uniform distributions even for large arrays.
    #
    # @example
    #   a = *1..5
    #   a.rand_subarrays(2) # => [[3, 4, 5], []]
    #   a.rand_subarrays(3) # => [[1], [1, 4, 5], [2, 3]]
    #
    def rand_subarrays(n = 1)
      raise ArgumentError, 'negative argument' if n < 0
      (1..n).map do
        r = rand(2**self.size)
        self.select.with_index { |_, i| r[i] == 1 }
      end
    end

    # Randomize the order of an array.
    #
    # @example
    #   [1,2,3,4].shuffle  # => [2,4,1,3]
    #
    def shuffle
      dup.shuffle!
    end

    # As with #shuffle but modifies the array in place.
    # The algorithm used here is known as a Fisher-Yates shuffle.
    #
    # @example
    #   a = [1,2,3,4]
    #   a.shuffle!
    #   a  # => [2,4,1,3]
    #
    def shuffle!
      s = size
      each_index do |j|
        i = SecureRandom.random_number(s-j)
        tmp = self[j]
        self[j] = self[j+i]
        self[j+i] = tmp
      end
      self
    end
  end

  # Random extensions for Hash class.
  #
  module HashExtensions
    # Returns a random key.
    #
    # @example
    #   {:one => 1, :two => 2, :three => 3}.pick_key  # => :three
    #
    def rand_key
      keys.at(SecureRandom.random_number(keys.size))
    end

    # Delete a random key-value pair, returning the key.
    #
    # @example
    #   a = {:one => 1, :two => 2, :three => 3}
    #   a.rand_key!  # => :two
    #   a            # => {:one => 1, :three => 3}
    #
    def rand_key!
      k,v = rand_pair
      delete(k)
      return k
    end

    alias_method :pick_key, :rand_key!

    # Returns a random key-value pair.
    #
    # @example
    #   {:one => 1, :two => 2, :three => 3}.pick  # => [:one, 1]
    #
    def rand_pair
      k = rand_key
      return k, fetch(k)
    end

    # Deletes a random key-value pair and returns that pair.
    #
    # @example
    #   a = {:one => 1, :two => 2, :three => 3}
    #   a.rand_pair!  # => [:two, 2]
    #   a             # => {:one => 1, :three => 3}
    #
    def rand_pair!
      k,v = rand_pair
      delete(k)
      return k,v
    end

    alias_method :pick_pair, :rand_pair!

    # Returns a random hash value.
    #
    # @example
    #   {:one => 1, :two => 2, :three => 3}.rand_value  # => 2
    #   {:one => 1, :two => 2, :three => 3}.rand_value  # => 1
    #
    def rand_value
      fetch(rand_key)
    end

    # Deletes a random key-value pair and returns the value.
    #
    # @example
    #   a = {:one => 1, :two => 2, :three => 3}
    #   a.at_rand!  # => 2
    #   a           # => {:one => 1, :three => 3}
    #
    def rand_value!
      k,v = rand_pair
      delete(k)
      return v
    end

    alias_method :pick,     :rand_value!
    alias_method :at_rand,  :rand_value
    alias_method :at_rand!, :rand_value!

    # Returns a copy of the hash with _values_ arranged in new random order.
    #
    # @example
    #   h = {:a=>1, :b=>2, :c=>3}
    #   h.shuffle  # => {:b=>2, :c=>1, :a>3}
    #
    def shuffle
      ::Hash.zip(
        keys.sort_by   { SecureRandom.random_number },
        values.sort_by { SecureRandom.random_number })
    end

    # Destructive shuffle_hash. Arrange the values in a new random order.
    #
    # @example
    #   h = {:a => 1, :b => 2, :c => 3}
    #   h.shuffle!
    #   h  # => {:b=>2, :c=>1, :a=>3}
    #
    def shuffle!
      self.replace(shuffle)
    end

  end

  # Random extensions for String class.
  #
  module StringExtensions

    def self.included(base)
      base.extend(Self)
    end

    # Class-level methods.
    module Self
      # Returns a randomly generated string. One possible use is
      # password initialization. Takes a max legnth of characters
      # (default 8) and an optional valid char Regexp (default /\w\d/).
      #
      # @example
      #   String.random    # => 'dd4qed4r'
      #
      def random(max_length = 8, char_re = /[\w\d]/)
        unless char_re.is_a?(Regexp)
          raise ArgumentError, 'second argument must be a regular expression'
        end
        string = ''
        while string.length < max_length
            ch = SecureRandom.random_number(255).chr
            string << ch if ch =~ char_re
        end
        return string
      end

      # Generate a random binary string of +n_bytes+ size.
      #
      def random_binary(n_bytes)
        #(Array.new(n_bytes) { rand(0x100) }).pack('c*')
        SecureRandom.random_bytes(64)
      end

      # Create a random String of given length, using given character set
      #
      # Examples
      #
      #     String.random
      #     => "D9DxFIaqR3dr8Ct1AfmFxHxqGsmA4Oz3"
      #
      #     String.ran(10)
      #     => "t8BIna341S"
      #
      #     String.ran(10, ['a'..'z'])
      #     => "nstpvixfri"
      #
      #     String.ran(10, ['0'..'9'] )
      #     => "0982541042"
      #
      #     String.ran(10, ['0'..'9','A'..'F'] )
      #     => "3EBF48AD3D"
      #
      def ran(len = 32, character_set = ["A".."Z", "a".."z", "0".."9"])
        chars = character_set.map(&:to_a).flatten
        Array.new(len){ chars.sample }.join
      end
    end

    # Return a random separation of the string. Default separation is by
    # charaacter.
    #
    # @example
    #   "Ruby rules".at_rand(' ')  # => ["Ruby"]
    #
    def at_rand(separator = //)
      self.split(separator, -1).at_rand
    end

    # Return a random separation while removing it from the string. Default
    # separation is by character.
    #
    # @example
    #   s = "Ruby rules"
    #   s.at_rand!(' ')    # => "Ruby"
    #   s                  # => "rules"
    #
    def at_rand!(separator = //)
      a = self.shatter(separator)
      w = []; a.each_with_index { |s, i| i % 2 == 0 ? w << s : w.last << s }
      i = SecureRandom.random_number(w.size)
      r = w.delete_at(i)
      self.replace(w.join(''))
      return r
    end

    # Return a random byte of _self_.
    #
    # @example
    #   "Ruby rules".rand_byte  # => 121
    #
    def rand_byte
      self[SecureRandom.random_number(size)]
    end

    # Destructive rand_byte. Delete a random byte of _self_ and return it.
    #
    # @example
    #   s = "Ruby rules"
    #   s.rand_byte!      # => 121
    #   s                 # => "Rub rules"
    #
    def rand_byte!
      i = SecureRandom.random_number(size)
      rv = self[i,1]
      self[i,1] = ''
      rv
    end

    # Return a random string index.
    #
    # @example
    #   "Ruby rules".rand_index  # => 3
    #
    def rand_index
      SecureRandom.random_number(size)
    end

    # Return the string with seperated sections arranged in a random order. The
    # default seperation is by character.
    #
    # @example
    #   "Ruby rules".shuffle  # => "e lybRsuur"
    #
    def shuffle(separator = //)
      split(separator).shuffle.join('')
    end

    # In place version of shuffle.
    #
    def shuffle!(separator = //)
      self.replace(shuffle(separator))
    end
  end
end

Hash.send(:include,    Random::HashExtensions)
Array.send(:include,   Random::ArrayExtensions)
Range.send(:include,   Random::RangeExtensions)
String.send(:include,  Random::StringExtensions)
Integer.send(:include, Random::IntegerExtensions)
Numeric.send(:include, Random::NumericExtensions)
