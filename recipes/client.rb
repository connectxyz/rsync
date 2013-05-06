if Chef::Config[:solo]
  Chef::Log.warn("This recipe uses search. Chef Solo does not support search.")
end

package "rsync"

#typeofserver = search(:node, "name:#{node.name}").map { |n| n.run_list.select { |value| value == 'role[AppSrv]' || value == 'role[WebMainSrv]' }}.first.first

server = search(:node, "roles:ManagementServer").map {|n| n["network"]["interfaces"][node['network_interfaces']['private']]["addresses"].select { |address, data| data["family"] == "inet" }}
server = server.first.keys.first unless server.empty? == true


node['cxyz']['rsync']['client']['vhosts'].each do |vhost|
  print vhost
  if vhost['vhost'] == nil || vhost['vhost'] == ""
    next
  end
  cron "sync#{vhost['vhost']}" do
    action :delete
    minute "0"
    command "rsync -aPv --delete rsync://pub@" + server + "/#{vhost['vhost']} #{vhost['destination'] != nil && vhost['destination'] != "" ? vhost['destination'] : node['cxyz']['rsync']['server']['src_root'] + '/' + vhost['vhost']}"
  end
end
template "/root/force_rsync_update.sh" do
  source "force_rsync_update.sh.erb"
  owner "root"
  mode 0700
  variables(
      :server => server)
end
execute "/root/force_rsync_update.sh" do
  command "bash /root/force_rsync_update.sh"
  action :run
end


if node.roles[0] == "AppSrv" || node.roles[0] == "WebMainSrv"

  cron "SyncHTTPLogs" do
    action :create
    minute 0
    command "rsync -r -a -v /var/log/nginx rsync://#{node['cxyz']['addressess']['chef_server']}/#{node['hostname']}"
  end
end
