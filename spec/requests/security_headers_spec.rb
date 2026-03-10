require "rails_helper"

RSpec.describe "Security Headers", type: :request do
  it "includes required security headers" do
    get "/health"

    expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
    expect(response.headers["X-Frame-Options"]).to eq("ALLOWALL")
    expect(response.headers["Content-Security-Policy"]).to include("frame-ancestors")
    expect(response.headers["Referrer-Policy"]).to eq("strict-origin-when-cross-origin")
    expect(response.headers["Permissions-Policy"]).to include("camera=()")
  end
end
