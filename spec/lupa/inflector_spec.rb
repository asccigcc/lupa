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

  describe ".pluralize" do
    {
      "profile" => "profiles", "order_summary" => "order_summaries", "product_category" => "product_categories",
      "day" => "days", "box" => "boxes", "batch" => "batches", "address" => "addresses",
      "status" => "statuses", "person" => "people", "settings" => "settings"
    }.each do |singular, plural|
      it "#{singular} -> #{plural}" do
        expect(described_class.pluralize(singular)).to eq(plural)
      end
    end
  end

  describe ".camelize" do
    it "camel-cases a snake_case word" do
      expect(described_class.camelize("chart_note")).to eq("ChartNote")
    end
  end
end
