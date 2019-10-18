#Final Code

defmodule Vampirenumber do
 def start_link(num1,num2) do
    #num1 = "n1 = " |> IO.gets() |> String.trim_trailing() |> String.to_integer()
    #num2 = "n2 = " |> IO.gets() |> String.trim_trailing() |> String.to_integer()
    main(num1,num2)
  end

  def main(num1,num2) do
    Enum.each(num1..num2,fn(number)->
    if digcount(number) == true do
      temp = factors(number) |> Enum.filter(fn(check)-> check != []end)
      if temp != [] do
        fangs = List.flatten([number]++temp)
        IO.puts "#{Enum.join(fangs," ")}"
      end
    else
      false
    end
  end)
  end

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
