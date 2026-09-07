# The editor's round trip: a document in, the drawing and its construction
# out, nothing saved. What the badge page shows on load is the same answer
# for the stored document, so the editor and the page cannot disagree.
module Badger
  class Badges::RendersController < ApplicationController
    before_action :set_badge

    # The document comes as JSON under `document`, or as YAML under
    # `document_yaml` from the editor's Document view; the answer carries
    # the document both ways, so either view can take up what the other
    # changed.
    def create
      badge = Badge.new(name: @badge.name)
      if params.key?(:document_yaml)
        badge.spec_yaml = params[:document_yaml].to_s
        raise Badger::Error, "The document is not YAML: #{badge.yaml_error}" if badge.yaml_error
      else
        badge.spec = params.require(:document).permit!.to_h
      end
      render json: badge.rendering.merge(document: badge.spec, yaml: badge.spec_yaml)
    rescue Badger::Spec::Error, Badger::Error => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    private
      def set_badge
        @badge = Badge.find(params[:id])
      end
  end
end
