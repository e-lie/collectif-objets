# frozen_string_literal: true

require "rails_helper"

describe SessionCode, type: :service do
  describe ".random_code" do
    it "should generate a 6-digit code" do
      code = SessionCode.random_code
      expect(code).to match(/^\d{6}$/)
    end
  end

  describe "#expired?" do
    let(:session_code) { build(:session_code, created_at:) }
    subject { session_code.expired? }
    context "sent 3 minutes ago" do
      let(:created_at) { 3.minutes.ago }
      it { should eq false }
    end
    context "sent 3 days ago" do
      let(:created_at) { 3.days.ago }
      it { should eq true }
    end
  end
end
