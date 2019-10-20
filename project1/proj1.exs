defmodule Proj1 do
  def vampnum do
    #Input the number from the console
    number = System.argv()
    [num1 | num2] = number
    number1 = String.to_integer(num1)
    number2 = String.to_integer(Enum.join(num2))
    #Invoking the Supervisor
    {:ok, supervisor_id} = Vampiresupervisor.start_link(number1, number2)

    childrens = Supervisor.which_children(supervisor_id)

    #Call made to the childrens to get the details from Pid and print the data
    Enum.each(Enum.sort(childrens), fn {_id, pid, _type, _module} ->
      if GenServer.call(pid, :get_state) != [] do
        IO.puts(GenServer.call(pid, :get_state))
      end
    end)
  end
end

#Module created for Supervisor
defmodule Vampiresupervisor do
  use Supervisor

  def start_link(num1, num2) do
    Supervisor.start_link(__MODULE__, [num1, num2])
  end

  def init([num1, num2]) do
    list = Enum.chunk_every(Enum.to_list(num1..num2), 10)

    child =
      Enum.map(list, fn number ->
        worker(Vampirenumber, [number], id: Enum.at(number, 0), restart: :permanent)
      end)

    supervise(child, strategy: :one_for_one)
  end
end

defmodule Vampirenumber do
  use GenServer

  #Initiating the Genserver
  def start_link(list) do
    {:ok, pid} = GenServer.start_link(__MODULE__, nil)
    GenServer.cast(pid, {:calculate, list})
    {:ok, pid}
  end

  def init(number) do
    {:ok, number}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  #passing the factors method that calculate the fangs of the number
  def handle_cast({:calculate, list}, _state) do
    values =
      Enum.map(list, fn n ->
        temp = factors(n) |> Enum.filter(fn check -> check != [] end)

        if temp != [] do
          fangs = List.flatten([n] ++ temp)
          Enum.join(fangs, " ")
        else
          ""
        end
      end)

    result = Enum.filter(values, fn r -> r != "" end)
    if length(result) > 1 do
      {:noreply, Enum.join(result, "\n")}
    else
      {:noreply, result}
    end
  end

  #Check if the digit count is even
  def digcount(number) do
    rem(length(Integer.digits(number)), 2) == 0
  end

  #calculating the fangs of the number
  def factors(number) do
    split_length = div(length(to_charlist(number)), 2)
    first = round(number / :math.pow(10, split_length))
    last = round(:math.sqrt(number))

    values =
      Enum.map(first..last, fn factor ->
        if rem(number, factor) == 0 do
          if factor * div(number, factor) == number &&
               length(to_charlist(div(number, factor))) == split_length &&
               length(to_charlist(factor)) == split_length do
            comp1 = Integer.to_charlist(factor)
            comp2 = Integer.to_charlist(div(number, factor))
            comp = comp1 ++ comp2

            if trailzero(factor, div(number, factor)) == false do
              if Enum.sort(Enum.chunk_every(comp, 1)) == compare(number) do
                Enum.sort([factor, div(number, factor)])
              else
                []
              end
            else
              []
            end
          else
            []
          end
        else
          []
        end
      end)

    values = Enum.filter(values, fn v -> v |> length() > 0 end)
    values
  end

  #checking if the permuattion of the fangs matches the number
  def compare(number) do
    Enum.sort(Enum.chunk_every(Integer.to_charlist(number), 1))
  end

  #Checking if both the fangs are not having trailing zeros
  def trailzero(factor1, factor2) do
    rem(factor1, 10) == 0 && rem(factor2, 10) == 0
  end
end

Proj1.vampnum()
