test_name "test that we can query and find a user that exists."

tag 'audit:high',
    'audit:refactor',  # Use block style `test_run`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require changing the system running the test
                       # in ways that might require special permissions
                       # or be harmful to the system running the test

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  step "ensure that our test user exists"
  agent.user_present(name)

  step "query for the resource and verify it was found"
  on(agent, puppet_resource('user', name)) do |result|
    fail_test "didn't find the user #{name}" unless result.stdout.include? 'present'
  end

  step "clean up the user and group we added"
  agent.user_absent(name)
  agent.group_absent(name)
end
