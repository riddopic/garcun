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


# Add #blank?, #present?, #try and #try! methods to Object class.
class Object

  # Returns true if the object is nil or empty (if applicable)
  #
  # @example
  #   [].blank?         # =>  true
  #   [1].blank?        # =>  false
  #   [nil].blank?      # =>  false
  #
  # @return [Boolean]
  #
  def blank?
    nil? || (respond_to?(:empty?) && empty?)
  end

  # Returns true if the object is NOT nil or empty
  #
  # @example
  #   [].present?         # =>  false
  #   [1].present?        # =>  true
  #   [nil].present?      # =>  true
  #
  # @return [Boolean]
  #
  def present?
    !blank?
  end

  # Invokes the public method whose name goes as first argument just like
  # `public_send` does, except that if the receiver does not respond to it the
  # call returns `nil` rather than raising an exception.
  #
  # @note
  #   `try` is defined on `Object`. Therefore, it won't work with instances
  #   of classes that do not have `Object` among their ancestors, like direct
  #   subclasses of `BasicObject`.
  #
  # @param [String] object
  #
  # @param [Symbol] method
  #
  # @return [Object]
  #
  def try(*a, &b)
    try!(*a, &b) if a.empty? || respond_to?(a.first)
  end

  # Same as #try, but will raise a NoMethodError exception if the receiver is
  # not `nil` and does not implement the tried method.
  #
  # @raise NoMethodError
  #   If the receiver is not `nil` and does not implement the tried method.
  #
  # @return [Object]
  #
  def try!(*a, &b)
    if a.empty? && block_given?
      if b.arity.zero?
        instance_eval(&b)
      else
        yield self
      end
    else
      public_send(*a, &b)
    end
  end

  # If receiver is callable, calls it and returns result. If not, just returns
  # receiver itself.
  #
  # @return [Object]
  #
  def try_call(*args)
    if self.respond_to?(:call)
      self.call(*args)
    else
      self
    end
  end

  # An identity method that provides access to an object's 'self'.
  #
  # Example
  #   [1,2,3,4,5,1,2,2,3].group_by(&:itself)
  #   #=> {1=>[1, 1], 2=>[2, 2, 2], 3=>[3, 3], 4=>[4], 5=>[5]}
  #
  def itself
    self
  end

  # Override this in a child class if it cannot be dup'ed.
  #
  #   obj1 = Object.new
  #   obj2 = obj1.dup!
  #   obj2.equal?(obj1)    #=> false
  #
  # @return [Object]
  #
  def dup!
    dup
  end

  # Alternative name for #dup!
  #
  # @return [Object]
  #
  def try_dup
    dup!
  end

  # Can you safely call #dup on this object?
  #
  # Returns `false` for `nil`, `false`, `true`, symbols, and numbers;
  # `true` otherwise.
  #
  # @return [Object]
  #
  def dup?   ; true ; end
  def clone? ; true ; end

  # Extracts the singleton class, so that metaprogramming can be done on it.
  #
  # @example [Setup]
  #   class MyString < String; end
  #
  #   MyString.instance_eval do
  #     define_method :foo do
  #       puts self
  #     end
  #   end
  #
  #   MyString.meta_class.instance_eval do
  #     define_method :bar do
  #       puts self
  #     end
  #   end
  #
  #   def String.add_meta_var(var)
  #     self.meta_class.instance_eval do
  #       define_method var do
  #         puts "HELLO"
  #       end
  #     end
  #   end
  #
  # @example
  #   MyString.new("Hello").foo # => "Hello"
  #
  # @example
  #   MyString.new("Hello").bar
  #     # => NoMethodError: undefined method `bar' for "Hello":MyString
  #
  # @example
  #   MyString.foo
  #     # => NoMethodError: undefined method `foo' for MyString:Class
  #
  # @example
  #   MyString.bar
  #     # => MyString
  #
  # @example
  #   String.bar
  #     # => NoMethodError: undefined method `bar' for String:Class
  #
  # @example
  #   MyString.add_meta_var(:x)
  #   MyString.x # => HELLO
  #
  # @details [Description of Examples]
  #   As you can see, using #meta_class allows you to execute code (and here,
  #   define a method) on the metaclass itself. It also allows you to define
  #   class methods that can be run on subclasses, and then be able to execute
  #   code on the metaclass of the subclass (here MyString).
  #
  #   In this case, we were able to define a class method (add_meta_var) on
  #   String that was executable by the MyString subclass. It was then able to
  #   define a method on the subclass by adding it to the MyString metaclass.
  #
  # @return [Class]
  #   The meta class.
  #
  def meta_class() class << self; self end end

  # @param [String] name
  #   The name of the constant to get, e.g. "Garcon::Check".
  #
  # @return [Object]
  #   The constant corresponding to the name.
  #
  def full_const_get(name)
    list = name.split('::')
    list.shift if list.first.blank?
    obj = self
    list.each do |x|
      obj = obj.const_defined?(x) ? obj.const_get(x) : obj.const_missing(x)
    end
    obj
  end

  # @param [String] name
  #   The name of the constant to get, e.g. "Garcon::Check".
  #
  # @param [Object] value
  #   The value to assign to the constant.
  #
  # @return [Object]
  #   The constant corresponding to the name.
  #
  def full_const_set(name, value)
    list = name.split('::')
    toplevel = list.first.blank?
    list.shift if toplevel
    last = list.pop
    obj = list.empty? ? Object : Object.full_const_get(list.join('::'))
    obj.const_set(last, value) if obj && !obj.const_defined?(last)
  end

  # Defines module from a string name (e.g. Foo::Bar::Baz). If module already
  # exists, no exception raised.
  #
  # @param [String] name
  #   The name of the full module name to make
  #
  # @return [nil]
  #
  def make_module(string)
    current_module = self
    string.split('::').each do |part|
      current_module = if current_module.const_defined?(part)
        current_module.const_get(part)
      else
        current_module.const_set(part, Module.new)
      end
    end
    current_module
  end

  # @param [Symbol, Class, Array] duck
  #   The thing to compare the object to.
  #
  # @note
  #   The behavior of the method depends on the type of duck as follows:
  #   Symbol:: Check whether the object respond_to?(duck).
  #   Class::  Check whether the object is_a?(duck).
  #   Array::  Check whether the object quacks_like? at least one of the
  #            options in the array.
  #
  # @return [Boolean]
  #   True if the object quacks like a duck.
  #
  def quacks_like?(duck)
    case duck
    when Symbol
      self.respond_to?(duck)
    when Class
      self.is_a?(duck)
    when Array
      duck.any? { |d| self.quacks_like?(d) }
    else
      false
    end
  end

  # @example 1.in?([1,2,3]) # => true
  #
  # @example 1.in?(1,2,3) # => true
  #
  # @param [#include?] arrayish
  #   Container to check, to see if it includes the object.
  #
  # @param [Array] *more
  #   additional args, will be flattened into arrayish
  #
  # @return [Boolean]
  #   True if the object is included in arrayish (+ more)
  #
  def in?(arrayish, *more)
    arrayish = more.unshift(arrayish) unless more.empty?
    arrayish.include?(self)
  end

  # Get or set state of object. You can think of #object_state as an in-code
  # form of marshalling.
  #
  #   class StateExample
  #     attr_reader :a, :b
  #     def initialize(a,b)
  #       @a, @b = a, b
  #     end
  #   end
  #
  #   obj = StateExample.new(1,2)
  #   obj.a  #=> 1
  #   obj.b  #=> 2
  #
  #   obj.object_state  #=> {:a=>1, :b=>2}
  #
  #   obj.object_state(:a=>3, :b=>4)
  #   obj.a  #=> 3
  #   obj.b  #=> 4
  #
  # For most object's this is essentially the same as `instance.to_h`.
  # But for data structures like Array and Hash it returns a snapshot of their
  # contents, not the state of their instance variables.
  #
  def object_state(data = nil)
    if data
      instance_variables.each do |iv|
        name = iv.to_s.sub(/^[@]/, '').to_sym
        instance_variable_set(iv, data[name])
      end
    else
      data = {}
      instance_variables.each do |iv|
        name = iv.to_s.sub(/^[@]/, '').to_sym
        data[name] = instance_variable_get(iv)
      end
      data
    end
  end
end
