test_name "ensure that puppet does not report removing a user that does not exist"

tag 'audit:high',
    'audit:refactor',  # Use block style `test_run`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require changing the system running the test
                       # in ways that might require special permissions
                       # or be harmful to the system running the test

name = "pl#{rand(999999).to_i}"

step "verify that user #{name} does not exist"
agents.each do |agent|
  agent.user_absent(name)
end

step "ensure absent doesn't try and do anything"
on(agents, puppet_resource('user', name, 'ensure=absent')) do |result|
  fail_test "tried to remove the user, apparently" if result.stdout.include? 'removed'
end
