require File.dirname(__FILE__) + '/../test_helper'

class AuthenticationLDAPTest < ActiveSupport::TestCase
  def setup
    remove_authentication_method
    @ldap = WebistranoConfig.delete(:ldap) if WebistranoConfig.has_key?(:ldap)
    WebistranoConfig[:ldap] = {
      :host => '172.16.101.13',
      :port => 389,
      :base => 'DC=CANDRUGCORP',
      :domain => 'CANDRUGCORP',
      :memberof => 'CN=Employees,CN=Users,DC=CanDrugCorp',
      :ldap_id => 'ldap_id'
    }
  end

  def teardown
    add_authentication_method
    if @ldap
      WebistranoConfig[:ldap] = @ldap
    else
      WebistranoConfig.delete(:ldap)
    end
  end

  def test_initialize_ldap_connection
    username, password = 'quentin', 'password'
    # :host, :port, and :base are defined in WebistranoConfig (see setup)
    Net::LDAP.expects(:new).with({
      :host => '172.16.101.13',
      :port => 389,
      :base => 'DC=CANDRUGCORP',
      :auth => {
        :method => :simple,
        :username => username,
        :password => password
      }
    })
    AuthenticationLDAP.send(:initialize_ldap_connection, :username => username, :password => password)
  end

  def test_authenticate_should_add_domain_to_username_if_provided
    username, password = 'quentin', 'password'
    AuthenticationLDAP.expects(:initialize_ldap_connection).with(:username => "#{username}@CANDRUGCORP", :password => password).returns(stub(:bind => false))
    AuthenticationLDAP.authenticate(username, password)
  end

  def test_authenticate_should_not_add_domain_to_username_if_not_provided
    without_ldap_config_option(:domain) do
      username, password = 'quentin', 'password'
      AuthenticationLDAP.expects(:initialize_ldap_connection).with(:username => username, :password => password).returns(stub(:bind => false))
      AuthenticationLDAP.authenticate(username, password)
    end
  end

  def test_authenticate_should_return_nil_if_login_fails
    Net::LDAP.any_instance.stubs(:bind).returns(false)
    assert_equal AuthenticationLDAP.authenticate('quentin', 'password'), nil
  end

  def test_authenticate_should_return_user_attributes_with_ldap_id_and_memerof_if_login_succeeds
    email, ldap_id = 'quentin@example.com', '123456'
    username, password = 'quentin', 'password'
    Net::LDAP.any_instance.stubs(:bind).returns(true)
    Net::LDAP.any_instance.stubs(:search).yields({
      :memberof => ['CN=Employees,CN=Users,DC=CanDrugCorp'],
      :mail => [email],
      :ldap_id => [ldap_id]
    })
    assert_equal AuthenticationLDAP.authenticate(username, password), {
      :email => email,
      :login => username,
      :ldap_id => ldap_id
    }
  end

  def test_authenticate_should_return_user_attributes_without_ldap_id_with_memberof_if_login_succeeds
    without_ldap_config_option(:ldap_id) do
      email, ldap_id = 'quentin@example.com', '123456'
      username, password = 'quentin', 'password'
      Net::LDAP.any_instance.stubs(:bind).returns(true)
      Net::LDAP.any_instance.stubs(:search).yields({
        :memberof => ['CN=Employees,CN=Users,DC=CanDrugCorp'],
        :mail => [email]
      })
      assert_equal AuthenticationLDAP.authenticate(username, password), {
        :email => email,
        :login => username
      }
    end
  end

  def test_authenticate_should_return_user_attributes_with_ldap_id_and_without_memberof_if_login_succeeds
    without_ldap_config_option(:memberof) do
      email, ldap_id = 'quentin@example.com', '123456'
      username, password = 'quentin', 'password'
      Net::LDAP.any_instance.stubs(:bind).returns(true)
      Net::LDAP.any_instance.stubs(:search).yields({
        :mail => [email],
        :ldap_id => ldap_id
      })
      assert_equal AuthenticationLDAP.authenticate(username, password), {
        :email => email,
        :login => username,
        :ldap_id => ldap_id
      }
    end
  end

  def test_authenticate_should_return_nil_if_memberof_check_fails
    email, ldap_id = 'quentin@example.com', '123456'
    username, password = 'quentin', 'password'
    Net::LDAP.any_instance.stubs(:bind).returns(true)
    Net::LDAP.any_instance.stubs(:search).yields({
      :memberof => ['This is not what we are expecting'],
      :mail => [email],
      :ldap_id => ldap_id
    })
    assert_equal AuthenticationLDAP.authenticate(username, password), nil
  end

  def without_ldap_config_option(option)
    value = WebistranoConfig[:ldap].delete(option)
    yield
    WebistranoConfig[:ldap][option] = value
  end
end
