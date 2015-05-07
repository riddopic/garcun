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

class Symbol

  # Override this in a child if it cannot be dup'ed
  #
  # @return [Object]
  def try_dup
    self
  end

  # Since Symbol is immutable it cannot be duplicated.
  # For this reason #try_dup returns +self+.
  #
  #   :a.dup!  #=> :a
  #
  def dup!   ; self  ; end
  def dup?   ; false ; end
  def clone? ; false ; end

  # Join with _o_ as a file path.
  #
  # @example
  #   :chef/'provider' # => 'chef/provider'
  #   :chef/ :provider # => 'chef/provider'
  #
  # @param [#to_s] other
  #   Path component(s) to join with receiver.
  #
  # @return [String]
  #   Receiver joined with other as a file path.
  #
  # @api public
  def /(other)
    File.join(self.to_s, other.to_s)
  end

  # Symbol does not end in `!`, `=`, or `?`.
  #
  #   :a.plain?   #=> true
  #   :a?.plain?  #=> false
  #   :a!.plain?  #=> false
  #   :a=.plain?  #=> false
  #
  def plain?
    c = to_s[-1,1]
    !(c == '=' || c == '?' || c == '!')
  end

  # Alias for `#plain?` method. Likely this should have been the original
  # and only name, but such is life.
  alias_method :reader?, :plain?

  # Symbol ends in `=`.
  #
  #   :a=.setter? #=> true
  #   :a.setter?  #=> false
  #
  def setter?
    to_s[-1,1] == '='
  end

  # Alias for `#setter?` method. Likely this should have been the original
  # and only name, but such is life.
  alias_method :writer?, :setter?

  # Symbol ends in `?`.
  #
  #   :a?.query? #=> true
  #   :a.query?  #=> false
  #
  def query?
    to_s[-1,1] == '?'
  end

  # Symbol ends in `!`.
  #
  #   :a!.bang? #=> true
  #   :a.bang?  #=> false
  #
  def bang?
    to_s[-1,1] == '!'
  end

  # Does a symbol have a "not" sign?
  #
  #   "friend".to_sym.not?   #=> false
  #   "~friend".to_sym.not?  #=> true
  #
  def not?
    self.to_s.slice(0,1) == '~'
  end

  # Add a "not" sign to the front of a symbol.
  #
  #   (~:friend)  #=> :"~friend"
  #
  def ~@
    if self.to_s.slice(0,1) == '~'
      "#{self.to_s[1..-1]}".to_sym
    else
      "~#{self}".to_sym
    end
  end

  # Generate a unique symbol.
  #
  #   Symbol.generate  #=> :"-1"
  #
  # If +key+ is given the new symbol will be prefixed with it.
  #
  #   Symbol.generate(:foo)  #=> :"foo-1"
  #
  def self.generate(key = nil)
    key = key.to_sym if key
    @symbol_generate_counter ||= {}
    @symbol_generate_counter[key] ||= 0
    num = @symbol_generate_counter[key] += 1
    ("#{key}-%X" % num).to_sym
  end

  # This allows us to call obj(&:method) instead of obj { |i| i.method }
  unless method_defined?(:to_proc)
    def to_proc
      proc { |obj, args| obj.send(self, *args) }
      # lambda { |obj, args=nil| obj.send(self, *args) }
    end
  end

  # Useful extension for &:symbol which makes it possible
  # to pass arguments for method in block
  #
  #   ['abc','','','def','ghi'].tap(&:delete.(''))
  #   #=> ['abc','def','ghi']
  #
  #   [1,2,3].map(&:to_s.(2))
  #   #=> ['1','10','11']
  #
  #   ['abc','cdef','xy','z','wwww'].select(&:size.() == 4)
  #   #=> ['cdef', 'wwww']
  #
  #   ['abc','aaA','AaA','z'].count(&:upcase.().succ == 'AAB')
  #   #=> 2
  #
  #   [%w{1 2 3 4 5},%w{6 7 8 9}].map(&:join.().length)
  #   #=> [5,4]
  #
  def call(*args, &block)
    proc do |recv|
      recv.__send__(self, *args, &block)
    end
  end
end
