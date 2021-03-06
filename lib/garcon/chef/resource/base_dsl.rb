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

require_relative 'attribute'

module Garcon
  module Resource
    # Provide default_action and actions like LWRPBase.
    #
    module BaseDSL
      module ClassMethods
        # Imitate the behavior of the `Chef::Resource::LWRPBase` DSL providing
        # a `default_action` method.
        #
        # @param [Symbol, String] name
        #   The default action.
        #
        # @return [undefined]
        #
        def default_action(name = nil)
          if name
            @default_action = name
            actions(name)
          end
          @default_action || (superclass.respond_to?(:default_action) &&
                              superclass.default_action) ||
                              :actions.first || :nothing
        end

        # Imitate the behavior of the `Chef::Resource::LWRPBase` LWRP DSL
        # providing a `action` method.
        #
        # @param [Array<String, Symbol>] name
        #   The default action.
        #
        # @return [undefined]
        #
        def actions(*names)
          @actions ||= superclass.respond_to?(:actions) ?
                       superclass.actions.dup : []
          (@actions << names).flatten!.uniq!
          @actions
        end

        def basic(source = nil)
          source ||= self
          hash    = Hash.new
          pattern = Regexp.new('^_set_or_return_(.+)$')
          source.public_methods(false).each do |method|
            pattern.match(method) do |m|
              attribute = m[1].to_sym
              hash[attribute] = send(attribute)
            end
          end
          Attribute.from_hash(hash)
        end

        def full(attribute = nil, source = nil, recursion = 3)
          source ||= self
          if attribute && (attribute.is_a?(Hash) || attribute.is_a?(Mash))
            data = attribute
          else
            data = Hash.new
          end
          data = Mash.from_hash(data) unless data.is_a?(Mash)
          data.merge!(attr_mash(source))
          data = data.symbolize_keys
          data.each do |k,v|
            next unless v.is_a? String

            for i in 1..recursion
              v2 = v % data
              v2 == v ? break : data[k] = v = v2
            end
          end
          Attribute.from_hash(data)
        end

        # Imitate the behavior of the `Chef::Resource::LWRPBase` LWRP DSL
        # providing a `attribute` method.
        #
        # @param [Symbol] name
        #
        # @param [Hash] opts
        #
        # @return [undefined]
        #
        def attribute(name, opts)
          coerce = opts.delete(:coerce)
          define_method(name) do |arg = nil, &block|
            if coerce && !arg.nil?
              arg = Garcon.coercer.coerce(arg, &coerce)
              # arg = instance_exec(arg, &coerce)
            else
              arg = block if arg.nil?
            end
            set_or_return(name, arg, opts)
          end
        end

        # Hook called when module is included, extends a descendant with class
        # and instance methods.
        #
        # @param [Module] descendant
        #   the module or class including Garcon::Resource::BaseDSL
        #
        # @return [self]
        #
        def included(descendant)
          super
          descendant.extend ClassMethods
        end
      end

      extend ClassMethods

      # Constructor for Chef::Resource::YourSuperAwesomeResource.
      #
      def initialize(*args)
        super
        @action = self.class.default_action if @action == :nothing
        (@allowed_actions << self.class.actions).flatten!.uniq!
      end
    end
  end

  module Provider
    # Helper to handle load_current_resource for direct subclasses of Provider
    #
    module BaseDSL
      module ClassMethods
        # Hook called when module is included, extends a descendant with class
        # and instance methods.
        #
        # @param [Module] descendant
        #   The module or class including Garcon::Provider::BaseDSL
        #
        # @return [self]
        #
        def included(descendant)
          super
          descendant.extend ClassMethods
          if descendant.is_a?(Class) && descendant.superclass == Chef::Provider
            descendant.class_exec { include Implementation }
          end
          descendant.class_exec { include Chef::DSL::Recipe }
        end
      end

      module Implementation
        def load_current_resource
        end
      end

      extend ClassMethods
    end
  end
end
