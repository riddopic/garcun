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
      attribute :local,
        kind_of: [String],
        default: 'en_US.UTF-8'
      attribute :iptables,
        kind_of: [TrueClass, FalseClass],
        default: lazy { node[:garcon][:civilize][:iptables] }
      attribute :selinux,
        kind_of: [TrueClass, FalseClass],
        default: lazy { node[:garcon][:civilize][:selinux] }
      attribute :dotfiles,
        kind_of: [TrueClass, FalseClass, String, Array],
        default: lazy { node[:garcon][:civilize][:dotfiles] }
      attribute :ruby,
        kind_of: [TrueClass, FalseClass],
        default: lazy { node[:garcon][:civilize][:ruby] }
      attribute :docker,
        kind_of: Array,
        default: lazy { node[:garcon][:civilize][:docker] }
      attribute :rhel_svcs,
        kind_of: Array,
        default: lazy { node[:garcon][:civilize][:rhel_svcs] }
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
        civilize_platform
        civilize_locale
        civilize_docker   if docker? && r.docker
        rhel_services     if r.rhel_svcs
        iptables          if !docker? && r.iptables
        selinux           if selinux? && r.selinux
        ps1prompt
        dotfiles        if r.dotfiles
      end

      private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

      def omnibus_updater
        node.default[:omnibus_updater][:restart_chef_service] = true
        node.default[:omnibus_updater][:force_latest]         = false
      end

      def locale
        case node[:platform_family]
        when 'debian'
          e = Chef::Resource::Execute.new('Set locale', run_context)
          e.command "/usr/sbin/update-locale LANG=#{r.local}"
          e.not_if { docker? }
          e.action :run
        when 'rhel'
          t ||= Chef::Resource::Template.new('/etc/sysconfig/i18n', run_context)
          t.cookbook   'garcon'
          t.owner      'root'
          t.group      'root'
          t.mode        00644
          t.variables   local: r.local
          e.not_if    { docker? }
          t.run_action :create
        end
      end

      def tattoo!(action)
        include_recipe 'motd-tail'
        m = Chef::Resource::Template.new('/etc/motd.tail', run_context)
        m.template_source 'motd.erb'
        m.cookbook 'garcon'
        m.action action
      end

      def chef_dot_io_repo(action)
        r = Chef::Resource::PackagecloudRepo.new('/chef/current', run_context)
        r.type   value_for_platform_family debian: 'deb', rhel: 'rpm'
        r.action action
      end

      def civilize_platform
        case node[:platform]
        when 'debian'
          run_context.include_recipe 'apt::default'

        when 'fedora'
          run_context.include_recipe 'yum-fedora::base'

        when 'centos'
          run_context.include_recipe 'yum-epel::base'
          run_context.include_recipe 'yum-centos::base'

        when 'amazon'
          run_context.include_recipe 'yum-epel::base'
          run_context.include_recipe 'yum-amazon::base'
        end
      end

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
