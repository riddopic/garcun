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

# Add #maybe
module Kernel

  # Random generator that returns true or false. Can also take a block that has
  # a 50/50 chance to being executed.
  #
  def maybe(chance = 0.5, &block)
    if block
      yield if rand < chance
    else
      rand < chance
    end
  end

  # Like #respond_to? but returns the result of the call if it does respond.
  #
  #   class RespondExample
  #     def f; "f"; end
  #   end
  #
  #   x = RespondExample.new
  #   x.respond(:f)  # => "f"
  #   x.respond(:g)  # => nil
  #
  # This method was known as #try until Rails defined #try
  # to be something more akin to #ergo.
  #
  def respond(sym = nil, *args, &blk)
    if sym
      return nil unless respond_to?(sym)
      __send__(sym, *args, &blk)
    else
      MsgFromGod.new(&method(:respond).to_proc)
    end
  end

  # The opposite of #nil?.
  #
  #   "hello".not_nil?     # -> true
  #   nil.not_nil?         # -> false
  #
  def not_nil?
    ! nil?
  end

  # Temporarily set variables while yielding a block, then return the
  # variables to their original settings when complete.
  #
  #   temporarily('$VERBOSE'=>false) do
  #     $VERBOSE.assert == false
  #   end
  #
  def temporarily(settings)
    cache = {}
    settings.each do |var, val|
      cache[var] = eval("#{var}")
      eval("proc{ |v| #{var} = v }").call(val)
    end
    yield
  ensure
    cache.each do |var, val|
      eval("proc{ |v| #{var} = v }").call(val)
    end
  end

  # Invokes the method identified by the symbol +method+, passing it any
  # arguments  and/or the block specified, just like the regular Ruby
  # `Object#send` does.
  #
  # *Unlike* that method however, a `NoMethodError` exception will *not*
  # be raised and +nil+ will be returned instead, if the receiving object
  # is a `nil` object or NilClass.
  #
  # For example, without try
  #
  #   @example = Struct.new(:name).new("bob")
  #
  #   @example && @example.name
  #
  # or:
  #
  #   @example ? @example.name : nil
  #
  # But with try
  #
  #   @example.try(:name)  #=> "bob"
  #
  # or
  #
  #   @example.try.name    #=> "bob"
  #
  # It also accepts arguments and a block, for the method it is trying:
  #
  #   @people.try(:collect){ |p| p.name }
  #
  def try(method=nil, *args, &block)
    if method
      __send__(method, *args, &block)
    else
      self
    end
  end

  # Parse a caller string and break it into its components,
  # returning an array composed of:
  #
  # * file (String)
  # * lineno (Integer)
  # * method (Symbol)
  #
  # For example, from irb
  #
  #     callstack(1)
  #
  # _produces_ ...
  #
  #     [["(irb)", 2, :irb_binding],
  #       ["/usr/lib/ruby/1.8/irb/workspace.rb", 52, :irb_binding],
  #       ["/usr/lib/ruby/1.8/irb/workspace.rb", 52, nil]]
  #
  # Note: If the user decides to redefine caller() to output data
  # in a different format, _prior_ to requiring this, then the
  # results will be indeterminate.
  #
  def callstack(level = 1)
    call_str_array = pp_callstack(level)
    stack = []
    call_str_array.each{ |call_str|
      file, lineno, method = call_str.split(':')
      if method =~ /in `(.*)'/ then
        method = $1.intern()
      end
      stack << [file, lineno.to_i, method]
    }
    stack
  end
  alias_method :call_stack, :callstack
  alias_method :pp_callstack,  :caller
  alias_method :pp_call_stack, :caller
end
