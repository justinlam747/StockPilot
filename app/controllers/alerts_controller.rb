class AlertsController < ApplicationController
  def index
    @alerts = Alert.order(created_at: :desc).page(params[:page]).per(25)
  end

  def dismiss
    alert = Alert.find(params[:id])
    alert.update!(dismissed: true)
    head :ok
  end
end
