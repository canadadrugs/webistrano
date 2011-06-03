require 'net/ldap'

class LDAPCommError < StandardError;end

class AuthenticationLDAP
  
  def self.authenticate(username,password)
    user_attributes = nil

    connection = initialize_ldap_connection(:username => "#{username}@CANDRUGCORP", :password => password)
    filter = Net::LDAP::Filter.eq( "sAMAccountName", username ) 
    if connection.bind
      connection.search( :filter => filter, :attributes => ["mail","description","givenname",'sn',"samaccountname", "memberof"] ) do |entry|
        if entry[:memberof].include?("CN=Employees,CN=Users,DC=CanDrugCorp")
          user_attributes = {   
                    :email => entry[:mail].first,
                    :login => username
                  }
        end
      end
    end
    
    user_attributes
  rescue Net::LDAP::LdapError => e
    ActiveRecord::Base.logger.error("#{self}.class#authenticate Error #{e.class}: #{e.message}")
    return nil
  end

  def self.find_user(username)
    user_attributes = nil
    connection = initialize_ldap_connection(:admin => true)

    if connection.bind
      filter = Net::LDAP::Filter.eq( "samaccountname", username )
      user_attributes = connection.search(:filter => filter, :attributes => ['*']).first
    end
    
    user_attributes
  rescue Net::LDAP::LdapError => e
    ActiveRecord::Base.logger.error("#{self}.class#find_user Error #{e.class}: #{e.message}")
    raise LDAPCommError.new
  end

private

  def self.initialize_ldap_connection(options={})
    config = WebistranoConfig[:ldap]
    options.merge!(WebistranoConfig[:ldap])

    Net::LDAP.new(
                  :host => config[:host], 
                  :port => config[:port],
                  :base => config[:base],
                  :auth => { 
                            :method => :simple, 
                            :username => options[:username], 
                            :password => options[:password]
                            }
                  ) 
  end
  
end
