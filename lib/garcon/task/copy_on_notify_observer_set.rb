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

  # A thread safe observer set implemented using copy-on-read approach:
  # observers are added and removed from a thread safe collection; every time
  # a notification is required the internal data structure is copied to
  # prevent concurrency issues
  class CopyOnNotifyObserverSet

    def initialize
      @mutex = Mutex.new
      @observers = {}
    end

    # Adds an observer to this set. If a block is passed, the observer will be
    # created by this method and no other params should be passed
    #
    # @param [Object] observer
    #   The observer to add
    #
    # @param [Symbol] func
    #   The function to call on the observer during notification. The default
    #   is :update
    #
    # @return [Object]
    #   the added observer
    def add_observer(observer = nil, func = :update, &block)
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
        @observers[observer] = func
      ensure
        @mutex.unlock
      end

      observer
    end

    # @param [Object] observer
    #   the observer to remove
    # @return [Object]
    #   the deleted observer
    def delete_observer(observer)
      @mutex.lock
      @observers.delete(observer)
      @mutex.unlock

      observer
    end

    # Deletes all observers
    # @return [CopyOnWriteObserverSet] self
    def delete_observers
      @mutex.lock
      @observers.clear
      @mutex.unlock

      self
    end

    # @return [Integer]
    #   the observers count
    def count_observers
      @mutex.lock
      result = @observers.count
      @mutex.unlock

      result
    end

    # Notifies all registered observers with optional args
    #
    # @param [Object] args
    #   arguments to be passed to each observer
    #
    # @return [CopyOnWriteObserverSet] self
    def notify_observers(*args, &block)
      observers = duplicate_observers
      notify_to(observers, *args, &block)

      self
    end

    # Notifies all registered observers with optional args and deletes them.
    #
    # @param [Object] args
    #   arguments to be passed to each observer
    #
    # @return [CopyOnWriteObserverSet] self
    def notify_and_delete_observers(*args, &block)
      observers = duplicate_and_clear_observers
      notify_to(observers, *args, &block)

      self
    end

    private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

    def duplicate_and_clear_observers
      @mutex.lock
      observers = @observers.dup
      @observers.clear
      @mutex.unlock

      observers
    end

    def duplicate_observers
      @mutex.lock
      observers = @observers.dup
      @mutex.unlock

      observers
    end

    def notify_to(observers, *args)
      if block_given? && !args.empty?
        raise ArgumentError.new 'cannot give arguments and a block'
      end
      observers.each do |observer, function|
        args = yield if block_given?
        observer.send(function, *args)
      end
    end
  end
end
