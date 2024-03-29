test_name 'PUP-3755 Test an un-assigned broken environment'

tag 'audit:high',
    'audit:integration',
    'audit:refactor',     # Use mk_tmp_environment_with_teardown helper
    'server'

teardown do
  agents.each do |agent|
    on(agent, puppet('config print lastrunfile')) do |command_result|
      agent.rm_rf(command_result.stdout)
    end
  end
end

step 'setup environments'

testdir = create_tmpdir_for_user(master, 'confdir')
environment = 'debug'
manifest = <<-MANIFEST
  File {
    ensure => directory,
    owner => #{master.puppet['user']},
    group => #{master.puppet['group']},
    mode => "0750",
  }

  file { "#{testdir}":;
    "#{testdir}/environments":;
    "#{testdir}/environments/production":;
    "#{testdir}/environments/production/manifests":;
    "#{testdir}/environments/production/modules":;
    "#{testdir}/environments/#{environment}":;
    "#{testdir}/environments/#{environment}/manifests":;
    "#{testdir}/environments/#{environment}/modules":;
  }
  # broken envioronment
  file { "#{testdir}/environments/production/manifests/site.pp":
    ensure  => file,
    content => 'import "/tmp/bogus/*.pp"'
  }
  file { "#{testdir}/environments/#{environment}/manifests/site.pp":
    ensure  => file,
    content => 'node default{\nnotify{"you win":}\n}'
  }
MANIFEST

apply_manifest_on(master, manifest, :catch_failures => true)

step 'run agents, ensure no one complains about the other environment'

master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments"
  }
}

with_puppet_running_on(master, master_opts, testdir) do
  agents.each do |agent|
    on(agent, puppet('agent',
                     "--test --environment #{environment}"),
       :acceptable_exit_codes => (0..255)) do |result|
      assert_match(/you win/, result.stdout, 'agent did not pickup newly classified environment.')
    end
  end
end
