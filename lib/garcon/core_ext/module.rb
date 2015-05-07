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

class Module

  # Create an instance of Object and extend it with +self+.
  #
  #   mod = Module.new do
  #     def foo; "foo"; end
  #   end
  #
  #   obj = mod.to_obj
  #
  #   obj.foo #=> "foo"
  #
  def to_obj
    o = Object.new
    o.extend self
    o
  end

  # Creates a new method wrapping the previous of the same name.
  # Reference to the old method is passed into the new definition
  # block as the first parameter.
  #
  #   class WrapExample
  #     def foo
  #       "foo"
  #     end
  #
  #     wrap_method(:foo) do |old_meth, *args|
  #       old_meth.call + '!'
  #     end
  #   end
  #
  #   example = WrapExample.new
  #   example.foo #=> 'foo!'
  #
  # Keep in mind that this cannot be used to wrap methods
  # that take a block.
  #
  def wrap_method( sym, &blk )
    old = instance_method(sym)
    define_method(sym) { |*args| blk.call(old.bind(self), *args) }
  end
  alias_method :wrap, :wrap_method

  unless method_defined?(:set)
    # Sets an option to the given value. If the value is a proc,
    # the proc will be called every time the option is accessed.
    #
    def set(option, value=self, &block)
      raise ArgumentError if block && value != self
      value = block if block
      if value.kind_of?(Proc)
        if value.arity == 1
          yield self
        else
          (class << self; self; end).module_eval do
            define_method(option, &value)
            define_method("#{option}?"){ !!__send__(option) }
            define_method("#{option}="){ |val| set(option, Proc.new{val}) }
          end
        end
      elsif value == self
        option.each{ |k,v| set(k, v) }
      elsif respond_to?("#{option}=")
        __send__("#{option}=", value)
      else
        set(option, Proc.new{value})
      end
      self
    end
  end
end

