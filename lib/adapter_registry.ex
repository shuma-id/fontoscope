defmodule Fontoscope.AdapterRegistry do
  @moduledoc """
  Registry for font file analysis adapters
  """
  alias Fontoscope.{TTXAdapter, EOTAdapter}

  @adapters Application.compile_env(:fontoscope, :adapters, [TTXAdapter, EOTAdapter])

  @doc """
  Find adapter by extension
  """
  @spec find_by_extension(String.t()) :: {:ok, module()} | {:error, :not_found}
  def find_by_extension(extension) do
    case Enum.find(@adapters, & extension in &1.supported_extensions()) do
      nil -> {:error, "Unsupported file extension: #{extension}"}
      adapter -> {:ok, adapter}
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
