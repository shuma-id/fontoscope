defmodule Fontoscope.AdapterRegistry do
  @moduledoc """
  Registry for font file analysis adapters
  """
  alias Fontoscope.{EOTAdapter, TTXAdapter}

  @adapters Application.compile_env(:fontoscope, :adapters, [TTXAdapter, EOTAdapter])

  @doc """
  Find adapter by extension
  """
  @spec find_by_extension(String.t()) :: {:ok, module()} | {:error, String.t()}
  def find_by_extension(extension) do
    ext_to_adapter =
      @adapters
      |> Enum.flat_map(fn adapter -> Enum.map(adapter.supported_extensions(), &{&1, adapter}) end)
      |> Map.new()

    with :error <- Map.fetch(ext_to_adapter, extension) do
      supported_exts = Enum.join(Map.keys(ext_to_adapter), ", ")
      {:error, "Unsupported extension: '#{extension}'. Supported: #{supported_exts}"}
    end
  end

  @doc """
  List all supported extensions
  """
  @spec supported_extensions() :: [String.t()]
  def supported_extensions do
    @adapters
    |> Enum.flat_map(& &1.supported_extensions())
    |> Enum.uniq()
  end

  @doc """
  List all adapters
  """
  @spec adapters() :: [module()]
  def adapters do
    @adapters
  end
end
