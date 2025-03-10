defmodule AshEvents do
  defp get_action_name(changeset) do
    changeset.action.name
    |> to_string()
    |> String.replace("_ash_events_impl", "")
    |> String.to_atom()
  end

  def create(changeset, opts \\ []) do
    if not changeset.valid? do
      {:error, changeset}
    else
      action = get_action_name(changeset)

      Ash.ActionInput.for_action(changeset.resource, action, changeset.params, opts)
      |> Ash.run_action(opts)
    end
  end

  def create!(changeset) do
    create(changeset)
    |> case do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  def update(changeset, opts \\ []) do
    if not changeset.valid? do
      {:error, changeset}
    else
      action = get_action_name(changeset)

      params =
        Map.put(changeset.params, :record, changeset.data)

      changeset.resource
      |> Ash.ActionInput.for_action(action, params, opts)
      |> Ash.run_action(opts)
    end
  end

  def update!(changeset) do
    update(changeset)
    |> case do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  def destroy(changeset, opts \\ []) do
    if not changeset.valid? do
      {:error, changeset}
    else
      action = get_action_name(changeset)

      params = Map.put(changeset.params, :record, changeset.data)

      Ash.ActionInput.for_action(changeset.resource, action, params, opts)
      |> Ash.run_action(opts)
    end
  end

  def destroy!(changeset) do
    destroy(changeset)
    |> case do
      :ok -> :ok
      {:error, error} -> raise error
    end
  end
end
