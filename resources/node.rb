#
# Cookbook:: windows_failover_cluster
# Resource:: node
#
# Copyright:: 2018, Stephen Hoekstra
# Copyright:: 2018, Schuberg Philis
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

require 'ipaddress'

property :cluster_name, String, name_property: true
property :cluster_ip, String, required: true, callbacks: { 'must be a valid IP address' => ->(ip) { IPAddress.valid?(ip) } }
property :install_tools, [TrueClass, FalseClass], default: true
property :fs_witness, String
property :quorum_disk, String
property :run_as_user, String, required: true, default: lazy { node['windows_failover_cluster']['run_as_user'] }, callbacks: { 'must not be nil' => ->(p) { !p.nil? } }
property :run_as_password, String, required: true, default: lazy { node['windows_failover_cluster']['run_as_password'] }, callbacks: { 'must not be nil' => ->(p) { !p.nil? } }

default_action :create

action_class do
  def cluster_contain_node?
    powershell_out_with_options('(Get-ClusterNode).Name').stdout.split(/\r\n/).include? node['hostname']
  end

  def cluster_exist?(cluster_name)
    powershell_out_with_options("(Get-Cluster #{cluster_name}).name").stdout.chomp == cluster_name
  end

  def cluster_quorum_disk?(disk_name)
    powershell_out_with_options('(Get-ClusterQuorum).QuorumResource.Name').stdout.chomp == disk_name
  end

  def cluster_quorum_fs_witness?
    powershell_out_with_options('(Get-ClusterResource "File Share Witness")').stdout.chomp =~ /File Share Witness/
  end

  def cluster_share_path?(share_path)
    powershell_out_with_options('(Get-ClusterResource "File Share Witness" | Get-ClusterParameter SharePath).Value').stdout.chomp == share_path
  end

  def set_quorum_node_majority
    powershell_out_with_options('Set-ClusterQuorum -NodeMajority')
  end

  def create_new_fs_witness
    powershell_out_with_options!("Set-ClusterQuorum -NodeAndFileShareMajority \'#{new_resource.fs_witness}\'")
  end

  def install_windows_feature(features)
    windows_feature [features].flatten do
      install_method :windows_feature_powershell
      action :nothing
    end.run_action(:install)
  end

  def powershell_out_options
    { user: new_resource.run_as_user, password: new_resource.run_as_password, domain: node['domain'] }
  end

  def powershell_out_with_options(script)
    powershell_out(script, powershell_out_options)
  end

  def powershell_out_with_options!(script)
    powershell_out!(script, powershell_out_options)
  end
end

action :create do
  # Install Failover Clustering feature and PowerShell module
  windows_features = %w(Failover-Clustering RSAT-Clustering-Powershell)
  windows_features << 'RSAT-Clustering-Mgmt' if new_resource.install_tools
  install_windows_feature(windows_features)

  # Create the cluster
  powershell_out_with_options!("New-Cluster -Name #{new_resource.cluster_name} -Node #{node['hostname']} -StaticAddress #{new_resource.cluster_ip} -Force") unless cluster_exist?(new_resource.cluster_name)
  # Add any available disks to the cluster
  powershell_out_with_options('Get-ClusterAvailableDisk | Add-ClusterDisk')

  if new_resource.quorum_disk && new_resource.fs_witness
    Chef::Log.fatal('You provided both quorum_disk and fs_witness, only one is supported!')
  end

  # Configure quorum using node & disk majority
  if new_resource.quorum_disk
    powershell_out_with_options!("Set-ClusterQuorum -NodeAndDiskMajority \'#{new_resource.quorum_disk}\'") unless cluster_quorum_disk?(new_resource.quorum_disk)
  end

  # Configure quorum using node & file share majority
  if new_resource.fs_witness
    if cluster_quorum_fs_witness?
      if cluster_share_path?(new_resource.fs_witness)
        # Nothing to do if cluster is configured to use a file share witness and using our defined witness path
        return
      else
        # Update witness path if a path is configured but not what we defined
        log 'Resetting File Share Witness'
        set_quorum_node_majority
        create_new_fs_witness
      end
    else
      # If we got here then a file share witness is not configured so we should configure it
      log 'Create new FS witness'
      create_new_fs_witness
    end
  end
end

action :join do
  # Install Failover Clustering feature and PowerShell module
  windows_features = %w(Failover-Clustering RSAT-Clustering-Powershell)
  windows_features << 'RSAT-Clustering-Mgmt' if new_resource.install_tools
  install_windows_feature(windows_features)

  # Join the cluster
  powershell_out_with_options!("Add-ClusterNode -Cluster #{new_resource.cluster_name} -Name #{node['hostname']}") if cluster_exist?(new_resource.cluster_name) && !cluster_contain_node?
end
