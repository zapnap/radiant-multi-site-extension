require File.dirname(__FILE__) + '/../test_helper'

class ResponseCacheExtensionsTest < Test::Unit::TestCase
  fixtures :sites

  class TestResponse < ActionController::TestResponse
    def initialize(body = '', headers = {})
      self.body = body
      self.headers = headers
    end
  end
  
  def setup
    @cache_dir = File.expand_path("#{RAILS_ROOT}/test/cache")
    Dir["#{@cache_dir}/*"].each { |d| FileUtils.rm_rf d }

    @cache = ResponseCache.new(
      :directory => @cache_dir,
      :perform_caching => true
    )
  end
  
  def test_should_scope_cache_location_to_current_site
    Page.current_site = nil
    assert_equal @cache.send(:page_cache_path, "/"), @cache.send(:page_cache_path_without_site, '/')
    assert_equal @cache.send(:page_cache_path, "/blah"), @cache.send(:page_cache_path_without_site, '/blah')
    
    Page.current_site = sites(:one)
    base_path = File.expand_path(File.join(@cache.directory, sites(:one).base_domain))
    assert_equal File.join(base_path, '_site-root'), @cache.send(:page_cache_path, "/")
    assert_equal File.join(base_path, 'blah'), @cache.send(:page_cache_path_without_site, '/mysite.domain.com/blah')
  end

  def test_should_clear_site_cache
    Page.current_site = sites(:one)
    @cache.cache_response("test1", response('content'))
    @cache.cache_response("test2", response('content'))
    assert_equal 1, Dir["#{@cache_dir}/*"].size
    assert_equal 4, Dir["#{@cache_dir}/#{sites(:one).base_domain}/*"].size

    @cache.clear_with_site(sites(:one))
    assert_equal 0, Dir["#{@cache_dir}/#{sites(:one).base_domain}/*"].size
  end

  def test_should_clear_all_site_caches
    Page.current_site = sites(:one)
    @cache.cache_response("test1", response('content'))
    @cache.cache_response("test2", response('content'))
    assert_equal 1, Dir["#{@cache_dir}/*"].size
    assert_equal 4, Dir["#{@cache_dir}/#{sites(:one).base_domain}/*"].size

    @cache.clear_with_site(nil)
    assert_equal 0, Dir["#{@cache_dir}/*"].size
  end

  private

    def response(*args)
      TestResponse.new(*args)
    end
end
