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
  module Extensions
    # MethodReader allows you to access keys of the hash via method calls. This
    # gives you an OStruct like way to access your hash's keys. It will
    # recognize keys either as strings or symbols.
    #
    # @note
    #   That while nil keys will be returned as nil, undefined keys will raise
    #   NoMethodErrors. Also note that #respond_to? has been patched to
    #   appropriately recognize key methods.
    #
    # @example
    #   class StashCache < Hash
    #     include Garcon::Extensions::MethodReader
    #   end
    #
    #   cash = StashCache.new
    #   cash['box'] = 'full'
    #   cash.box # => 'full'
    #
    module MethodReader
      def respond_to?(name, include_private = false)
        return true if key?(name.to_s) || key?(name.to_sym)
        super
      end

      def method_missing(name, *args)
        if key?(name)
          self[name]
        else
          sname = name.to_s
          if key?(sname)
            self[sname]
          elsif sname[-1] == '?'
            kname = sname[0..-2]
            key?(kname) || key?(kname.to_sym)
          else
            super
          end
        end
      end
    end

    # MethodWriter gives you #key_name= shortcuts for writing to your hash.
    # Keys are written as strings, override #convert_key if you would like to
    # have symbols or something else.
    #
    # @note
    #   That MethodWriter also overrides #respond_to such that any
    #   #method_name= will respond appropriately as true.
    #
    # @example
    #   class MyHash < Hash
    #     include Garcon::Extensions::MethodWriter
    #   end
    #
    #   h = MyHash.new
    #   h.awesome = 'sauce'
    #   h['awesome'] # => 'sauce'
    #
    module MethodWriter
      def respond_to?(name, include_private = false)
        return true if name.to_s =~ /=$/
        super
      end

      def method_missing(name, *args)
        if args.size == 1 && name.to_s =~ /(.*)=$/
          return self[convert_key(Regexp.last_match[1])] = args.first
        end

        super
      end

      def convert_key(key)
        key.to_s
      end
    end

    # MethodQuery gives you the ability to check for the truthiness of a key
    # via method calls. Note that it will return false if the key is set to a
    # non-truthful value, not if the key isn't set at all. Use #key? for
    # checking if a key has been set.
    #
    # MethodQuery will check against both string and symbol names of the method
    # for existing keys. It also patches #respond_to to appropriately detect
    # the query methods.
    #
    # @example
    #   class MyHash < Hash
    #     include Garcon::Extensions::MethodQuery
    #   end
    #
    #   h = MyHash.new
    #   h['abc'] = 123
    #   h.abc? # => true
    #   h['def'] = nil
    #   h.def? # => false
    #   h.hji? # => NoMethodError
    #
    module MethodQuery
      def respond_to?(name, include_private = false)
        if name.to_s =~ /(.*)\?$/ && (key?(Regexp.last_match[1]) ||
                                      key?(Regexp.last_match[1].to_sym))
          return true
        end
        super
      end

      def method_missing(name, *args)
        if args.empty? && name.to_s =~ /(.*)\?$/ &&
          (key?(Regexp.last_match[1]) ||
           key?(Regexp.last_match[1].to_sym))
          return self[Regexp.last_match[1]] ||
                 self[Regexp.last_match[1].to_sym]
        end
        super
      end
    end

    # A macro module that will automatically include MethodReader,
    # MethodWriter, and MethodQuery, giving you the ability to read, write,
    # and query keys in a hash using method call shortcuts.
    #
    module MethodAccess
      def self.included(base)
        [MethodReader, MethodWriter, MethodQuery].each do |mod|
          base.send :include, mod
        end
      end
    end

    # MethodOverridingWriter gives you #key_name= shortcuts for writing to your
    # hash. It allows methods to be overridden by #key_name= shortcuts and
    # aliases those methods with two leading underscores.
    #
    # Keys are written as strings. Override #convert_key if you would like to
    # have symbols or something else.
    #
    # Note that MethodOverridingWriter also overrides #respond_to_missing? such
    # that any #method_name= will respond appropriately as true.
    #
    # @example
    #   class MyHash < Hash
    #     include Garcon::Extensions::MethodOverridingWriter
    #   end
    #
    #   h = MyHash.new
    #   h.awesome = 'sauce'
    #   h['awesome'] # => 'sauce'
    #   h.zip = 'a-dee-doo-dah'
    #   h.zip # => 'a-dee-doo-dah'
    #   h.__zip # => [[['awesome', 'sauce'], ['zip', 'a-dee-doo-dah']]]
    #
    module MethodOverridingWriter
      def convert_key(key)
        key.to_s
      end

      def method_missing(name, *args)
        if args.size == 1 && name.to_s =~ /(.*)=$/
          key = Regexp.last_match[1]
          redefine_method(key) if method?(key) && !already_overridden?(key)
          return self[convert_key(key)] = args.first
        end

        super
      end

      def respond_to_missing?(name, include_private = false)
        return true if name.to_s.end_with?('=')
        super
      end

      protected

      def already_overridden?(name)
        method?("__#{name}")
      end

      def method?(name)
        methods.map(&:to_s).include?(name)
      end

      def redefine_method(method_name)
        eigenclass = class << self; self; end
        eigenclass.__send__(:alias_method, "__#{method_name}", method_name)
        eigenclass.__send__(:define_method, method_name, -> {self[method_name]})
      end
    end

    # A macro module that will automatically include MethodReader,
    # MethodOverridingWriter, and MethodQuery, giving you the ability to read,
    # write, and query keys in a hash using method call shortcuts that can
    # override object methods. Any overridden object method is automatically
    # aliased with two leading underscores.
    #
    module MethodAccessWithOverride
      def self.included(base)
        [MethodReader, MethodOverridingWriter, MethodQuery].each do |mod|
          base.send :include, mod
        end
      end
    end
  end

  module Extensions
    module PrettyInspect
      def self.included(base)
        base.send :alias_method, :hash_inspect, :inspect
        base.send :alias_method, :inspect, :stash_inspect
      end

      def stash_inspect
        ret = "#<#{self.class}"
        keys.sort_by(&:to_s).each do |key|
          ret << " #{key}=#{self[key].inspect}"
        end
        ret << '>'
        ret
      end
    end
  end
end
