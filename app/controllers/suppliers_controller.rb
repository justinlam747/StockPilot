# frozen_string_literal: true

class SuppliersController < ApplicationController
  def index
    @suppliers = shop_cache.suppliers
    @supplier = Supplier.new
  end

  def create
    @supplier = Supplier.new(supplier_params)
    if @supplier.save
      shop_cache.write_supplier(@supplier)
      AuditLog.record(action: 'supplier_created', shop: current_shop, request: request,
                      metadata: { supplier_id: @supplier.id })
      if request.headers['HX-Request']
        @suppliers = shop_cache.suppliers
        render partial: 'list', locals: { suppliers: @suppliers }
      else
        redirect_to suppliers_path, notice: 'Supplier created'
      end
    else
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @supplier = Supplier.find(params[:id])
    if @supplier.update(supplier_params)
      shop_cache.write_supplier(@supplier)
      if request.headers['HX-Request']
        @suppliers = shop_cache.suppliers
        render partial: 'list', locals: { suppliers: @suppliers }
      else
        redirect_to suppliers_path, notice: 'Supplier updated'
      end
    else
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @supplier = Supplier.find(params[:id])
    AuditLog.record(action: 'supplier_deleted', shop: current_shop, request: request,
                    metadata: { supplier_id: @supplier.id, name: @supplier.name })
    @supplier.destroy!
    shop_cache.invalidate_supplier(@supplier.id)
    if request.headers['HX-Request']
      @suppliers = shop_cache.suppliers
      render partial: 'list', locals: { suppliers: @suppliers }
    else
      redirect_to suppliers_path, notice: 'Supplier deleted'
    end
  end

  private

  def supplier_params
    params.require(:supplier).permit(:name, :email, :phone, :lead_time_days, :star_rating, :rating_notes)
  end
end
