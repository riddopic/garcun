
# Garcon

A collection of methods helpful in writing complex cookbooks that are
impossible to comprehend.

Hipster, hoodie ninja cool awesome.

## Requirements

Before trying to use the cookbook make sure you have a supported system. If you
are attempting to use the cookbook in a standalone manner to do testing and
development you will need a functioning Chef/Ruby environment, with the
following:

* Chef 11 or higher
* Ruby 1.9 (preferably from the Chef full-stack installer)

#### Chef

Chef Server version 11+ and Chef Client version 11.16.2+ and Ohai 7+ are
required. Clients older that 11.16.2 do not work.

#### Platforms

This cookbook uses Test Kitchen to do cross-platform convergence and post-
convergence tests. The tested platforms are considered supported. This cookbook
may work on other platforms or platform versions with or without modification.

* Red Hat Enterprise Linux (RHEL) Server 6 x86_64 (RedHat, CentOS, Oracle etc.)

#### Cookbooks

The following cookbooks are required as noted (check the metadata.rb file for
the specific version numbers):

* [chef_handler](https://supermarket.getchef.com/cookbooks/chef_handler) -
  Distribute and enable Chef Exception and Report handlers.
* [yum](https://supermarket.getchef.com/cookbooks/yum) - The Yum cookbook
  exposes the yum_repository resources that allows a user to both control global
  behavior and make individual Yum repositories available for use.

### Development Requirements

In order to develop and test this Cookbook, you will need a handful of gems
installed.

* [Chef][]
* [Berkshelf][]
* [Test Kitchen][]
* [ChefSpec][]
* [Foodcritic][]

It is recommended for you to use the Chef Developer Kit (ChefDK). You can get
the [latest release of ChefDK from the downloads page][ChefDK].

On Mac OS X, you can also use [homebrew-cask](http://caskroom.io) to install
ChefDK.

Once you install the package, the `chef-client` suite, `berks`, `kitchen`, and
this application (`chef`) will be symlinked into your system bin directory,
ready to use.

You should then set your Ruby/Chef development environment to use ChefDK. You
can do so by initializing your shell with ChefDK's environment.

    eval "$(chef shell-init SHELL_NAME)"

where `SHELL_NAME` is the name of your shell, (bash or zsh). This modifies your
`PATH` and `GEM_*` environment variables to include ChefDK's paths (run without
the `eval` to see the generated code). Now your default `ruby` and associated
tools will be the ones from ChefDK:

    which ruby
    # => /opt/chefdk/embedded/bin/ruby

You will also need Vagrant 1.6+ installed and a Virtualization provider such as
VirtualBox or VMware.

## Usage

Include the garcon recipe in your run list:

    include_recipe 'garcon::default'

## Attributes

Attributes are under the `garcon` namespace, the following attributes affect
the behavior of how the cookbook performs an installation, or are used in the
recipes for various settings that require flexibility.

### General attributes:

General attributes can be found in the `default.rb` file.

* `node[:garcon][:repo][:gpgcheck]`: [TrueClass, FalseClass] This tells yum
  whether or not it should perform a GPG signature check on packages. When this
  is set in the [main] section it sets the default for all repositories. The
  default is `true`.
* `node[:garcon][:repo][:gpgkey]`: [String, URI::HTTP] A URL pointing to the
  ASCII-armored GPG key file for the repository. This option is used if yum
  needs a public key to verify a package and the required key hasn't been
  imported into the RPM database. If this option is set, yum will automatically
  import the key from the specified URL.
* `node[:garcon][:repo][:mirrorlist]`: [String, URI::HTTP] Specifies a URL to a
  file containing a list of baseurls. This can be used instead of or with the
  baseurl option. Substitution variables, described below, can be used with this
  option. As a special hack is the mirrorlist URL contains the word "metalink"
  then the value of mirrorlist is copied to metalink (if metalink is not set).

## Providers

This cookbook includes HWRPs for managing:

  * `Chef::Provider::Download`: The `download` resource is a lightweight multi-
    protocol and multi-source download utility. It supports HTTP/HTTPS, FTP,
    BitTorrent and Metalink.
  * `Chef::Provider::ZipFile`: Provides a pure-ruby implementation for managing
    zip files, adapted from the `windows_zipfile` resource.
  * `Chef::Provider::Thread`:

### download

Use the `download` resource to transfer files from a remote location, similar
to `remote_file` but provides multithreaded torrent and http downloader
utilizing [Aria2](http://aria2.sourceforge.net). This can  be up to four times
faster than the standard `remote_file` resource, useful for large file
transfers.

#### Syntax

The syntax for using the `download` resource in a recipe is as follows:

    download 'name' do
      attribute 'value' # see attributes section below
      ...
      action :action # see actions section below
    end

Where:

  * `download` tells the chef-client to use the `Chef::Provider::Download`
    provider during the chef-client run;
  * `name` is the name of the resource block; when the `path` attribute is not
    specified as part of a recipe, `name` is also the path to the remote file;
  * `attribute` is zero (or more) of the attributes that are available for this
    resource;
  * `:action` identifies which steps the chef-client will take to bring the node
    into the desired state.

For example:

    download ::File.join(Chef::Config[:file_cache_path], 'file.tar.gz') do
      source 'http://www.example.org/file.tar.gz'
    end

#### Actions

  * `:create`: Default. Use to create a file. If a file already exists (but does
    not match), use to update that file to match.
  * `:create_if_missing`: Use to create a file only if the file does not exist.
    (When the file exists, nothing happens.)
  * `:delete`: Use to delete a file.
  * `:touch`: Use to touch a file. This updates the access (atime) and file
    modification (mtime) times for a file. (This action may be used with this
    resource, but is typically only used with the file resource.)

#### Attribute Parameters

  * `backup`: The number of backups to be kept. Set to false to prevent backups
     from being kept. Default value: 5.
  * `checksum`: Optional, allows for conditional gets. The SHA-256 checksum of
    the file. Use to prevent the `download` resource from re-downloading a file.
    When the local file matches the checksum, it will not be downloaded.
  * `connections`: Download a file using N connections. If more than N URIs are
    given, first N URIs are used and remaining URIs are used for backup. If less
    than N URIs are given, those URIs are used more than once so that N
    connections total are made simultaneously. Default: 5.
  * `group`: A string or ID that identifies the group owner by group name. If
    this value is not specified, existing groups will remain unchanged and new
    group assignments will use the default POSIX group (if available).
  * `max_connections`: The maximum number of connections to one server for each
    download. Default: 5.
  * `mode`: A quoted string that defines the octal mode for a file. If mode is
    not specified and if the file already exists, the existing mode on the file
    is used. If mode is not specified, the file does not exist, and the :create
    action is specified, the chef-client will assume a mask value of "0777" and
    then apply the umask for the system on which the file will be created to the
    mask value. For example, if the umask on a system is "022", the chef-client
    would use the default value of "0755".
  * `owner`: A string or ID that identifies the group owner by user name. If
    this value is not specified, existing owners will remain unchanged and new
    owner assignments will use the current user (when necessary).
  * `path`: The full path to the file, including the file name and its
    extension. Default value: the name of the resource block.
  * `source`: name attribute. The location (URI) of the source file. This value
    may also specify HTTP (http://), FTP (ftp://), or local (file://) source
    file locations.

#### Examples

The following examples demonstrate various approaches for using resources in
recipes. If you want to see examples of how Chef uses resources in recipes, take
a closer look at the cookbooks that Chef authors and maintains: https://
github.com/opscode-cookbooks.

##### Transfer a file from a URL

    download '/tmp/testfile' do
      source 'http://www.example.com/tempfiles/testfile'
      mode 00644
      checksum '3a7dac00b1' # A SHA256 (or portion thereof) of the file.
    end

##### Transfer a file only when the source has changed

    download '/tmp/file.png' do
      source 'http://example.com/file.png'
      action :nothing
    end

    http_request 'HEAD //example.com/file.png' do
      message ''
      url '//example.com/file.png'
      action :head
      if ::File.exists?('/tmp/file.png')
        header "If-Modified-Since" => ::File.mtime("/tmp/file.png").httpdate
      end
      notifies :create, 'download[http://example.com/file.png]', :immediately
    end

##### Install a file from a remote location using bash

The following is an example of how to install the foo123 module for Nginx. This
module adds shell-style functionality to an Nginx configuration file and does
the following:

  * Declares three variables;
  * Gets the Nginx file from a remote location;
  * Installs the file to the path specified by the `src_path` variable.

The following code sample is similar to the `upload_progress_module` recipe in
the [nginx](https://github.com/opscode-cookbooks/nginx) cookbook.

    src_file = "foo123-nginx-module-v#{node[:nginx][:foo123][:version]}.tar.gz"
    src_path = ::File.join(Chef::Config[:file_cache_path], src_file)
    extract_path = ::File.join(Chef::Config[:file_cache_path],
      'nginx_foo123_module', node[:nginx][:foo123][:checksum]
    )

    download src_path do
      source node[:nginx][:foo123][:url]
      checksum node[:nginx][:foo123][:checksum]
      owner 'root'
      group 'root'
      mode 00644
    end

    bash 'extract module' do
      cwm ::File.dirname(src_path)
      code <<-CODE
        mkdir -p #{extract_path}
        tar xzf #{src_file} -C #{extract_path}
        mv #{extract_path}/*/* #{extract_path}/
      CODE
      not_if { ::File.exist?(extract_path) }
    end

### zip_file

This resource provides a pure-ruby implementation for managing zip files. Be
sure to use the not_if or only_if meta parameters to guard the resource for
idempotence or action will be taken every Chef run.

#### Syntax

The syntax for using the `zip_file` resource in a recipe is as follows:

    zip_file 'name' do
      attribute 'value' # see attributes section below
      ...
      action :action # see actions section below
    end

Where:

  * `zip_file` tells the chef-client to use the `Chef::Provider::ZipFile`
    provider during the chef-client run;
  * `name` is the name of the resource block; when the `path` attribute is not
    specified as part of a recipe, `name` is also the path where files will be
    (un)zipped to;
  * `attribute` is zero (or more) of the attributes that are available for this
    resource;
  * `:action` identifies which steps the chef-client will take to bring the node
    into the desired state.

For example:

    zip_file '/tmp/path' do
      source 'http://www.example.org/file.tar.gz'
    end

#### Actions

  * `:unzip`: unzip a compressed file.
  * `:zip`: zip a directory (recursively).

#### Attribute Parameters

  * `checksum`: for :unzip, useful if source is remote, if the local file
    matches the SHA-256 checksum, Chef will not download it.
  * `group`: A string or ID that identifies the group owner by group name. If
    this value is not specified, existing groups will remain unchanged and new
    group assignments will use the default POSIX group (if available).
  * `mode`: A quoted string that defines the octal mode for a file. If mode is
    not specified and if the file already exists, the existing mode on the file
    is used. If mode is not specified, the file does not exist, and the :create
    action is specified, the chef-client will assume a mask value of "0777" and
    then apply the umask for the system on which the file will be created to the
    mask value. For example, if the umask on a system is "022", the chef-client
    would use the default value of "0755".
  * `overwrite`: force an overwrite of the files if they already exist.
  * `owner`: A string or ID that identifies the group owner by user name. If
    this value is not specified, existing owners will remain unchanged and new
    owner assignments will use the current user (when necessary).
  * `path`: name attribute. The path where files will be (un)zipped to.
  * `remove_after`: If the zip file should be removed once it has been unzipped.
    Default is false.
  * `source`: The source of the zip file (either a URI or local
    path) for :unzip, or directory to be zipped for :zip.

#### Examples

The following examples demonstrate various approaches for using resources in
recipes. If you want to see examples of how Chef uses resources in recipes, take
a closer look at the cookbooks that Chef authors and maintains: https://
github.com/opscode-cookbooks.

##### Unzip a remote zip file locally

    zip_file '/opt/app' do
      source 'http://example.com/app.zip'
      owner 'app_user'
      group 'app_group'
      action :unzip
      not_if { ::File.exist?('/opt/app/bin/startup.sh') }
    end

##### Unzip a local zipfile

    zip_file '/home/foo' do
      source '/tmp/something.zip'
      action :unzip
    end

##### Create a local zipfile

    zip_file '/tmp/foo.zip' do
      source '/home/foo'
      action :zip
    end

## Testing

Ensure you have all the required prerequisite listed in the Development
Requirements section. You should have a working Vagrant installation with either VirtualBox or VMware installed. From the parent directory of this cookbook begin by running bundler to ensure you have all the required Gems:

    bundle install

A ruby environment with Bundler installed is a prerequisite for using the testing harness shipped with this cookbook. At the time of this writing, it works with Ruby 2.1.2 and Bundler 1.6.2. All programs involved, with the exception of Vagrant and VirtualBox, can be installed by cd'ing into the parent directory of this cookbook and running 'bundle install'.

#### Vagrant and VirtualBox

The installation of Vagrant and VirtualBox is extremely complex and involved. Please be prepared to spend some time at your computer:

If you have not yet installed Homebrew do so now:

    ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"

Next install Homebrew Cask:

    brew tap phinze/homebrew-cask && brew install brew-cask

Then, to get Vagrant installed run this command:

    brew cask install vagrant

Finally install VirtualBox:

    brew cask install virtualbox

You will also need to get the Berkshelf and Omnibus plugins for Vagrant:

    vagrant plugin install vagrant-berkshelf
    vagrant plugin install vagrant-omnibus

Try doing that on Windows.

#### Rakefile

The Rakefile ships with a number of tasks, each of which can be ran individually, or in groups. Typing `rake` by itself will perform style checks with [Rubocop](https://github.com/bbatsov/rubocop) and [Foodcritic](http://www.foodcritic.io), [Chefspec](http://sethvargo.github.io/chefspec/) with rspec, and integration with [Test Kitchen](http://kitchen.ci) using the Vagrant driver by default. Alternatively, integration tests can be ran with Test Kitchen cloud drivers for EC2 are provided.

    $ rake -T
    rake all                         # Run all tasks
    rake chefspec                    # Run RSpec code examples
    rake doc                         # Build documentation
    rake foodcritic                  # Lint Chef cookbooks
    rake kitchen:all                 # Run all test instances
    rake kitchen:apps-dir-centos-65  # Run apps-dir-centos-65 test instance
    rake kitchen:default-centos-65   # Run default-centos-65 test instance
    rake kitchen:ihs-centos-65       # Run ihs-centos-65 test instance
    rake kitchen:was-centos-65       # Run was-centos-65 test instance
    rake kitchen:wps-centos-65       # Run wps-centos-65 test instance
    rake readme                      # Generate README.md from _README.md.erb
    rake rubocop                     # Run RuboCop
    rake rubocop:auto_correct        # Auto-correct RuboCop offenses
    rake test                        # Run all tests except `kitchen` / Run
                                     # kitchen integration tests
    rake yard                        # Generate YARD Documentation

#### Style Testing

Ruby style tests can be performed by Rubocop by issuing either the bundled binary or with the Rake task:

    $ bundle exec rubocop
        or
    $ rake style:ruby

Chef style tests can be performed with Foodcritic by issuing either:

    $ bundle exec foodcritic
        or
    $ rake style:chef

### Testing

This cookbook uses Test Kitchen to verify functionality.

1. Install [ChefDK](http://downloads.getchef.com/chef-dk/)
2. Activate ChefDK's copy of ruby: `eval "$(chef shell-init bash)"`
3. `bundle install`
4. `bundle exec kitchen test kitchen:default-centos-65`

#### Spec Testing

Unit testing is done by running Rspec examples. Rspec will test any libraries, then test recipes using ChefSpec. This works by compiling a recipe (but not converging it), and allowing the user to make assertions about the resource_collection.

#### Integration Testing

Integration testing is performed by Test Kitchen. Test Kitchen will use either the Vagrant driver or EC2 cloud driver to instantiate machines and apply cookbooks. After a successful converge, tests are uploaded and ran out of band of Chef. Tests are be designed to
ensure that a recipe has accomplished its goal.

#### Integration Testing using Vagrant

Integration tests can be performed on a local workstation using Virtualbox or VMWare. Detailed instructions for setting this up can be found at the [Bento](https://github.com/opscode/bento) project web site. Integration tests using Vagrant can be performed with either:

    $ bundle exec kitchen test
        or
    $ rake integration:vagrant

#### Integration Testing using EC2 Cloud provider

Integration tests can be performed on an EC2 providers using Test Kitchen plugins. This cookbook references environmental variables present in the shell that `kitchen test` is ran from. These must contain authentication tokens for driving APIs, as well as the paths to ssh private keys needed for Test Kitchen log into them after they've been created.

Examples of environment variables being set in `~/.bash_profile`:

    # aws
    export AWS_ACCESS_KEY_ID='your_bits_here'
    export AWS_SECRET_ACCESS_KEY='your_bits_here'
    export AWS_KEYPAIR_NAME='your_bits_here'

Integration tests using cloud drivers can be performed with either

    $ bundle exec kitchen test
        or
    $ rake integration:cloud

### Guard

Guard tasks have been separated into the following groups:

  * `doc`
  * `lint`
  * `unit`
  * `integration`

By default, Guard will generate documentation, lint, and run unit tests.
The integration group must be selected manually with `guard -g integration`.

## Contributing

Please see the [CONTRIBUTING.md](CONTRIBUTING.md).

## License and Authors

Author:: Stefano Harding <riddopic@gmail.com>

Copyright:: 2014-2015, Stefano Harding

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

- - -

[Berkshelf]: http://berkshelf.com "Berkshelf"
[Chef]: https://www.getchef.com "Chef"
[ChefDK]: https://www.getchef.com/downloads/chef-dk "Chef Development Kit"
[Chef Documentation]: http://docs.opscode.com "Chef Documentation"
[ChefSpec]: http://chefspec.org "ChefSpec"
[Foodcritic]: http://foodcritic.io "Foodcritic"
[Learn Chef]: http://learn.getchef.com "Learn Chef"
[Test Kitchen]: http://kitchen.ci "Test Kitchen"
