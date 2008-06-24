require File.dirname(__FILE__) + '/../test_helper'

# Re-raise errors caught by the controller.
Admin::PageController.class_eval { def rescue_action(e) raise e end }

class PageControllerExtensionsTest < Test::Unit::TestCase
  include ActionController::UrlWriter
  
  fixtures :sites, :pages
  test_helper :pages, :login, :difference
  
  class TestResponse < ActionController::TestResponse
    def initialize(body = '', headers = {})
      self.body = body
      self.headers = headers
    end
  end
  
  def setup
    @controller = Admin::PageController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    default_url_options[:host] = 'test.host'
  end
  
  def test_should_set_root_to_given_page_id
    login_as(:developer) # or admin
    get :index, :root => 5
    assert_response :success
    assert_not_nil assigns(:homepage)
    assert_equal 5, assigns(:homepage).id
    assert_equal sites(:one), assigns(:site)
  end

  def test_should_deny_regular_user_access_to_other_sites
    login_as(:existing)
    get :index, :root => 5
    assert_response :redirect
    assert_redirected_to login_url
  end
  
  def test_should_pick_first_site_if_no_root_given
    login_as(:developer) # non-devel or admin users are bound to their own sites
    get :index
    assert_response :success
    assert_equal pages(:homepage), assigns(:homepage)
    assert_equal sites(:one), assigns(:site)
  end

  def test_should_fallback_on_default_when_no_sites_defined
    login_as(:developer) # or admin
    Site.delete_all
    get :index
    assert_response :success
    assert_equal pages(:homepage), assigns(:homepage)
  end

  def test_should_deny_access_if_user_site_deleted
    user = users(:existing)
    user.site = sites(:one)
    user.save

    login_as(:existing)
    Site.delete_all
    get :index
    assert_response :redirect
    assert_redirected_to login_url
  end
  
  def test_should_remove_page_if_site_owner
    create_pages_for(sites(:two))
    @user = users(:existing)
    @user.site = sites(:two)
    @user.save
    
    login_as(:existing)
    assert_difference(Page, :count, -1) do
      post :remove, :id => sites(:two).homepage.children[0].id
      assert_response :redirect
      assert sites(:two), assigns(:site)
    end
  end
  
  def test_should_deny_remove_page_if_user_is_not_owner
    login_as(:existing)
    assert_no_difference(Page, :count) do
      post :remove, :id => pages(:childless)
      assert_response :redirect
      assert_redirected_to login_url
    end
  end
  
  def test_should_redirect_after_remove
    create_pages_for(sites(:two))
    login_as(:developer)
    
    assert_difference(Page, :count, -1) do
      post :remove, :id => sites(:two).homepage.children[0].id
      assert_response :redirect
      assert sites(:two), assigns(:site)
    end
  end
  
  def test_should_create_user_site_page
    @user = users(:existing)
    @user.site = sites(:two)
    @user.save
    
    create_pages_for(sites(:two))    

    login_as(:existing)
    assert_difference(Page, :count) do
      post :new, :parent_id => sites(:two).homepage_id, :page => page_params(:title => 'xyz', :slug => 'xyz')
      assert_response :redirect
      assert_equal sites(:two), assigns(:site)
    end
  end
  
  def test_should_limit_create_to_user_site
    login_as(:existing)
    assert_no_difference(Page, :count) do
      post :new, :parent_id => pages(:homepage), :page => page_params(:title => 'xyz', :slug => 'xyz')
      assert_response :redirect
      assert_redirected_to login_url
    end
  end
  
  def test_should_redirect_on_create # admin or developer
    create_pages_for(sites(:two))
    
    login_as(:developer)
    assert_difference(Page, :count) do
      post :new, :parent_id => sites(:two).homepage_id, :page => page_params(:title => 'xyz', :slug => 'xyz')
      assert_response :redirect
      assert_equal sites(:two), assigns(:site)
    end
  end
  
  def test_should_edit_user_site_page
    @user = users(:existing)
    @user.site = sites(:one)
    @user.save
    
    login_as(:existing)
    post :edit, :id => pages(:homepage), :page => { :title => 'updated', :slug => 'updated' }
    assert_response :redirect
    assert_equal sites(:one), assigns(:site)
    
    assert_equal 'updated', sites(:one).homepage.title
  end
  
  def test_should_limit_edit_to_user_site
    login_as(:existing)
    title = pages(:homepage).title
    post :edit, :id => pages(:homepage), :page => { :title => 'updated', :slug => 'updated' }
    assert_response :redirect
    assert_redirected_to login_url
    assert_equal title, pages(:homepage).reload.title
  end
  
  def test_should_redirect_on_edit # admin or developer
    login_as(:developer)    
    post :edit, :id => pages(:homepage), :page => { :title => 'updated', :slug => 'updated' }
    assert_response :redirect
    assert_equal pages(:homepage).root.site, assigns(:site)
    assert_equal 'updated', pages(:homepage).reload.title
  end
  
  def test_should_set_site_when_clearing_cache
    Page.send "current_site=", nil 
    @controller.send :instance_variable_set, "@page", pages(:homepage)
    @controller.send :clear_model_cache
    assert_equal sites(:one), Page.current_site
  end

  def test_should_scope_layouts_to_site
    @user = users(:existing)
    @user.site = sites(:one)
    @user.save

    @layout = Layout.create(:name => "Layout for site", :site => sites(:two))

    login_as(:existing)
    get :edit, :id => pages(:homepage)
    assert_response :success
    assert_select "select#page_layout_id" do
      assert_select "option", Layout.count(:conditions => "site_id IS NULL or site_id = #{@user.site_id}") + 1 # +1 is inherit
    end
  end

  protected

    def create_pages_for(site)
      homepage = create_test_page(:title => "new home page", :slug => "new1")
      childpage = create_test_page(:title => "new child page", :slug => "new2", :parent_id => homepage.id)
      site.homepage = homepage
      site.save
    end
    
    def create_cached_pages_for(site)      
      Page.current_site = site
      @cache.cache_response('test', TestResponse.new('test'))
      assert_equal 2, Dir["#{@cache_dir}/#{site.base_domain}/*"].size
    end
end
