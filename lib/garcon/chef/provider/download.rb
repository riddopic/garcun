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
    class Download < Chef::Resource
      include Garcon

      # Chef attributes
      identity_attr :path
      provides      :download
      state_attrs   :checksum, :owner, :group, :mode

      # Actions
      actions        :create, :create_if_missing, :delete, :touch
      default_action :create

      # Attributes
      attribute :path,
        kind_of: String,
        name_attribute: true
      attribute :source,
        kind_of: [String, URI::HTTP],
        callbacks: source_callbacks,
        required: true
      attribute :backup,
        kind_of: [Integer, FalseClass],
        default: 5
      attribute :checksum,
        kind_of: String,
        regex:   /^[0-9a-f]{32}$|^[a-zA-Z0-9]{40,64}$/
      attribute :connections,
        kind_of: Integer,
        default: 8
      attribute :owner,
        kind_of: [String, Integer],
        regex:   Chef::Config[:user_valid_regex]
      attribute :group,
        kind_of: [String, Integer],
        regex:   Chef::Config[:group_valid_regex]
      attribute :mode,
        kind_of: [String, Integer],
        regex:   /^0?\d{3,4}$/
      attribute :check_cert,
        kind_of: [TrueClass, FalseClass],
        default: true
      attribute :header,
        kind_of: String,
        default: nil

      # @!attribute [rw] installed
      #   @return [TrueClass, FalseClass] True if resource exists.
      attr_accessor :exist

      # Determine if the resource exists. This value is set by the provider
      # when the current resource is loaded.
      #
      # @see Dsccsetup#action_create
      #
      # @return [Boolean]
      #
      # @api public
      def exist?
        !!@exist
      end
    end
  end

  class Provider
    class Download < Chef::Provider
      include Chef::Mixin::EnforceOwnershipAndPermissions
      include Chef::Mixin::Checksum
      include Garcon

      def initialize(name, run_context = nil)
        super
        @resource_name = :download
        @provider      = Chef::Provider::Download
        @ready         = AtomicBoolean.new(installed?('aria2c'))
        @lock          = ReadWriteLock.new

        make_ready unless ready?
        poll(300) { ready? }
      end

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

      # Reload the resource state when something changes
      #
      # @return [undefined]
      #
      # @api private
      def load_new_resource_state
        r.exist = @current_resource.exist if r.exist.nil?
      end

      # Load and return the current resource.
      #
      # @return [Chef::Provider::Download]
      #
      # @api private
      def load_current_resource
        @current_resource ||= Chef::Resource::Download.new(r.name)
        @current_resource.path(r.path)

        if ::File.exist?(@current_resource.path)
          @current_resource.checksum(checksum(@current_resource.path))
          if @current_resource.checksum == r.checksum
            @current_resource.exist = true
          else
            @current_resource.exist = false
          end
        else
          @current_resource.exist = false
        end
        @current_resource
      end

      # Default, download the specified source file if it does not exist. If a
      # file already exists (but does not match), use to update that file to
      # match.
      #
      # @return [undefined]
      #
      # @api public
      def action_create
        if @current_resource.exist? && !access_controls.requires_changes?
            Chef::Log.debug "#{r.path} already exists - nothing to do"

        elsif @current_resource.exist? && access_controls.requires_changes?
          converge_by(access_controls.describe_changes) do
            access_controls.set_all
          end
          r.updated_by_last_action(true)

        else
          converge_by "Download #{r.path}" do
            backup unless ::File.symlink?(r.path)
            do_download
          end
          do_acl_changes
          load_resource_attributes_from_file(r)
          r.updated_by_last_action(true)
          load_new_resource_state
          r.exist = true
        end
      end

      alias_method :action_create_if_missing, :action_create

      # Use to delete a file.
      #
      # @return [undefined]
      #
      # @api public
      def action_delete
        if @current_resource.exist?
          converge_by "Delete #{r.path}" do
            backup unless ::File.symlink?(r.path)
            ::File.delete(r.path)
          end
          r.updated_by_last_action(true)
          load_new_resource_state
          r.exist = false
        else
          Chef::Log.debug "#{r.path} does not exists - nothing to do"
        end
      end

      # Use to touch a file. This updates the access (atime) and file
      # modification (mtime) times for a file. (This action may be used with
      # this resource, but is typically only used with the file resource.)
      #
      # @return [undefined]
      #
      # @api public
      def action_touch
        if @current_resource.exist?
          converge_by "Update utime on #{r.path}" do
            time = Time.now
            ::File.utime(time, time, r.path)
          end
          r.updated_by_last_action(true)
          load_new_resource_state
          r.exist = true
        else
          Chef::Log.debug "#{r.path} does not exists - nothing to do"
        end
      end

      # Implementation components *should* follow symlinks when managing access
      # control (e.g., use chmod instead of lchmod even if the path we're
      # managing is a symlink).
      #
      def manage_symlink_access?
        false
      end

      private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

      # Change file ownership and mode.
      #
      # @return [undefined]
      #
      # @api private
      def do_acl_changes
        if access_controls.requires_changes?
          converge_by(access_controls.describe_changes) do
            access_controls.set_all
          end
        end
      end

      # Reads Access Control Settings on a file and writes them out to a
      # resource, attempting to match the style used by the new resource, that
      # is, if users are specified with usernames in new_resource, then the
      # uids from stat will be looked up and usernames will be added to
      # current_resource.
      #
      # @return [undefined]
      #
      # @api private
      def load_resource_attributes_from_file(resource)
        acl_scanner = Chef::ScanAccessControl.new(@new_resource, resource)
        acl_scanner.set_all!
      end

      # Gather options to download file.
      #
      # @return [Array]
      #
      # @api private
      def args(args = [])
        args << "--out=#{::File.basename(r.path)}"
        args << "--dir=#{::File.dirname(r.path)}"
        args << "--checksum=sha-256=#{r.checksum}" if r.checksum
        args << "--header='#{r.header}'" if r.header
        args << "--check-certificate=#{r.check_cert}"
        args << "--file-allocation=falloc"
        args << "--max-connection-per-server=#{r.connections}"
        args << r.source
      end

      # Command line executioner for running aria2.
      #
      # @return [undefined]
      #
      # @api private
      def do_download
        retrier(tries: 10, sleep: ->(n) { 4**n }) { installed?('aria2') }
        cmd = [which('aria2c')] << args.flatten.join(' ')
        Chef::Log.info shell_out!(cmd.flatten.join(' ')).stdout
      end

      # Backup the file before overwriting or replacing it unless
      # `new_resource.backup` is `false`
      #
      # @return [undefined]
      #
      # @api private
      def backup(file = nil)
        Chef::Util::Backup.new(new_resource, file).backup!
      end

      def ready?
        @ready.value
      end

      def make_ready
        return true if @ready.value == true
        @lock.with_write_lock { handle_prerequisites }
        installed?('aria2c') ? @ready.make_true : @ready.make_false
      end

      def handle_prerequisites
        if node.platform_family == 'rhel'
          package 'gnutls', :install
          yumrepo(:create)
        end
        package 'aria2', :install
        wipe_repo if node.platform_family == 'rhel'
      end

      def package(name, action = :nothing)
        p = Chef::Resource::Package.new(name, run_context)
        p.retries     30
        p.retry_delay 10
        p.run_action  action
      end

      def yumrepo(action = :nothing)
        y = Chef::Resource::YumRepository.new('garcon', run_context)
        y.mirrorlist Repos.mirrorlist
        y.gpgkey     Repos.gpgkey
        y.gpgcheck   true
        y.run_action action
      end

      def wipe_repo
        # Seems Chef::Resource::YumRepository action :delete is foobared, so
        # nuke the repo another way.
        Future.execute do
          ::File.unlink('/etc/yum.repos.d/garcon.repo')
          shell_out!('yum clean all && yum -q makecache')
          Chef::Provider::Package::Yum::YumCache.instance.reload
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
  resource: :download,
  provider:  Chef::Provider::Download
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :centos,
  resource: :download,
  provider:  Chef::Provider::Download
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :oracle,
  resource: :download,
  provider:  Chef::Provider::Download
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :redhat,
  resource: :download,
  provider:  Chef::Provider::Download
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :scientific,
  resource: :download,
  provider:  Chef::Provider::Download
)
