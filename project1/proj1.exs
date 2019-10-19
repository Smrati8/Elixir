defmodule Proj1 do
  def vampnum do
    number = System.argv()
    [num1 | num2] = number
    number1 = String.to_integer(num1)
    number2 = String.to_integer(Enum.join(num2))
    Vampiresupervisor.start_link(number1,number2)
  end
end

defmodule Vampiresupervisor do
  use Supervisor

  def start_link(num1,num2) do
    Supervisor.start_link(__MODULE__,[num1,num2])
  end

  def init([num1,num2]) do
    list = Enum.chunk_every(Enum.to_list(num1..num2),10)
    child =
      Enum.map(list, fn(number) -> worker(Vampirenumber,[number],[id: Enum.at(number,0), restart: :permanent]) end)
    supervise(child, strategy: :one_for_one)
  end
end

defmodule Vampirenumber do
  use GenServer
  def start_link(list) do
     #:observer.start
     #main(number)
     #{:ok, self()}
     {:ok,pid} = GenServer.start_link(__MODULE__,nil)
     GenServer.cast(pid, {:calculate,list})
     {:ok,pid}
   end

   def init(number) do
    {:ok,number}
   end

   def handle_cast({:calculate,list},state) do
    main(list)
    {:noreply,state}
   end

   def main([head | tail]) do
     if digcount(head) == true do
       temp = factors(head) |> Enum.filter(fn(check)-> check != []end)
       if temp != [] do
         fangs = List.flatten([head]++temp)
         IO.puts "#{Enum.join(fangs," ")}"
       end
     else
       false
     end
     main(tail)
   end

   def main([]), do: nil

   def digcount(number) do
     (rem((length(Integer.digits(number))),2) == 0)
   end

   def factors(number) do
     split_length = div(length(to_charlist(number)), 2)
     first = round(number/:math.pow(10,(split_length-1)))
     last = round(:math.sqrt(number))

     Enum.map(first..last, fn(factor) ->
       if rem(number,factor) == 0 do
         if factor * div(number,factor) == number && length(to_charlist(div(number,factor))) == split_length && length(to_charlist(factor)) == split_length do
           comp1 = Integer.to_charlist(factor)
           comp2 = Integer.to_charlist(div(number,factor))
           comp = comp1++comp2
           if trailzero(factor,div(number,factor)) == false do
             if Enum.sort(Enum.chunk_every(comp,1)) == compare(number) do
               Enum.sort([factor,div(number,factor)])
             else
               []
             end
           else
             []
           end
         else
           []
         end
       else[]
       end
     end)
   end

   def compare(number) do
     Enum.sort(Enum.chunk_every(Integer.to_charlist(number),1))
   end

   def trailzero(factor1,factor2) do
     rem(factor1,10) == 0 && rem(factor2,10) == 0
   end
 end

 Proj1.vampnum
