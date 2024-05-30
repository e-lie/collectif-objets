# frozen_string_literal: true

require "rails_helper"

RSpec.describe Campaign, type: :model do
  describe "factory" do
    it "should be valid" do
      campaign = build(:campaign)
      res = campaign.valid?
      expect(campaign.errors).to be_empty
      expect(res).to eq true
    end
  end

  describe "#step_for_date" do
    let(:campaign) do
      build(
        :campaign,
        date_lancement: Date.new(2030, 5, 10),
        date_relance1: Date.new(2030, 5, 15),
        date_relance2: Date.new(2030, 5, 20),
        date_relance3: Date.new(2030, 5, 25),
        date_fin: Date.new(2030, 5, 30)
      )
    end
    subject { campaign.step_for_date(date) }

    context "date is before lancement" do
      let(:date) { Date.new(2030, 1, 1) }
      it { should eq nil }
    end

    context "date is lancement date" do
      let(:date) { Date.new(2030, 5, 10) }
      it { should eq "lancement" }
    end

    context "date is between lancement and relance1" do
      let(:date) { Date.new(2030, 5, 12) }
      it { should eq "lancement" }
    end

    context "date is relance1" do
      let(:date) { Date.new(2030, 5, 15) }
      it { should eq "relance1" }
    end

    context "date is between relance1 and relance2" do
      let(:date) { Date.new(2030, 5, 17) }
      it { should eq "relance1" }
    end

    context "date is relance2" do
      let(:date) { Date.new(2030, 5, 20) }
      it { should eq "relance2" }
    end

    context "date is between relance3 and end" do
      let(:date) { Date.new(2030, 5, 27) }
      it { should eq "relance3" }
    end

    context "date is date_fin" do
      let(:date) { Date.new(2030, 5, 30) }
      it { should eq "fin" }
    end

    context "date is after date_fin" do
      let(:date) { Date.new(2030, 6, 10) }
      it { should eq "fin" }
    end
  end

  describe "#previous_step_for" do
    subject { Campaign.previous_step_for(step) }

    context "step is lancement" do
      let(:step) { "lancement" }
      it { should eq nil }
    end

    context "step is relance1" do
      let(:step) { "relance1" }
      it { should eq "lancement" }
    end

    context "step is relance3" do
      let(:step) { "relance3" }
      it { should eq "relance2" }
    end

    context "step is end" do
      let(:step) { "fin" }
      it { should eq "relance3" }
    end
  end

  describe "validation coherent dates" do
    let(:date_lancement) { Date.new(2030, 1, 3) }
    let(:date_relance1) { date_lancement + 2.weeks }
    let(:date_relance2) { date_relance1 + 2.weeks }
    let(:date_relance3) { date_relance2 + 2.weeks }
    let(:date_fin) { date_relance3 + 2.weeks }
    let(:campaign) do
      build(:campaign, status: :draft, date_lancement:, date_relance1:, date_relance2:, date_relance3:, date_fin:)
    end
    subject { campaign.valid? }

    context "coherent dates" do
      it { should eq true }
    end

    context "relance2 is before relance1" do
      let(:date_relance2) { date_relance1 - 1.week }
      it { should eq false }
    end

    context "relance2 is same day as relance1" do
      let(:date_relance2) { date_relance1 }
      it { should eq false }
    end

    context "lancement date is in the past" do
      let(:date_lancement) { Time.zone.today.prev_occurring(:monday) }
      it { should eq false }
    end

    context "lancement date is today" do
      let(:date_lancement) { Time.zone.today }
      it { should eq false }
    end

    context "lancement date is in the past for finished campaign" do
      let(:date_lancement) { Time.zone.today.prev_occurring(:monday) }
      let(:campaign) do
        build(
          :campaign,
          status: :finished, date_lancement:, date_relance1:, date_relance2:,
          date_relance3:, date_fin:
        )
      end
      it { should eq true }
    end

    context "begins on a monday" do
      let(:date_lancement) { Date.current.next_week(:monday) }
      it { should eq true }
    end

    context "begins on a saturday" do
      let(:date_lancement) { Date.current.next_week(:saturday) }
      it { should eq false }
    end

    context "begins on a sunday" do
      let(:date_lancement) { Date.current.next_week(:saturday) }
      it { should eq false }
    end

    context "same dates in the past for an ongoing campaign" do
      let(:date_lancement) { Date.new(2022, 1, 3) } # monday
      let(:date_relance1) { date_lancement } # this can happen in staging when force stepping up
      let(:date_relance2) { date_lancement }
      let(:date_relance3) { date_lancement }
      let(:date_fin) { date_lancement + 1.week }
      let(:campaign) do
        build(
          :campaign,
          status: :ongoing, date_lancement:, date_relance1:, date_relance2:,
          date_relance3:, date_fin:
        )
      end
      it { should eq true }
    end
  end

  describe "validate no overlap for planned" do
    let!(:departement) { create(:departement) }
    let!(:existing_campaign) { create(:campaign, departement:, status: :planned, date_lancement: Date.new(2030, 1, 1)) }
    subject { new_campaign.valid? }

    context "new campaign does not overlap" do
      let(:new_campaign) { build(:campaign, departement:, status: :planned, date_lancement: Date.new(2030, 6, 1)) }
      it { should eq false }
    end

    context "new campaign overlaps with other planned one" do
      let(:new_campaign) { build(:campaign, departement:, status: :planned, date_lancement: Date.new(2030, 1, 15)) }
      it { should eq false }
    end

    context "new draft campaign overlaps with other planned one" do
      let(:new_campaign) { build(:campaign, departement:, status: :draft, date_lancement: Date.new(2030, 1, 15)) }
      it { should eq true }
    end
  end

  describe "#plan" do
    let!(:campaign) { create(:campaign, status: "draft") }
    let!(:campaign_recipient1) do
      create(:campaign_recipient, campaign:, commune: build(:commune_with_user, status: "inactive"))
    end
    let!(:campaign_recipient2) do
      create(:campaign_recipient, campaign:, commune: build(:commune_with_user, status: "inactive"))
    end

    context "only inactive communes" do
      it "should allow planning the campaign" do
        res = campaign.plan!
        expect(res).to eq true
        expect(campaign.reload.status).to eq("planned")
      end
    end
  end

  describe "#start" do
    let(:campaign) { create(:campaign_planned) }
    let(:commune_non_recensée) { create(:commune_non_recensée) }
    let(:commune_en_cours_de_recensement) { create(:commune_non_recensée) }
    let(:commune_a_examiner) { create(:commune_a_examiner) }
    let(:commune_en_cours_dexamen) { create(:commune_en_cours_dexamen) }
    let(:commune_examinée) { create(:commune_examinée) }

    before do
      campaign.communes << [commune_non_recensée, commune_en_cours_de_recensement,
                            commune_a_examiner, commune_en_cours_dexamen, commune_examinée]
      commune_en_cours_de_recensement.start
    end

    it "should archive dossiers when necessary" do
      campaign.start

      # Expectations on old dossier
      expect(commune_non_recensée.dossier).to be_nil
      expect(commune_en_cours_de_recensement.dossier.status).to eq("construction")
      expect(commune_a_examiner.dossier.status).to eq("archived")
      expect(commune_en_cours_dexamen.dossier.status).to eq("archived")
      expect(commune_examinée.dossier.status).to eq("archived")

      # Expectations on new dossier
      expect(commune_non_recensée.reload.dossier).to be_nil
      expect(commune_en_cours_de_recensement.reload.dossier.status).to eq("construction")
      expect(commune_a_examiner.reload.dossier).to be_nil
      expect(commune_en_cours_dexamen.reload.dossier).to be_nil
      expect(commune_examinée.reload.dossier).to be_nil
    end
  end

  describe "#add_default_recipients" do
    let(:departement) { create(:departement) }
    let(:campaign) { build(:campaign, departement:) }
    it "ajoute les communes valides aux destinataires" do
      create(:commune, :with_user, departement:) # User, pas d'objet
      create(:commune, :with_objets, departement:) # Pas d'user, des objets
      create(:commune, :with_user, :with_objets, :en_cours_de_recensement, departement:) # User, objets, mais en cours
      communes_valides = 3
      create_list(:commune, communes_valides, :with_user, :with_objets, departement:)
      expect(campaign.add_default_recipients.size).to eq communes_valides
    end
  end
end
