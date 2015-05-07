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

module Garcon

  # A queue collection in which the elements are sorted based on their
  # comparison (spaceship) operator `<=>`. Items are added to the queue at a
  # position relative to their priority. On removal the element with the
  # "highest" priority is removed. By default the sort order is from highest to
  # lowest, but a lowest-to-highest sort order can be set on construction.
  #
  # The API is based on the `Queue` class from the Ruby standard library.
  #
  class MutexPriorityQueue

    # Create a new priority queue with no items.
    #
    # @param [Hash] opts
    #   The options for creating the queue.
    #
    # @option opts [Symbol] :order (:max)
    #   dictates the order in which items are stored: from highest to lowest
    #   when `:max` or `:high`; from lowest to highest when `:min` or `:low`
    #
    def initialize(opts = {})
      order = opts.fetch(:order, :max)
      @comparator = [:min, :low].include?(order) ? -1 : 1
      clear
    end

    # Removes all of the elements from this priority queue.
    #
    def clear
      @queue = [nil]
      @length = 0
      true
    end

    # Deletes all items from `self` that are equal to `item`.
    #
    # @param [Object] item
    #   The item to be removed from the queue.
    #
    # @return [Object]
    #   True if the item is found else false.
    #
    def delete(item)
      original_length = @length
      k = 1
      while k <= @length
        if @queue[k] == item
          swap(k, @length)
          @length -= 1
          sink(k)
          @queue.pop
        else
          k += 1
        end
      end
      @length != original_length
    end

    # Returns `true` if `self` contains no elements.
    #
    # @return [Boolean]
    #   True if there are no items in the queue else false.
    #
    def empty?
      size == 0
    end

    # Returns `true` if the given item is present in `self` (that is, if any
    # element == `item`), otherwise returns false.
    #
    # @param [Object] item
    #   The item to search for
    #
    # @return [Boolean]
    #   True if the item is found else false.
    #
    def include?(item)
      @queue.include?(item)
    end
    alias_method :has_priority?, :include?

    # The current length of the queue.
    #
    # @return [Fixnum]
    #   The number of items in the queue.
    #
    def length
      @length
    end
    alias_method :size, :length

    # Retrieves, but does not remove, the head of this queue, or returns `nil`
    # if this queue is empty.
    #
    # @return [Object]
    #   The head of the queue or `nil` when empty.
    #
    def peek
      @queue[1]
    end

    # Retrieves and removes the head of this queue, or returns `nil` if this
    # queue is empty.
    #
    # @return [Object]
    #   The head of the queue or `nil` when empty.
    #
    def pop
      max = @queue[1]
      swap(1, @length)
      @length -= 1
      sink(1)
      @queue.pop
      max
    end
    alias_method :deq, :pop
    alias_method :shift, :pop

    # Inserts the specified element into this priority queue.
    #
    # @param [Object]
    #   Item the item to insert onto the queue.
    #
    def push(item)
      @length += 1
      @queue << item
      swim(@length)
      true
    end
    alias_method :<<, :push
    alias_method :enq, :push

    # Create a new priority queue from the given list.
    #
    # @param [Enumerable] list
    #   The list to build the queue from.
    #
    # @param [Hash] opts
    #   The options for creating the queue.
    #
    # @return [PriorityQueue]
    #   The newly created and populated queue.
    #
    def self.from_list(list, opts = {})
      queue = new(opts)
      list.each { |item| queue << item }
      queue
    end

    protected #      A T T E N Z I O N E   A R E A   P R O T E T T A

    # Exchange the values at the given indexes within the internal array.
    #
    # @param [Integer] x
    #   The first index to swap.
    #
    # @param [Integer] y
    #   The second index to swap.
    #
    # @!visibility private
    def swap(x, y)
      temp = @queue[x]
      @queue[x] = @queue[y]
      @queue[y] = temp
    end

    # Are the items at the given indexes ordered based on the priority
    # order specified at construction?
    #
    # @param [Integer] x
    #   The first index from which to retrieve a comparable value.
    #
    # @param [Integer] y
    #   The second index from which to retrieve a comparable value.
    #
    # @return [Boolean]
    #   True if the two elements are in the correct priority order else false.
    #
    # @!visibility private
    def ordered?(x, y)
      (@queue[x] <=> @queue[y]) == @comparator
    end

    # Percolate down to maintain heap invariant.
    #
    # @param [Integer] k
    #   The index at which to start the percolation.
    #
    # @!visibility private
    def sink(k)
      while (j = (2 * k)) <= @length do
        j += 1 if j < @length && ! ordered?(j, j+1)
        break if ordered?(k, j)
        swap(k, j)
        k = j
      end
    end

    # Percolate up to maintain heap invariant.
    #
    # @param [Integer] k
    #   The index at which to start the percolation.
    #
    # @!visibility private
    def swim(k)
      while k > 1 && ! ordered?(k/2, k) do
        swap(k, k/2)
        k = k/2
      end
    end
  end

  class PriorityQueue < MutexPriorityQueue; end
end
