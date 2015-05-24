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

require 'garcon'

class Chef
  class Resource
    class Development < Chef::Resource
      include Garcon

      # Chef attributes
      identity_attr :name
      provides      :development

      # Actions
      actions        :run
      default_action :run

      # Attributes
      attribute :name,
        kind_of: String
    end
  end

  class Provider
    class Development < Chef::Provider
      include Garcon

      # Shortcut to new_resource.
      #
      alias_method :r, :new_resource

      # Boolean indicating if WhyRun is supported by this provider
      #
      # @return [TrueClass, FalseClass]
      #
      # @api private
      def whyrun_supported?
        true
      end

      # Load and return the current resource.
      #
      # @return [Chef::Provider:Development]
      #
      # @api private
      def load_current_resource
        @current_resource ||= Chef::Resource::Development.new(r.name)
        @current_resource
      end

      def action_run
        chef_handler
        install_gem('pry')
        Chef::Recipe.send(:require, 'pry')
        install_gem('awesome_print')
        Chef::Recipe.send(:require, 'ap')
      end

      private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

      def chef_handler
        include_recipe 'chef_handler::default'

        file = ::File.join(node[:chef_handler][:handler_path], 'devreporter.rb')
        f ||= Chef::Resource::CookbookFile.new(file, run_context)
        f.cookbook   'garcon'
        f.backup      false
        f.owner      'root'
        f.group      'root'
        f.mode        00600
        f.run_action :create

        h ||= Chef::Resource::ChefHandler.new('DevReporter', run_context)
        h.source      file
        h.supports    report: true, exception: true
        h.run_action :enable
      end


      def os_includes
        case node['platform_family']
        when 'debian'
        	include_recipe 'apt'
      end

      %w(build-essential git).each do |ir|
        include_recipe ir
      end

      chef_dk 'my_chef_dk' do
          version 'latest'
          global_shell_init true
          action :install
      end

      chef_gem 'knife-push'


      def install_gem(name)
        g ||= Chef::Resource::ChefGem.new(name, run_context)
        g.compile_time(false) if respond_to?(:compile_time)
        g.not_if { gem_installed?(name) }
        g.run_action :install
      end
    end
  end
end

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :amazon,
  resource: :development,
  provider:  Chef::Provider::Development
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :centos,
  resource: :development,
  provider:  Chef::Provider::Development
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :oracle,
  resource: :development,
  provider:  Chef::Provider::Development
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :redhat,
  resource: :development,
  provider:  Chef::Provider::Development
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :scientific,
  resource: :development,
  provider:  Chef::Provider::Development
)
