# frozen_string_literal: true

require "rails_helper"

RSpec.describe Commune, type: :model do
  describe "#start!" do
    let!(:commune) { create(:commune, status: :inactive, dossier: nil) }
    it "change le statut de la commune et créé un dossier" do
      commune.start!
      expect(commune.status.to_sym).to eq :started
      expect(commune.dossier).to be_a Dossier
      expect(commune.dossier.status.to_sym).to eq :construction
    end
  end

  describe "#start! mais un problème se produit" do
    let!(:commune) { create(:commune, status: :inactive, dossier: nil) }
    before do
      def commune.aasm_before_start
        super
        raise StandardError
      end
    end

    it "annule tous les changements" do
      initial_dossier_count = Dossier.count
      expect { commune.start! }.to raise_exception StandardError
      expect(commune.reload.status.to_sym).to eq :inactive
      expect(commune.reload.dossier).to be_nil
      expect(Dossier.count).to eq initial_dossier_count
    end
  end

  describe "#start! mais la commune est déjà associée à un dossier" do
    let!(:commune) { create(:commune, status: :inactive) }
    let!(:dossier) { create(:dossier, commune:) }
    before { commune.update!(dossier:) }
    it "échoue et annule les changements" do
      initial_dossier_count = Dossier.count
      expect { commune.start! }.to(raise_error { AASM::InvalidTransition })
      expect(commune.reload.status.to_sym).to eq :inactive
      expect(commune.reload.dossier).to eq dossier
      expect(Dossier.count).to eq initial_dossier_count
    end
  end

  describe "#complete!" do
    let!(:commune) { create(:commune, status: :started) }
    let!(:dossier) { create(:dossier, commune:) }
    before { commune.update!(dossier:) }
    it "change le statut de la commune et du dossier" do
      commune.complete!
      expect(commune.reload.status.to_sym).to eq :completed
      expect(dossier.reload.status.to_sym).to eq :submitted
      expect(commune.reload.completed_at).to be_within(2.seconds).of(Time.zone.now)
    end
  end

  describe "#complete! mais dossier.submit! échoue" do
    let!(:commune) { create(:commune, status: :started) }
    let!(:dossier) { create(:dossier, commune:) }
    before { commune.update!(dossier:) }
    before { expect(dossier).to receive(:submit!).and_raise(AASM::InvalidTransition) }
    it "échoue et annule les changements" do
      expect { commune.complete! }.to(raise_error { AASM::InvalidTransition })
      expect(commune.reload.status.to_sym).to eq :started
      expect(dossier.reload.status.to_sym).to eq :construction
    end
  end

  describe "#return_to_started!" do
    let!(:commune) { create(:commune, status: :completed) }
    let!(:dossier) { create(:dossier, commune:, status: :submitted) }
    before { commune.update!(dossier:) }
    it "change le statut de la commune et du dossier" do
      commune.return_to_started!
      expect(commune.reload.status.to_sym).to eq :started
      expect(dossier.reload.status.to_sym).to eq :construction
    end
  end

  describe "#return_to_started! mais dossier.return_to_construction échoue" do
    let!(:commune) { create(:commune, status: :completed) }
    let!(:dossier) { create(:dossier, commune:, status: :submitted) }
    before { commune.update!(dossier:) }
    before { expect(dossier).to receive(:return_to_construction!).and_raise(AASM::InvalidTransition) }
    it "échoue et annule les changements" do
      expect { commune.return_to_started! }.to(raise_error { AASM::InvalidTransition })
      expect(commune.reload.status.to_sym).to eq :completed
      expect(dossier.reload.status.to_sym).to eq :submitted
    end
  end

  describe "#shall_receive_email_objets_verts?" do
    let!(:commune) { create(:commune_with_user) }

    it "returns false si la commune n'a pas fini son recensement" do
      expect(commune.shall_receive_email_objets_verts?(Time.zone.today)).to be_falsy

      commune.start!
      expect(commune.shall_receive_email_objets_verts?(Time.zone.today)).to be_falsy
    end

    context "commune a terminé son recensement" do
      let!(:dossier) { create(:dossier, :submitted, commune:) }
      before do
        commune.update(dossier:)
        commune.update(status: "completed")
      end

      it "returns false si soumis il y a moins d'une semaine" do
        dossier.update(submitted_at: Date.new(2023, 11, 9))
        expect(commune.shall_receive_email_objets_verts?(Date.new(2023, 11, 10))).to be_falsy
      end

      it "returns false si c'est le weekend" do
        expect(commune.shall_receive_email_objets_verts?(Date.new(2023, 11, 13))).to be_falsy
      end

      context "le recensement est terminé il y a plus d'une semaine et la date d'envoi est hors weekend" do
        let(:date_envoi) { Date.new(2023, 11, 13) }
        before { dossier.update(submitted_at: Date.new(2023, 11, 3)) }

        it "returns false si la commune a des objets prioritaires" do
          create(:recensement, :en_peril, dossier:)
          expect(commune.shall_receive_email_objets_verts?(date_envoi)).to be_falsy
        end

        it "returns true si la commune n'a pas d'objest prioritaires" do
          expect(commune.shall_receive_email_objets_verts?(date_envoi)).to be_truthy
        end

        it "returns false si la commune est en cours d'examen" do
          objet = create(:objet, commune:)
          create(:recensement, :examiné, objet:)
          expect(commune.shall_receive_email_objets_verts?(date_envoi)).to be_falsey
        end

        it "returns false si la commune a déjà reçu un email objets verts" do
          dossier.update(replied_automatically_at: Date.yesterday)
          expect(commune.shall_receive_email_objets_verts?(date_envoi)).to be_falsey
        end
      end
    end
  end

  describe ".include_objets_count" do
    let!(:commune) { create(:commune) }
    before do
      create_list(:objet, 2, commune:)
    end

    it "fournit un compteur avec 2 objets" do
      expect(Commune.include_objets_count.first.objets_count).to eq 2
    end
  end

  describe ".include_recensements_prioritaires_count" do
    let!(:commune) { create(:commune) }
    before do
      create(:objet, :with_recensement, commune:)
      create(:objet_en_peril, commune:)
      create_list(:objet, 2, :disparu, commune:)
    end

    it "fournit un compteur d'objets disparus" do
      expect(Commune.include_recensements_prioritaires_count.first.disparus_count).to eq 2
    end

    it "fournit un compteur d'objets en péril" do
      expect(Commune.include_recensements_prioritaires_count.first.en_peril_count).to eq 1
    end
  end

  describe ".statut_global" do
    let!(:commune) { create(:commune, status: :inactive) }
    let!(:objet) { create(:objet, commune:) }

    it "a un statut global sur le recensement et l'examen à Non recensé" do
      expect(Commune.include_statut_global.first.statut_global).to eq Commune::ORDRE_NON_RECENSÉ
      expect(Commune.first.statut_global).to eq Commune::ORDRE_NON_RECENSÉ
    end

    context "lorsque la commune a démarré son recensement" do
      before { commune.start! }

      it "a un statut global sur le recensement et l'examen à En cours de recensement" do
        expect(Commune.include_statut_global.first.statut_global).to eq Commune::ORDRE_EN_COURS_DE_RECENSEMENT
        expect(Commune.first.statut_global).to eq Commune::ORDRE_EN_COURS_DE_RECENSEMENT
      end

      context "lorsque la commune a terminé son recensement" do
        let!(:conservateur) { create(:conservateur) }
        before do
          commune.complete!
          commune.dossier.conservateur = conservateur
        end

        context "lorsque la commune a reçu une réponse automatique" do
          before { commune.dossier.update(replied_automatically_at: Time.zone.now) }

          it "a un statut global sur le recensement et l'examen à Réponse automatique" do
            expect(Commune.include_statut_global.first.statut_global).to eq Commune::ORDRE_REPONSE_AUTOMATIQUE
            expect(Commune.first.statut_global).to eq Commune::ORDRE_REPONSE_AUTOMATIQUE
          end

          it "passe en Examiné si le conservateur décide de faire l'examen tout de même" do
            commune.dossier.accept!

            expect(Commune.include_statut_global.first.statut_global).to eq Commune::ORDRE_EXAMINÉ
            expect(Commune.first.statut_global).to eq Commune::ORDRE_EXAMINÉ
          end
        end

        context "recensement avec des objets en peril" do
          let!(:recensement) do
            create(:recensement,
                   etat_sanitaire: Recensement::ETAT_PERIL, dossier: commune.dossier, objet:, conservateur:)
          end

          it "a un statut global sur le recensement et l'examen à À examiner" do
            expect(Commune.include_statut_global.first.statut_global).to eq Commune::ORDRE_A_EXAMINER
            expect(Commune.first.statut_global).to eq Commune::ORDRE_A_EXAMINER
          end

          it "a un statut global sur le recensement et l'examen à En cours d'examen" do
            recensement.update(analysed_at: Time.zone.now)

            expect(Commune.include_statut_global.first.statut_global).to eq Commune::ORDRE_EN_COURS_D_EXAMEN
            expect(Commune.first.statut_global).to eq Commune::ORDRE_EN_COURS_D_EXAMEN
          end
        end

        it "a un statut global sur le recensement et l'examen à Examiné" do
          commune.dossier.accept!

          expect(Commune.include_statut_global.first.statut_global).to eq Commune::ORDRE_EXAMINÉ
          expect(Commune.first.statut_global).to eq Commune::ORDRE_EXAMINÉ
        end
      end
    end
  end
end
