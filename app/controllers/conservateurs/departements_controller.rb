# frozen_string_literal: true

module Conservateurs
  class DepartementsController < BaseController
    before_action :set_departements, only: [:index, :activite_des_departements]
    before_action :set_departement, only: [:show, :carte, :activite]
    before_action :set_date_range, only: [:activite, :activite_des_departements]
    before_action :set_communes, only: [:show, :carte]
    before_action :set_status_global_filter, only: [:show]
    before_action :set_tabs, only: [:show, :carte, :activite]

    skip_after_action :verify_authorized, only: :activite_des_departements

    def index; end

    def activite_des_departements
      if @departements.length == 1
        redirect_to activite_conservateurs_departement_path(@departements.first)
      else
        render "activite"
      end
    end

    def show
      @ransack = @communes.select("nom").ransack(params[:q])

      # Remonte par défaut les communes avec le plus d'objets en péril
      @ransack.sorts = "en_peril_count DESC" if @ransack.sorts.empty?
      @ransack.sorts = "nom ASC" unless @ransack.sorts.collect(&:attr).include? "unaccent(nom)"

      @pagy, @communes = pagy @ransack.result, items: 15
      @query_present = params[:q].present?
      render "tabs"
    end

    def carte
      @communes.select(%w[code_insee nom status objets_count en_peril_count latitude longitude]).to_a
      @departement_json = {
        code: @departement.code,
        boundingBox: @departement.bounding_box
      }.to_json
      render "tabs"
    end

    def activite
      render "tabs"
    end

    protected

    def set_departements
      @departements = policy_scope(Departement).include_objets_count.order(:code)
    end

    def set_departement
      @departement = Departement.find(params[:id])
      authorize(@departement)
    end

    def set_communes
      @communes = @departement.communes.include_statut_global
    end

    def set_date_range
      @date_start = parse_date(params[:du])
      @date_end = parse_date(params[:au])
      @date_range = @date_start && @date_end ? @date_start..@date_end : Date.current.all_week
      @date_start ||= @date_range.first
      @date_end   ||= @date_range.last
    end

    def set_tabs
      anchor = :tabpanel
      @tabs = [
        [:show, "Vue tableau", conservateurs_departement_path(@departement, anchor:)],
        [:carte, "Vue carte", carte_conservateurs_departement_path(@departement, anchor:)],
        [:activite, "Activité", activite_conservateurs_departement_path(@departement, anchor:)]
      ]
    end

    def set_status_global_filter
      # Si l'utilisateur choisit un statut à filtrer, le conserver en session
      if params[:q] && params[:q][:statut_global_eq]
        session[:statut_global_eq] = params[:q][:statut_global_eq]
      elsif session[:statut_global_eq] # sinon, on le renvoie sur le statut choisi précédemment
        redirect_to conservateurs_departement_path(@departement, q: { statut_global_eq: session[:statut_global_eq] })
      end
    end

    def active_nav_links = ["Mes départements", @departement&.to_s].compact

    def parse_date(str)
      return if str.nil? || str.blank?

      Date.strptime(str, "%Y-%m-%d")
    rescue Date::Error
      nil
    end
  end
end
