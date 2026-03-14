require "rails_helper"

RSpec.describe "Brakeman security scan" do
  it "finds no warnings" do
    result = `bundle exec brakeman --no-pager -q --format json`
    report = JSON.parse(result)
    warnings = report["warnings"]
    expect(warnings).to be_empty,
      "Brakeman found #{warnings.size} warnings:\n" +
      warnings.map { |w| "  - #{w['warning_type']}: #{w['message']} (#{w['file']}:#{w['line']})" }.join("\n")
  end
end
