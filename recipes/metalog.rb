#
# Author:: anthony ryan <anthony@tentric.com>
# Cookbook Name:: server
#
# Copyright 2014, Anthony Ryan
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

# default dependent packages
if platform?("ubuntu")
  metadepend = ['build-essential','libgettextpo-dev','libpcre3-dev','pkg-config']
else
  metadepend = ['build-essential','gettext','libpcre3-dev','pkg-config']
end

# run package dependencies
metadepend.each do |metainstall|
  package metainstall do
    action :install
    retries 2
    retry_delay 5
    ignore_failure true
  end
end

# stop any prevously installed loging facility and remove it from auto run
service "rsyslog" do
  action :stop
  ignore_failure true
  only_if do
    File.exists?("/etc/init.d/rsyslog")
  end
end

execute "rsyslog-init-remove" do
  environment({"PATH" => "/usr/local/bin:/usr/bin:/bin:/usr/sbin:$PATH"})
  command "update-rc.d -f rsyslog remove"
  ignore_failure true
  only_if do
    File.exists?("/etc/init.d/rsyslog")
  end
end

execute "service-pkill" do
  Chef::Log.info("Running pkill -9 rsyslog*")
  environment({"PATH" => "/usr/local/bin:/usr/bin:/bin:/usr/sbin:$PATH"})
  command "pkill -9 rsyslog*"
  user 'root'
  ignore_failure true
end

# remove specific packages that are installed by default
if platform?("ubuntu")
  package "ubuntu-minimal" do
    action :remove
    ignore_failure true
  end
  package "rsyslog" do
    action :remove
    ignore_failure true
  end
elsif platform?('debian',"amazon","redhat","centos","fedora")
  package "rsyslog" do
    action :remove
    ignore_failure true
  end
end

# install metalog from source
metalog_src_url = "#{node['server']['metalogsrc_url']}"
metalog_tar = "metalog-#{node['server']['metalogversion']}.tar.xz"

# download the file
remote_file "/tmp/#{metalog_tar}" do
  source metalog_src_url
  mode 0644
  action :create_if_missing
  ignore_failure true
end

# untar it
execute "tar --no-same-owner -xJf #{metalog_tar}" do
  cwd "/tmp"
  creates "/tmp/metalog-#{node['server']['metalogversion']}"
end

# run configure
execute "metalog configure" do
  environment({"PATH" => "/usr/local/bin:/usr/bin:/bin:/usr/sbin:$PATH"})
  command "./configure --prefix=/usr"
  cwd "/tmp/metalog-#{node['server']['metalogversion']}"
  creates "/tmp/metalog-#{node['server']['metalogversion']}/src/metalog"
  ignore_failure true
end

# run make install
execute "metalog make install" do
  environment({"PATH" => "/usr/local/bin:/usr/bin:/bin:/usr/sbin:$PATH"})
  command "make install"
  cwd "/tmp/metalog-#{node['server']['metalogversion']}"
  creates "/usr/sbin/metalog"
  ignore_failure true
end

# copy our default template
template 'metalog.conf' do
  path "/etc/metalog.conf"
  source 'metalog_conf.erb'
  owner 'root'
  group 'root'
  mode 0644
  ignore_failure true
end

# copy our default settings
template 'metalog defaults' do
  case node[:platform]
  when 'centos','redhat','fedora','amazon','debian'
    path "/etc/conf.d/metalog"
  when 'ubuntu'
    path "/etc/default/metalog"
  end
  source 'metalog_default.erb'
  owner 'root'
  group 'root'
  mode 0644
  ignore_failure true
end

# copy our init script
template 'metalog init' do
  path "/etc/init.d/metalog"
  source 'metalog_init.erb'
  owner 'root'
  group 'root'
  mode 0755
  ignore_failure true
end

# turn on metalog for auto start
execute "metalog on" do
  user 'root'
  environment({"PATH" => "/usr/local/bin:/usr/bin:/bin:/usr/sbin:$PATH"})
  command "update-rc.d metalog defaults"
  ignore_failure true
end

# delete the default metalog config
file "/usr/etc/metalog.conf" do
  action :delete
  backup false
  only_if do
    File.exists?("/usr/etc/metalog.conf")
  end
end

# clean up old logs
bash "metalog-cleanup" do
  user 'root'
  cwd "/tmp"
  code <<-EOH
    PATH="/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin:$PATH"
    mkdir /var/log/logs.old
    mv /var/log/*.log /var/log/logs.old
    mv /var/log/dmesg* /var/log/logs.old
    mv /var/log/syslog* /var/log/logs.old
  EOH
  ignore_failure true
end 

# start the metalog service
service "metalog" do
  action :start
  ignore_failure true
end
