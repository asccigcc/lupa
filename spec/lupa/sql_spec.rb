# frozen_string_literal: true

RSpec.describe Lupa::Sql do
  describe ".quote" do
    it "escapes single quotes to keep the SQL injection-safe" do
      expect(described_class.quote("O'Brien")).to eq("'O''Brien'")
    end
  end

  describe ".like_literal" do
    it "escapes LIKE wildcards and the escape character itself" do
      expect(described_class.like_literal("a_b%c\\d")).to eq("a\\_b\\%c\\\\d")
    end
  end
end
