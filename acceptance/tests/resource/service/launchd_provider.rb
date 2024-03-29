test_name 'Mac OS X launchd Provider Testing'

tag 'audit:high',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

confine :to, {:platform => /osx/}, agents

require 'puppet/acceptance/service_utils'
extend Puppet::Acceptance::ServiceUtils

sloth_daemon_script = <<SCRIPT
#!/usr/bin/env sh
while true; do sleep 1; done
SCRIPT

svc = 'com.puppetlabs.sloth'
launchd_script_path = "/Library/LaunchDaemons/#{svc}.plist"

def launchctl_assert_status(host, service, expect_running)
  on(host, 'launchctl list') do |result|
    if expect_running
      assert_match(/#{service}/, result.stdout, 'Service was not found in launchctl list')
    else
      refute_match(/#{service}/, result.stdout, 'Service was not expected in launchctl list')
    end
  end
end

agents.each do |agent|
  step "Setup on #{agent}"
  sloth_daemon_path = agent.tmpfile("sloth_daemon.sh")
  create_remote_file(agent, sloth_daemon_path, sloth_daemon_script)

  launchd_script = <<SCRIPT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>Label</key>
        <string>#{svc}</string>
        <key>Program</key>
        <string>#{sloth_daemon_path}</string>
        <key>RunAtLoad</key>
        <true/>
</dict>
</plist>
SCRIPT
  create_remote_file(agent, launchd_script_path, launchd_script)

  teardown do
    on agent, puppet_resource('service', 'com.puppetlabs.sloth', 'ensure=stopped', 'enable=true')
    on agent, "rm #{sloth_daemon_path} #{launchd_script_path}"
  end

  step "Verify the service exists on #{agent}"
  assert_service_status_on_host(agent, svc, {:ensure => 'stopped', :enable => 'true'}) do
    launchctl_assert_status(agent, svc, false)
  end

  step "Start the service on #{agent}"
  ensure_service_on_host(agent, svc, {:ensure => 'running'}) do
    launchctl_assert_status(agent, svc, true)
  end

  step "Disable the service on #{agent}"
  ensure_service_on_host(agent, svc, {:enable => 'false'}) do
    launchctl_assert_status(agent, svc, true)
  end

  step "Stop the service on #{agent}"
  ensure_service_on_host(agent, svc, {:ensure => 'stopped'}) do
    launchctl_assert_status(agent, svc, false)
  end

  step "Enable the service on #{agent}"
  ensure_service_on_host(agent, svc, {:enable => 'true'}) do
    launchctl_assert_status(agent, svc, false)
  end

  # switching from stopped to running should output the correct status of the service and not 'absent'
  step "Start the service on #{agent} when service is stopped, and check output" do
    on agent, puppet_resource('service', svc, 'ensure=stopped')
    on agent, puppet_resource('service', svc, 'ensure=running')
    assert_service_status_on_host(agent, svc, {:ensure => 'running'})
  end

  # switching from running to stopped should output the correct status of the service and not 'absent'
  step "Stop the service on #{agent} when service is running, and check output" do
    on agent, puppet_resource('service', svc, 'ensure=running')
    on agent, puppet_resource('service', svc, 'ensure=stopped')
    assert_service_status_on_host(agent, svc, {:ensure => 'stopped'})
  end
end
