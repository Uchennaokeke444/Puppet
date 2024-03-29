test_name "ticket 1073: common package name in two different providers should be allowed" do

  confine :to, {:platform => /(?:centos|el-|fedora)/}, agents
  # Skipping tests if facter finds this is an ec2 host, PUP-7774
  agents.each do |agent|
    skip_test('Skipping EC2 Hosts') if fact_on(agent, 'ec2_metadata')
  end

  # Upgrade the AlmaLinux release package for newer keys until our image is updated (RE-16096)
  agents.each do |agent|
    on(agent, 'dnf -y upgrade almalinux-release') if fact_on(agent, 'os.name') == 'AlmaLinux'
  end

  tag 'audit:high',
      'audit:acceptance' # Uses a provider that depends on AIO packaging

  require 'puppet/acceptance/rpm_util'
  extend Puppet::Acceptance::RpmUtils
  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::CommandUtils

  rpm_options = {:pkg => 'guid', :version => '1.0'}

  teardown do
    step "cleanup"
    agents.each do |agent|
      clean_rpm agent, rpm_options
    end
  end

  step "Verify gem and ruby-devel on fedora-22 and above if not aio" do
    if @options[:type] != 'aio' then
      agents.each do |agent|
        if agent[:platform] =~ /fedora-2[2-9]/ then
          unless check_for_package agent, 'rubygems'
            install_package agent, 'rubygems'
          end
          unless check_for_package agent, 'ruby-devel'
            install_package agent, 'ruby-devel'
          end
        end
      end
    end
  end

  def gem_provider
    if @options[:type] == 'aio'
      'puppet_gem'
    else
      'gem'
    end
  end

  def verify_state(hosts, pkg, state, match)
    hosts.each do |agent|
      cmd = rpm_provider(agent)
      # Note yum lists packages as <name>.<arch>
      on(agent, "#{cmd} list installed") do |result|
        method(match).call(/^#{pkg}\./, result.stdout)
      end

      on(agent, "#{gem_command(agent, @options[:type])} list --local") do |result|
        method(match).call(/^#{pkg} /, result.stdout)
      end
    end
  end

  def verify_present(hosts, pkg)
    verify_state(hosts, pkg, '(?!purged|absent)[^\']+', :assert_match)
  end

  def verify_absent(hosts, pkg)
    verify_state(hosts, pkg, '(?:purged|absent)', :refute_match)
  end

  # Setup repo and package
  agents.each do |agent|
    clean_rpm agent, rpm_options
    setup_rpm agent, rpm_options
    send_rpm agent, rpm_options
  end

  verify_absent agents, 'guid'

  # Test error trying to install duplicate packages
  collide1_manifest = <<-MANIFEST
    package {'guid': ensure => installed}
    package {'other-guid': name => 'guid', ensure => present}
  MANIFEST

  apply_manifest_on(agents, collide1_manifest, :acceptable_exit_codes => [1]) do |result|
    assert_match(/Error while evaluating a Resource Statement, Cannot alias Package\[other-guid\] to \[nil, "guid", nil\]/, "#{result.host}: #{result.stderr}")
  end

  verify_absent agents, 'guid'

  gem_source = if ENV['GEM_SOURCE'] then "source => '#{ENV['GEM_SOURCE']}'," else '' end
  collide2_manifest = <<-MANIFEST
    package {'guid': ensure => '0.1.0', provider => #{gem_provider}, #{gem_source}}
    package {'other-guid': name => 'guid', ensure => installed, provider => #{gem_provider}, #{gem_source}}
  MANIFEST

  apply_manifest_on(agents, collide2_manifest, :acceptable_exit_codes => [1]) do |result|
    assert_match(/Error while evaluating a Resource Statement, Cannot alias Package\[other-guid\] to \[nil, "guid", "#{gem_provider}"\]/, "#{result.host}: #{result.stderr}")
  end

  verify_absent agents, 'guid'

  # Test successful parallel installation
  install_manifest = <<-MANIFEST
    package {'guid': ensure => installed}

    package {'gem-guid':
      provider => #{gem_provider},
      name => 'guid',
      ensure => installed,
      #{gem_source}
    }
  MANIFEST

  apply_manifest_on(agents, install_manifest) do |result|
    assert_match('Package[guid]/ensure: created', "#{result.host}: #{result.stdout}")
    assert_match('Package[gem-guid]/ensure: created', "#{result.host}: #{result.stdout}")
  end

  verify_present agents, 'guid'

  # Test removal
  remove_manifest = <<-MANIFEST
    package {'gem-guid':
      provider => #{gem_provider},
      name => 'guid',
      ensure => absent,
      #{gem_source}
    }

    package {'guid': ensure => absent}
  MANIFEST

  apply_manifest_on(agents, remove_manifest) do |result|
    assert_match('Package[guid]/ensure: removed', "#{result.host}: #{result.stdout}")
    assert_match('Package[gem-guid]/ensure: removed', "#{result.host}: #{result.stdout}")
  end

  verify_absent agents, 'guid'

end
