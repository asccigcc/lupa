# frozen_string_literal: true

RSpec.describe Lupa::Inflector do
  describe ".singularize" do
    {
      "widgets" => "widget", "deliveries" => "delivery", "categories" => "category",
      "addresses" => "address", "statuses" => "status", "boxes" => "box",
      "batches" => "batch", "wishes" => "wish", "people" => "person",
      "children" => "child", "product_categories" => "product_category",
      "status" => "status", "address" => "address", "series" => "series"
    }.each do |plural, singular|
      it "#{plural} -> #{singular}" do
        expect(described_class.singularize(plural)).to eq(singular)
      end
    end
  end

  describe ".camelize" do
    it "camel-cases a snake_case word" do
      expect(described_class.camelize("chart_note")).to eq("ChartNote")
    end
  end
end
