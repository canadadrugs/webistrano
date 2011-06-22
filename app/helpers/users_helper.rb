module UsersHelper
  def can_create_user?
    WebistranoConfig[:authentication_method] != :ldap
  end

  def can_change_password?
    ![:ldap, :cas].include?(WebistranoConfig[:authentication_method])
  end
end
