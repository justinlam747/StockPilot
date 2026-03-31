# frozen_string_literal: true

# Handles data ingestion: CSV upload and pasted text import with column mapping.
class ImportsController < ApplicationController
  before_action :require_shop!

  def index
    @imports = Import.order(created_at: :desc).page(params[:page]).per(20)
  end

  def new; end

  def create
    parsed = parse_input
    return unless parsed

    @import = Import.create!(
      source: parsed[:source],
      status: 'previewing',
      raw_data: parsed[:content],
      total_rows: parsed[:result][:rows].size,
      column_mapping: parsed[:result][:suggested_mapping]
    )

    redirect_to preview_import_path(@import)
  end

  def preview
    @import = Import.find(params[:id])
    parsed = parse_raw_data(@import)
    @rows = parsed[:rows]
    @headers = parsed[:headers]
    @mapping = @import.column_mapping
  end

  def confirm
    @import = Import.find(params[:id])
    mapping = params[:mapping]&.to_unsafe_h || @import.column_mapping
    @import.update!(column_mapping: mapping, status: 'confirmed')

    parsed = parse_raw_data(@import)
    result = Ingestion::ImportPersister.new(
      current_shop, @import, parsed[:rows], mapping
    ).persist!

    redirect_to '/inventory',
                notice: "Imported #{result[:imported]} items (#{result[:skipped]} skipped)."
  end

  private

  def parse_input
    if params[:file].present?
      parse_file_input
    elsif params[:raw_text].present?
      parse_text_input
    else
      redirect_to new_import_path, alert: 'Please upload a file or paste inventory data.'
      nil
    end
  end

  def parse_file_input
    content = params[:file].read
    {
      content: content,
      source: 'csv',
      result: Ingestion::CsvParser.new(content).parse
    }
  end

  def parse_text_input
    content = params[:raw_text]
    {
      content: content,
      source: 'paste',
      result: Ingestion::PasteParser.new(content).parse
    }
  end

  def parse_raw_data(import)
    if import.source == 'csv'
      Ingestion::CsvParser.new(import.raw_data).parse
    else
      Ingestion::PasteParser.new(import.raw_data).parse
    end
  end
end
