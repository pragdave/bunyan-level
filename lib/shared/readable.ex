defmodule Bunyan.Shared.Readable do


  @moduledoc """
  This module creates the basic environment for a Bunyan source plugin,
  reasponsible for capturing loggable events and injecting them into the
  collector.

  To create new reader plugin:

  1. `mix new bunyan_source_«name» --module Bunyan.Source.«Name»`

  2. Decide what configuration options your plugin needs. Create
     a module `Bunyan.Source.«Name».State` that defines a structure
     to hold the options. That structure must also contain a field named
     `collector`, which this module will populate with a reference to the
     collector your code should send messages to.

     Also in that module write a function

     ~~~ elixir
     @spec from(keyword) :: %__MODULE__{}
     ~~~

     This is responsible for taking a set of options from the runtime
     configuration of the app that uses your plugin and using them to populate
     the structure. You'll also do validation here, raising exceptions for bad
     or missing options.

  3. Delete `lib/bunyan_source_«name».ex`.

  4. Create `lib/«name».ex`:

     ~~~ elixir
     defmodule Bunyan.Source.«Name» do

      use Bunyan.Shared.Readable

      def start(config) do
        # your code goes here
      end

     end
     ~~~

     Your `start` function will be passed the structure you populated in step 2.
     It can send messages to the `config.collector` to inject them into the main
     logger.

  """

  @type collector :: pid() | atom()


  @doc """
  If called in Bunyan.Source.Api, this generates

  ~~~ elixir
  def child_spec({ collector, config }) do

    Supervisor.child_spec({ Bunyan.Source.Api.Server, state }, [])
  end

  def state_from_config(collector, config) do
    Readable.validate_collector(Bunyan.Source.Api, collector)
    Bunyan.Source.Api.State.from(config) |> Map.put(:collector, collector)
  end
  ~~~
  """
  defmacro __using__(args \\ []) do

    caller = __CALLER__.module
    state_module  = args[:state_module]  || Module.concat(caller,  State)
    server_module = args[:server_module] || Module.concat(caller,  Server)

    quote do
      def child_spec({ collector, config }) do
        Supervisor.child_spec({
          unquote(server_module),
          state_from_config(collector, config)
         }, [])
      end
      defoverridable child_spec: 1

      def state_from_config(collector, config) do
        unquote(__MODULE__).validate_collector(unquote(caller), collector)
        unquote(state_module).from(config) |> Map.put(:collector, collector)
      end
    end
  end



  def validate_collector(module, nil) do
    raise """

    Missing or invalid `collector:` option in the
    configuration for #{inspect module}.

    """
  end

  def validate_collector(module, collector) when is_atom(collector) do
    case Process.whereis(collector) do
      nil ->
        raise """

        #{inspect module} cannot find a collector
        named #{inspect collector}. Please check the `collector:`
        option in the appropriate section of your Bunyan config.

        """
      pid ->
        validate_collector(module, pid)
      end
    end

  def validate_collector(module, pid) when is_pid(pid) do
    cond do
      Process.alive?(pid) ->
        :ok

      true ->
        raise """

        #{inspect module} cannot find a collector
        at pid #{inspect pid}. Please check the `collector:`
        option in the appropriate section of your Bunyan config.

        """
    end
  end
end
