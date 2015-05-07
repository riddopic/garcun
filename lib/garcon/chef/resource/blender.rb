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

require 'chef/provider'

module Garcon
  module Resource
    # Combine a resource and provider class for quick and easy oven baked
    # goodness. Never has cooking been this fun since the invention of the
    # grocery store!
    #
    # @example
    #   class Chef::Resource::HouseKeeping < Chef::Resource
    #     include Garcon(blender: true)
    #
    #     attribute :path,
    #       kind_of: String,
    #       name_attribute: true
    #     attribute :message,
    #       kind_of: String,
    #       default: 'Clean the kitchen'
    #
    #     action :run do
    #       file new_resource.path do
    #         content new_resource.message
    #       end
    #     end
    #   end
    #
    module Blender
      # Coerce is_a? so that the DSL will consider this a Provider for the
      # purposes of attaching enclosing_provider.
      #
      # @param klass [Class]
      #
      # @return [Boolean]
      #
      # @api private
      def is_a?(klass)
        klass == Chef::Provider ? true : super
      end

      # Coerce provider_for_action so that the resource is also the provider.
      #
      # @param action [Symbol]
      #
      # @return [Chef::Provider]
      #
      # @api private
      def provider_for_action(action)
        provider(self.class.blender_provider_class) unless provider
        super
      end

      module ClassMethods
        # Define a provider action. The block should contain the usual provider
        # code.
        #
        # @param name [Symbol]
        #   Name of the action.
        #
        # @param block [Proc]
        #   Action implementation.
        #
        def action(name, &block)
          blender_actions[name.to_sym] = block
          actions(name.to_sym) if respond_to?(:actions)
        end

        # Storage accessor for blended action blocks. Maps action name to proc.
        #
        # @return [Hash<Symbol, Proc>]
        #
        # @api private
        def blender_actions
          (@blender_actions ||= {})
        end

        # Create a provider class for the blender actions in this resource.
        # Inherits from the blender provider class of the resource's
        # superclass if present.
        #
        # @return [Class]
        #
        # @api private
        def blender_provider_class
          @blender_provider_class ||= begin
            provider_superclass = begin
              self.superclass.blender_provider_class
            rescue NoMethodError
              Chef::Provider
            end
            actions = blender_actions
            class_name = self.name
            Class.new(provider_superclass) do
              include Garcon
              define_singleton_method(:name) { class_name + ' (blender)' }
              actions.each do |action, block|
                define_method(:"action_#{action}", &block)
              end
            end
          end
        end

        # Hook called when module is included, extends a descendant with class
        # and instance methods.
        #
        # @param [Module] descendant
        #   The module or class including Garcon::Resource::Blender
        #
        # @return [self]
        #
        # @api private
        def included(descendant)
          super
          descendant.extend ClassMethods
        end
      end

      extend ClassMethods
    end
  end
end

