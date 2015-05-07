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
  module Resource
    # Helper module to automatically set @resource_name.
    #
    # @example
    #   class MyResource < Chef::Resource
    #     include Garcon
    #
    #     provides :my_resource
    #   end
    #
    module ResourceName
      # Constructor for Chef::Resource::MyResource.
      #
      def initialize(*args)
        super
        if self.class.resource_name(false)
          @resource_name = self.class.resource_name
        else
          @resource_name ||= self.class.resource_name
        end
      end

      module ClassMethods
        # Maps a resource/provider (and optionally a platform and version) to a
        # Chef resource/provider. This allows finer grained per platform
        # resource attributes and the end of overloaded resource definitions.
        #
        # @note
        #   The provides method must be defined in both the custom resource and
        #   custom provider files and both files must have identical provides
        #   statement(s).
        #
        # @param [Symbol] name
        #   Name of a Chef resource/provider to map to.
        #
        # @return [undefined]
        #
        def provides(name)
          if self.name && respond_to?(:constantize)
            old_constantize = instance_method(:constantize)
            define_singleton_method(:constantize) do |name|
              name == self.name ? self : old_constantize.bind(self).call(name)
            end
          end
          @provides_name = name
          super if defined?(super)
        end

        # Return the Snake case name of the current resource class. If not set
        # explicitly it will be introspected based on the class name.
        #
        # @param [Boolean] auto
        #   Try to auto-detect based on class name.
        #
        # @return [Symbol]
        #
        def resource_name(auto = true)
          return @provides_name if @provides_name
          @provides_name || if name && name.start_with?('Chef::Resource')
            Garcon::Inflections.snakeify(name, 'Chef::Resource').to_sym
          elsif name
            Garcon::Inflections.snakeify(name.split('::').last).to_sym
          end
        end

        # Used by Resource#to_text to find the human name for the resource.
        #
        def dsl_name
          resource_name.to_s
        end

        # Hook called when module is included, extends a descendant with class
        # and instance methods.
        #
        # @param [Module] descendant
        #   the module or class including Garcon::Resource::ResourceName
        #
        # @return [self]
        #
        def included(descendant)
          super
          descendant.extend ClassMethods
        end
      end

      extend ClassMethods
    end
  end
end
