# SPDX-FileCopyrightText: 2024 Torkild G. Kjevik
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.Address do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :street, :string, allow_nil?: false
    attribute :city, :string, allow_nil?: false
    attribute :state, :string, allow_nil?: false
    attribute :zip_code, :string, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:street, :city, :state, :zip_code]
    end

    update :update do
      primary? true
      accept [:street, :city, :state, :zip_code]
    end
  end
end
