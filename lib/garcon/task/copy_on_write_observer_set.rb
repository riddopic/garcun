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

  # A thread safe observer set implemented using copy-on-write approach:
  # every time an observer is added or removed the whole internal data structure
  # is duplicated and replaced with a new one.
  #
  class CopyOnWriteObserverSet

    def initialize
      @mutex = Mutex.new
      @observers = {}
    end

    # Adds an observer to this set. If a block is passed, the observer will be
    # created by this method and no other params should be passed
    #
    # @param [Object] observer
    #   the observer to add
    #
    # @param [Symbol] func
    #   the function to call on the observer during notification. The default
    #   is :update.
    #
    # @return [Object]
    #   the added observer
    def add_observer(observer=nil, func=:update, &block)
      if observer.nil? && block.nil?
        raise ArgumentError, 'should pass observer as a first argument or block'
      elsif observer && block
        raise ArgumentError.new('cannot provide both an observer and a block')
      end

      if block
        observer = block
        func = :call
      end

      begin
        @mutex.lock
        new_observers = @observers.dup
        new_observers[observer] = func
        @observers = new_observers
        observer
      ensure
        @mutex.unlock
      end
    end

    # @param [Object] observer
    #   the observer to remove
    # @return [Object]
    #   the deleted observer
    def delete_observer(observer)
      @mutex.lock
      new_observers = @observers.dup
      new_observers.delete(observer)
      @observers = new_observers
      observer
    ensure
      @mutex.unlock
    end

    # Deletes all observers
    # @return [CopyOnWriteObserverSet] self
    def delete_observers
      self.observers = {}
      self
    end


    # @return [Integer] the observers count
    def count_observers
      observers.count
    end

    # Notifies all registered observers with optional args
    #
    # @param [Object] args
    #   Arguments to be passed to each observer
    #
    # @return [CopyOnWriteObserverSet] self
    def notify_observers(*args, &block)
      notify_to(observers, *args, &block)
      self
    end

    # Notifies all registered observers with optional args and deletes them.
    #
    # @param [Object] args
    #   Arguments to be passed to each observer
    #
    # @return [CopyOnWriteObserverSet] self
    def notify_and_delete_observers(*args, &block)
      old = clear_observers_and_return_old
      notify_to(old, *args, &block)
      self
    end

    private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

    def notify_to(observers, *args)
      if block_given? && !args.empty?
        raise ArgumentError.new 'cannot give arguments and a block'
      end
      observers.each do |observer, function|
        args = yield if block_given?
        observer.send(function, *args)
      end
    end

    def observers
      @mutex.lock
      @observers
    ensure
      @mutex.unlock
    end

    def observers=(new_set)
      @mutex.lock
      @observers = new_set
    ensure
      @mutex.unlock
    end

    def clear_observers_and_return_old
      @mutex.lock
      old_observers = @observers
      @observers = {}
      old_observers
    ensure
      @mutex.unlock
    end
  end
end
