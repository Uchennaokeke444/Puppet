test_name "should query all users"

tag 'audit:high',
    'audit:refactor',  # Use block style `test_run`
    'audit:integration'

agents.each do |agent|
  next if agent == master
  skip_test('this test fails on windows French due to Cygwin/UTF Issues - PUP-8319,IMAGES-492') if agent['platform'] =~ /windows/ && agent['locale'] == 'fr'

  step "query natively"
  users = agent.user_list

  fail_test("No users found") unless users

  step "query with puppet"
  on(agent, puppet_resource('user')) do |result|
    result.stdout.each_line do |line|
      name = ( line.match(/^user \{ '([^']+)'/) or next )[1]

      unless users.delete(name)
        fail_test "user #{name} found by puppet, not natively"
      end
    end
  end

  if users.length > 0 then
    fail_test "#{users.length} users found natively, not puppet: #{users.join(', ')}"
  end
end
