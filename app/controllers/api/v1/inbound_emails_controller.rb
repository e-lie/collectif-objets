# frozen_string_literal: true

module Api
  module V1
    class InboundEmailsController < BaseController
      before_action :validate_ip

      PERMITTED_PARAMS_ROOT = %w[
        MessageId InReplyTo ReplyTo SentAtDate Subject RawHtmlBody RawTextBody ExtractedMarkdownMessage
        ExtractedMarkdownSignature SpamScore
      ].freeze
      PERMITTED_PARAMS_NESTED = [
        {
          "Uuid" => [],
          "From" => %w[Name Address],
          "To" => %w[Name Address],
          "Cc" => [],
          "Attachments" => %w[Name ContentType ContentLength ContentID DownloadToken],
          "Headers" => %w[
            Return-Path Delivered-To Received ARC-Seal ARC-Message-Signature ARC-Authentication-Results DKIM-Signature
            MIME-Version References In-Reply-To From Date Message-ID Subject To Content-Type Received-SPF
          ]
        }
      ].freeze
      PERMITTED_PARAMS = { "items" => PERMITTED_PARAMS_ROOT + PERMITTED_PARAMS_NESTED }.freeze

      def create
        items.each { ReceiveInboundEmailJob.perform_async(_1) }
        render json: { success: true }
      end

      private

      def validate_ip
        # cf https://developers.sendinblue.com/docs/how-to-use-webhooks#securing-your-webhooks
        return true if \
          (Rails.env.development? && request.ip == "127.0.0.1") ||
          request.ip.start_with?("185.107.232.") ||
          request.ip.start_with?("1.179.112.")

        render status: :forbidden, json: { error: "IP not authorized" }
      end

      def items
        params.permit(PERMITTED_PARAMS)["items"].map(&:to_h)
      end
    end
  end
end