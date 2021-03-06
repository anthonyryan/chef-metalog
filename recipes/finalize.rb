#
# Author:: anthony ryan <anthony@tentric.com>
# Cookbook Name:: metalog
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

# run pkill again as service was left running previously
execute "service-pkill" do
  Chef::Log.info("Running pkill -9 rsyslog*")
  environment({"PATH" => "/usr/local/bin:/usr/bin:/bin:/usr/sbin:$PATH"})
  command "pkill -9 rsyslog*"
  user 'root'
  ignore_failure true
end
