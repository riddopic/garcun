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

require_relative 'chef/chef_helpers'
require_relative 'chef/node'
require_relative 'chef/secret_bag'
require_relative 'chef/validations'

require_relative 'chef/resource/attribute'
require_relative 'chef/resource/base_dsl'
require_relative 'chef/resource/blender'
require_relative 'chef/resource/lazy_eval'

module Garcon
  # Extend Resource with class and instance methods.
  #
  module Resource
    include BaseDSL
    include LazyEval
    include Validations
    include Garcon::UrlHelper
    include Garcon::FileHelper

    module ClassMethods
      # Interpolate node attributes automatically.
      #
      def interpolate(namespace = nil)
        node.set[namespace] = interpolate(Garcon.config.stash[namespace])
      end

      # Combine a resource and provider class for quick and easy oven baked
      # goodness. Never has cooking been this fun since the invention of the
      # grocery store!
      #
      def blender
        include Garcon::Resource::Blender
      end

      # Hook called when module is included, extends a descendant with class
      # and instance methods.
      #
      # @param [Module] descendant
      #   the module or class including Garcon
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

  # Extend Provider with class and instance methods.
  #
  module Provider
    include BaseDSL
    include Garcon::Retry
    include Garcon::Timeout
    include Garcon::UrlHelper
    include Garcon::FileHelper
    include Garcon::ChefHelpers
  end

  # Hook called when module is included, extends a descendant with class
  # and instance methods.
  #
  # @param [Module] descendant
  #   the module or class including Garcon
  #
  # @return [self]
  #
  # @api private
  def self.included(descendant)
    super
    if descendant < Chef::Resource
      descendant.class_exec { include Garcon::Resource }
    elsif descendant < Chef::Provider
      descendant.class_exec { include Garcon::Provider }
    end
  end
end

def Garcon(opts = {})
  if opts.is_a?(Class)
    opts = { parent: opts }
  end

  mod = Module.new

  def mod.name
    super || 'Garcon'
  end

  mod.define_singleton_method(:included) do |base|
    super(base)
    base.class_exec { include Garcon }
    if base < Chef::Resource
      base.interpolate(opts[:node], opts[:namespace]) if opts[:interpolate]
      base.blender if opts[:blender]
    end
  end

  mod
end

unless Chef::Recipe.ancestors.include?(Garcon::ChefHelpers)
  Chef::Recipe.send(:include,   Garcon::ChefHelpers)
  Chef::Resource.send(:include, Garcon::ChefHelpers)
  Chef::Provider.send(:include, Garcon::ChefHelpers)
end

unless Chef::Recipe.ancestors.include?(Garcon::Interpolation)
  Chef::Recipe.send(:include,   Garcon::Interpolation)
  Chef::Resource.send(:include, Garcon::Interpolation)
  Chef::Provider.send(:include, Garcon::Interpolation)
end

require_relative 'chef/provider/civilize'
require_relative 'chef/provider/development'
require_relative 'chef/provider/download'
require_relative 'chef/provider/house_keeping'
require_relative 'chef/provider/node_cache'
require_relative 'chef/provider/zip_file'
