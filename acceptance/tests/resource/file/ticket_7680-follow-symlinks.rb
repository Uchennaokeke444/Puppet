test_name "#7680: 'links => follow' should use the file source content"

tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:acceptance'

agents.each do |agent|

  step "Create file content"
  real_source = agent.tmpfile('follow_links_source')
  dest        = agent.tmpfile('follow_links_dest')
  symlink     = agent.tmpfile('follow_links_symlink')

  on agent, "echo 'This is the real content' > #{real_source}"
  if agent['platform'].include?('windows')
    # cygwin ln doesn't behave properly, fallback to mklink,
    # but that requires backslashes, that need to be escaped,
    # and the link cannot exist prior.
    on agent, "rm -f #{symlink}"
    on agent, "cmd /c mklink #{symlink.gsub('/', '\\\\\\\\')} #{real_source.gsub('/', '\\\\\\\\')}"
  else
    on agent, "ln -sf #{real_source} #{symlink}"
  end

  manifest = <<-MANIFEST
    file { '#{dest}':
      ensure => file,
      source => '#{symlink}',
      links  => follow,
    }
  MANIFEST
  apply_manifest_on(agent, manifest, :trace => true)

  on(agent, "cat #{dest}") do |result|
    assert_match(/This is the real content/, result.stdout)
  end

  step "Cleanup"
  [real_source, dest, symlink].each do |file|
    on agent, "rm -f '#{file}'"
  end
end


