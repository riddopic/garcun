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
require 'digest/md5'

class Chef
  class Resource
    class Partial < Chef::Resource
      include Garcon

      # Chef attributes
      identity_attr :name
      provides :partial

      # Actions
      actions :run
      default_action :run

      # Attributes
      attribute :run_list,
        kind_of: String
      attribute :save,
        kind_of: [TrueClass, FalseClass],
        default: true
      attribute :arguments,
        kind_of: Hash
      attribute :attributes,
        kind_of: Hash
    end
  end

  class Provider
    class Partial < Chef::Provider
      include Garcon

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
      # @return [Chef::Provider::Partial]
      #
      # @api private
      def load_current_resource
        @current_resource ||= Chef::Resource::Partial.new(new_resource.name)
        @current_resource
      end

      def action_run(r = new_resource)
        converge_by "Executing partial run list: #{r.run_list}" do
          partial = r.name
          runner  = Chef::PartialRun.new(partial, r.attributes, r.arguments)
          runner.partial_run(r.run_list)
          unless runner.run_status.updated_resources.empty?
            r.updated_by_last_action(true)
          end
        end

        if r.save
          node.consume_attributes(runner.clean_attrs)
          runner.save_updated_node
        end
      end
    end
  end

  class PartialRun < Client
    def initialize(partial, attributes = nil, arguments = {})
      super(attributes, arguments)
      @partial = partial
    end

    def partial_run(run_list)
      cache_path = file_cache_path
      begin
        digest = Digest::MD5.hexdigest(@partial)
        Chef::Config[:file_cache_path] = file_cache_path("partial-#{digest}")
        run_ohai
        register unless Chef::Config[:solo]
        load_node
        run_list_items = run_list.split(',').collect do |item|
          Chef::RunList::RunListItem.new(item)
        end
        node.run_list(*run_list_items)
        build_node
        run_context = setup_run_context
        converge(run_context)
      ensure
        Chef::Config[:file_cache_path] = cache_path
      end
    end

    # Clean the node data
    #
    def clean_attrs
      data = node.to_hash
      %w(run_list recipes roles).each { |k| data.delete(k) }
      data
    end

    def run_completed_successfully
      # do nothing
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
  resource: :partial,
  provider:  Chef::Provider::Partial
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :centos,
  resource: :partial,
  provider:  Chef::Provider::Partial
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :oracle,
  resource: :partial,
  provider:  Chef::Provider::Partial
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :redhat,
  resource: :partial,
  provider:  Chef::Provider::Partial
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :scientific,
  resource: :partial,
  provider:  Chef::Provider::Partial
)
