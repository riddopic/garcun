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
    class Civilize < Chef::Resource
      include Garcon

      # Chef attributes
      identity_attr :name
      provides      :civilize

      # Actions
      actions        :run
      default_action :run

      # Attributes
      attribute :name,
        kind_of: String
      attribute :iptables,
        kind_of: [TrueClass, FalseClass],
        default: true
      attribute :selinux,
        kind_of: [TrueClass, FalseClass],
        default: true
      attribute :dotfiles,
        kind_of: [TrueClass, FalseClass, String, Array],
        default: true
      attribute :ruby,
        kind_of: [TrueClass, FalseClass],
        default: true
      attribute :docker,
        kind_of: Array,
        default: %w[tar htop initscripts]
      attribute :rhel_svcs,
        kind_of: Array,
        default: %w[
          autofs avahi-daemon bluetooth cpuspeed cups gpm haldaemon messagebus
        ]
    end
  end

  class Provider
    class Civilize < Chef::Provider
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
      # @return [Chef::Provider::Civilize]
      #
      # @api private
      def load_current_resource
        @current_resource ||= Chef::Resource::Civilize.new(r.name)
        @current_resource
      end

      def action_run
        civilize_docker if docker? && r.docker
        rhel_services   if r.rhel_svcs
        iptables        if !docker? && r.iptables
        selinux         if selinux? && r.selinux
        ps1prompt
        dotfiles        if r.dotfiles
      end

      private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

      def civilize_docker
        r.docker.each { |pkg| package pkg }
      end

      def rhel_services
        r.rhel_svcs.each do |svc|
          service(svc) { action [:stop, :disable] }
        end
      end

      def iptables
        shell_out!('iptables -F')
      end

      def selinux
        shell_out!('setenforce 0')
      end

      def ps1prompt
        ver = run_context.cookbook_collection[cookbook_name].metadata.version
        t ||= Chef::Resource::Template.new('/etc/profile.d/ps1.sh', run_context)
        t.cookbook   'garcon'
        t.owner      'root'
        t.group      'root'
        t.mode        00644
        t.variables   version: ver
        t.run_action :create
      end

      def dotfiles
        users = if r.dotfiles.is_a?(TrueClass)
                  Array('root')
                elsif r.dotfiles.respond_to?(:to_ary)
                  users = r.dotfiles
                elsif r.dotfiles.respond_to?(:to_str)
                  users = Array(r.dotfiles)
                end

        users.each do |user|
          home = user =~ /root/ ? '/root' : "/home/#{user}"
          ['.bashrc', '.inputrc'].each do |dot|
            file = ::File.join(home, dot)
            f ||= Chef::Resource::CookbookFile.new(file, run_context)
            f.source      dot[1..-1]
            f.cookbook   'garcon'
            f.backup      false
            f.owner       user
            f.group       user
            f.mode        00644
            f.run_action :create
          end
        end
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
  resource: :civilize,
  provider:  Chef::Provider::Civilize
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :centos,
  resource: :civilize,
  provider:  Chef::Provider::Civilize
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :oracle,
  resource: :civilize,
  provider:  Chef::Provider::Civilize
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :redhat,
  resource: :civilize,
  provider:  Chef::Provider::Civilize
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :scientific,
  resource: :civilize,
  provider:  Chef::Provider::Civilize
)
