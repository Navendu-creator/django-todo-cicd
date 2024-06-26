require 'typhoeus'
require 'typhoeus/adapters/faraday'
require 'json'

def fetch_families(params = nil)
  request = Typhoeus::Request.new('http://localhost:8081/families', params: params)
  request.run
  {
      response: request.response,
      json: JSON.parse(request.response.body)
  }
end

def test_category(category = nil)
  res = fetch_families(:category => category)
  expect(res[:response].code).to eq(200), "bad status code #{res[:response].code}"
  expect(res[:json]['results'].length).to be > 0, "too few results"
end

def test_filter(params, filter)
  res = fetch_families(params)
  unfiltered_cnt = res[:json]['total']
  res = fetch_families(params.merge filter)
  filtered_cnt = res[:json]['total']
  expect(unfiltered_cnt).to be > 0
  expect(filtered_cnt).to be > 0
  puts "#{unfiltered_cnt} #{filtered_cnt}"
  expect(unfiltered_cnt).to be > filtered_cnt
end

RSpec.describe "api" do

  context "category searches return some results" do

    it "return results with no category (any)" do
      test_category :any
    end

    it "return results in the sans category" do
      test_category :sans
    end

    it "return results in the script category" do
      test_category :script
    end

    it "return results in the display category" do
      test_category :display
    end

    it "return results in the serif category" do
      test_category :serif
    end

    it "return results in the blackletter category" do
      test_category :blackletter
    end

    it "return results in the symbols category" do
      test_category :symbols
    end

    xit "return results in the slab category" do
      test_category :slab
    end

  end

  context "filters" do
    context "webfonts" do
      it "returns fewer results for a category with webfont filter" do
        test_filter({:category => 'serif'}, {:type => 'webfonts'})
      end
      it "returns fewer results for a category with webfonter filter" do
        test_filter({:category => 'serif'}, {:client => 'webfonter'})
      end
      it "autocomplete returns fewer results for a category with webfont filter" do
        test_filter({:autocomplete => true, :q => "DIN"}, {:type => 'webfonts'})
      end
      it "autocomplete returns fewer results for a category with webfonter filter" do
        test_filter({:autocomplete => true, :q => "DIN"}, {:client => 'webfonter'})
      end
      it "similar returns fewer results for a category with webfont filter" do
        test_filter({:similar_to => 2946251}, {:type => 'webfonts'})
      end
    end
  end

  context "sort_orders" do

  end

end