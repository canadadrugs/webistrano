require File.dirname(__FILE__) + '/../test_helper'

class AuthenticationLDAPTest < ActiveSupport::TestCase
  def setup
    @authentication_method = WebistranoConfig.delete(:authentication_method) if WebistranoConfig.has_key?(:authentication_method)
    @ldap = WebistranoConfig.delete(:ldap) if WebistranoConfig.has_key?(:ldap)
    WebistranoConfig[:ldap] = {
      :host => '172.16.101.13',
      :port => 389,
      :base => 'DC=CANDRUGCORP'
    }
  end

  def teardown
    if @authentication_method
      WebistranoConfig[:authentication_method] = @authentication_method
    else
      WebistranoConfig.delete(:authentication_method)
    end
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

  def test_authenticate_should_add_domain_to_username
    username, password = 'quentin', 'password'
    AuthenticationLDAP.expects(:initialize_ldap_connection).with(:username => "#{username}@CANDRUGCORP", :password => password).returns(stub(:bind => false))
    AuthenticationLDAP.authenticate(username, password)
  end

  def test_authenticate_should_return_nil_if_login_fails
    Net::LDAP.any_instance.stubs(:bind).returns(false)
    assert_equal AuthenticationLDAP.authenticate('quentin', 'password'), nil
  end

  def test_authenticate_should_return_user_attributes_if_login_succeeds
    email, guid = 'quentin@example.com', '123456'
    username, password = 'quentin', 'password'
    Net::LDAP.any_instance.stubs(:bind).returns(true)
    Net::LDAP.any_instance.stubs(:search).yields({
      :memberof => ['CN=Employees,CN=Users,DC=CanDrugCorp'],
      :mail => [email],
      :objectguid => [guid]
    })
    assert_equal AuthenticationLDAP.authenticate(username, password), {
      :email => email,
      :login => username,
      :guid => guid
    }
  end
end
