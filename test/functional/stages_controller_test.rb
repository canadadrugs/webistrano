require File.dirname(__FILE__) + '/../test_helper'

class StagesControllerTest < ActionController::TestCase

  def setup
    @project = create_new_project(:template => 'mongrel_rails')
    @stage = create_new_stage(:project => @project, :name => 'my_stage')
    @user = login
  end

  def assign_stage_to_user(stage, user)
    user.stages << stage
    user.save!
  end

  def test_should_get_index
    get :index, :project_id => @project.id 
    assert_response :success
  end

  def test_should_get_redirect_if_not_admin
    @user = login
    get :new, :project_id => @project.id
    assert_redirected_to home_path
    assert_not_nil flash[:notice]
  end

  def test_should_create_stage_if_admin
    @user = admin_login
    old_count = Stage.count
    post :create, :stage => { :name => 'Beta' }, :project_id => @project.id
    assert_equal old_count+1, Stage.count
    assert_redirected_to project_stage_path(assigns(:project), assigns(:stage))
  end

  def test_should_show_stage_if_admin
    @user = admin_login
    get :show, :id => @stage.id, :project_id => @project.id
    assert_response :success
  end

  def test_should_show_stage_if_user_has_stage
    assign_stage_to_user(@stage, @user)
    get :show, :id => @stage.id, :project_id => @project.id
    assert_response :success
  end

  def test_should_get_edit_if_admin
    @user = admin_login
    get :edit, :id => @stage.id, :project_id => @project.id
    assert_response :success
  end
  
  def test_should_update_stage_if_admin
    @user = admin_login
    put :update, :id => @stage.id, :project_id => @project.id, :stage => { :name => 'Gamma' }
    assert_redirected_to project_stage_path(assigns(:project), assigns(:stage))
    assert_not_nil flash[:notice]
  end
  
  def test_should_destroy_stage_if_admin
    @user = admin_login
    old_count = Stage.count
    delete :destroy, :id => @stage.id, :project_id => @project.id
    assert_equal old_count-1, Stage.count
    
    assert_redirected_to project_path(@project)
  end
  
  def test_capfile_if_admin
    @user = admin_login
    @project = create_new_project(:template => 'mongrel_rails', :name => 'Schumaker Levi')
    @stage = create_new_stage(:project => @project, :name => '123 Name')
    
    # set some config values and expect to find these in the Capfile
    @stage.configuration_parameters.build(:name => 'scm_command', :value => '/tmp/foobar_scm_command').save!
    @stage.configuration_parameters.build(:name => 'my_conf', :value => nil, :prompt_on_deploy => 1).save!
    @project.configuration_parameters.build(:name => 'mongrel_port', :value => '99').save!
    @project.configuration_parameters.build(:name => 'bool_conf', :value => 'true').save!
    
    web_role = create_new_role(:stage => @stage, :name => 'web')
    app_role = create_new_role(:stage => @stage, :name => 'app', :primary => 1)
    db_role = create_new_role(:stage => @stage, :name => 'db', :no_release => 1)
  
    recipe_1 = create_new_recipe(:name => 'Copy config files', :body => 'foobar here')
    @stage.recipes << recipe_1
  
    get :capfile, :id => @stage.id, :project_id => @project.id
    assert_response :success
    
    # variables check
    assert_match 'set :scm_command, "/tmp/foobar_scm_command"', @response.body
    assert_match 'Capistrano::CLI.ui.ask "Please enter \'my_conf\': "', @response.body
    assert_match 'set :mongrel_port, "99"', @response.body
    assert_match 'set :bool_conf, true', @response.body
    
    # check default webistrano vars
    assert_match "set :webistrano_project, \"schumaker_levi\"", @response.body
    assert_match "set :webistrano_stage, \"123_name\"", @response.body
    
    # check roles
    assert_match "role :web, \"#{web_role.hostname_and_port}\"", @response.body
    assert_match "role :app, \"#{app_role.hostname_and_port}\", {:primary=>true}", @response.body
    assert_match "role :db, \"#{db_role.hostname_and_port}\", {:no_release=>true}", @response.body
    
    # tasks
    assert_match "invoke_command \"mongrel_rails cluster::", @response.body
    
    # custom recipes
    assert_match "foobar here", @response.body
  end
  
  def test_should_show_stage_tasks
    get :tasks, :id => @stage.id, :project_id => @project.id
    assert_response :success
    assert_match /webistrano:mongrel:start/, @response.body
  end
  
  def test_should_render_xml_for_stage_tasks
    @user = login
    get :tasks, :id => @stage.id, :project_id => @project.id, :format => "xml"
    assert_response :success
    assert_match /webistrano:mongrel:start/, @response.body
  end
  
  def test_index
    get :index, :project_id => @project.id, :format => 'xml'
    assert_response :success
    assert_select 'stages' do |elements|
      elements.each do |el|
        assert_select 'stage>name', 'my_stage' 
      end
    end
  end
  
end
