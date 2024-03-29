test_name "#6541: file type truncates target when filebucket cannot retrieve hash"

tag 'audit:high',
    'audit:integration', # file type and file bucket interop
    'audit:refactor'     # look into combining with ticket_4622_filebucket_diff_test.rb
                         # Use block style `test_run`

agents.each do |agent|
  target=agent.tmpfile('6541-target')

  on(agent, "rm -rf \"#{agent.puppet['vardir']}/*bucket\"")

  step "write zero length file"
  manifest = "file { '#{target}': content => '' }"
  apply_manifest_on(agent, manifest)

  step "overwrite file, causing zero-length file to be backed up"
  manifest = "file { '#{target}': content => 'some text', backup => 'puppet' }"
  apply_manifest_on(agent, manifest)

  test_name "verify invalid hashes should not change the file"

  manifest = "file { '#{target}': content => '{sha256}notahash' }"

  apply_manifest_on(agent, manifest) do |result|
    refute_match(/content changed/, result.stdout, "#{agent}: shouldn't have overwrote the file")
  end

  test_name "verify valid but unbucketed hashes should not change the file"
  manifest = "file { '#{target}': content => '{md5}13ad7345d56b566a4408ffdcd877bc78' }"
  apply_manifest_on(agent, manifest) do |result|
    refute_match(/content changed/, result.stdout, "#{agent}: shouldn't have overwrote the file")
  end

  test_name "verify that an empty file can be retrieved from the filebucket"
  manifest = "file { '#{target}': content => '{sha256}e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', backup => 'puppet' }"

  apply_manifest_on(agent, manifest) do |result|
    assert_match(/content changed '\{sha256\}b94f6f125c79e3a5ffaa826f584c10d52ada669e6762051b826b55776d05aed2' to '\{sha256\}e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'/, result.stdout, "#{agent}: shouldn't have overwrote the file")
  end
end
