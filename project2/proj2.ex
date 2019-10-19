defmodule Proj2 do
  use GenServer

  def main(input) do
    # Input of the nodes, Topology and Algorithm
    #input = System.argv()
    [numNodes, topology, algorithm] = input
    numNodes = numNodes |> String.to_integer()
    startTime = System.monotonic_time(:millisecond)

    # Associating all nodes with their PID's
    allNodes =
      Enum.map(1..numNodes, fn x ->
        pid = start_node()
        updatePIDState(pid, x)
        pid
      end)

    # Indexing all the PID's with the nodes
    indexed_actors =
      Stream.with_index(allNodes, 1)
      |> Enum.reduce(%{}, fn {pids, nodeID}, acc -> Map.put(acc, nodeID, pids) end)

    # Setting the neighbors according to the chosen topology
    neighbours = set_neighbours(allNodes, indexed_actors, numNodes, topology)

    cond do
      algorithm == "gossip" ->
        IO.puts("Initiating Gossip Algorithm with #{topology} topology...")
        startGossip(allNodes, neighbours)
        wait_till_converged_gossip(allNodes, startTime)

      algorithm == "push-sum" ->
        IO.puts("Initiating push-sum Algorithm with #{topology} topology...")
        startPushSum(allNodes, startTime, indexed_actors, neighbours)
        wait_till_converged_pushsum(allNodes, startTime)

      true ->
        IO.puts("Invalid ALgorithm!")
    end
  end

  def init(:ok) do
    {:ok, {0, 0, [], 1}}
  end

  def start_node() do
    {:ok, pid} = GenServer.start_link(__MODULE__, :ok, [])
    pid
  end

  def updatePIDState(pid, nodeID) do
    GenServer.call(pid, {:UpdatePIDState, nodeID})
  end
  # ---------------------------------GOSSIP----------------------------------

  def startGossip(allnodes, neighbours) do
    firstNode = Enum.random(allnodes)
    neighborsList = Map.fetch!(neighbours, firstNode)
    chooseRandomNeighbor = Enum.random(neighborsList)
    neighborsList = Map.fetch!(neighbours, chooseRandomNeighbor)
    IO.puts("Executing...")

    GenServer.cast(chooseRandomNeighbor, {:sendGossip, neighbours, neighborsList})
  end

  def receiveGossip(neighbours, neighborsList) do
    newNode = Enum.random(neighborsList)
    neighborsList = Map.fetch!(neighbours, newNode)
    GenServer.cast(newNode, {:sendGossip, neighbours, neighborsList})
    Process.sleep(1)
    GenServer.cast(self(), {:sendGossip, neighbours, neighborsList})
  end

  # Check if the nodes have converged
  def wait_till_converged_gossip(allNodes, startTime) do
    counters =
      Enum.map(allNodes, fn pid ->
        state = GenServer.call(pid, :getStateGossip)
        {_, counter, _, _} = state
        counter
      end)

    if length(Enum.filter(counters, fn x -> x >= 1 end)) < (0.9 * length(allNodes)) |> trunc do
      wait_till_converged_gossip(allNodes, startTime)
    else
      endTime = System.monotonic_time(:millisecond)
      timeTaken = endTime - startTime
      IO.puts("Convergence achieved in #{timeTaken} Milliseconds")
    end
  end

  # ----------------------------------------SETTING NEIGHBOURS------------------------------------

  def set_neighbours(actors, indexd_actors, numNodes, topology) do
    cond do
      topology == "line" ->
        Enum.reduce(1..numNodes, %{}, fn x, acc ->
          neighbors =
            cond do
              x == 1 -> [2]
              x == numNodes -> [numNodes - 1]
              true -> [x - 1, x + 1]
            end

          neighbor_pids =
            Enum.map(neighbors, fn i ->
              {:ok, n} = Map.fetch(indexd_actors, i)
              n
            end)

          {:ok, actor} = Map.fetch(indexd_actors, x)
          Map.put(acc, actor, neighbor_pids)
        end)

      topology == "full" ->
        Enum.reduce(1..numNodes, %{}, fn x, acc ->
          neighbors =
            cond do
              x == 1 -> Enum.to_list(2..numNodes)
              x == numNodes -> Enum.to_list(1..(numNodes - 1))
              true -> Enum.to_list(1..(x - 1)) ++ Enum.to_list((x + 1)..numNodes)
            end

          neighbor_pids =
            Enum.map(neighbors, fn i ->
              {:ok, n} = Map.fetch(indexd_actors, i)
              n
            end)

          {:ok, actor} = Map.fetch(indexd_actors, x)
          Map.put(acc, actor, neighbor_pids)
        end)
  end


  # Handle Cast methods for PushSum and Gossip
  def handle_cast(
        {:ReceivePushSum, incomingS, incomingW, startTime, indexed_actors, neighbours,
         neighbours_map},
        state
      ) do
    {s, pscount, _adjList, w} = state
    myS = s + incomingS
    myW = w + incomingW
    difference = abs(myS / myW - s / w)

    randomNode = Enum.random(neighbours)
    neighbours = Map.fetch!(neighbours_map, randomNode)

    state =
      if(difference < :math.pow(10, -10)) do
        {myS / 2, pscount + 1, neighbours, myW / 2}
      else
        {myS / 2, 0, neighbours, myW / 2}
      end

    sendPushSum(
      randomNode,
      myS / 2,
      myW / 2,
      startTime,
      indexed_actors,
      neighbours,
      neighbours_map
    )

    {:noreply, state}
  end

  def handle_cast({:sendGossip, neighbours, neighborsList}, state) do
    {nodeID, counter, _list, w} = state
    state = {nodeID, counter + 1, neighborsList, w}
    {_nodeID, counter, _list, _w} = state

    if counter < 10 do
      receiveGossip(neighbours, neighborsList)
    end

    {:noreply, state}
  end

  # Handle call for associating specific Node with PID
  def handle_call({:UpdatePIDState, nodeID}, _from, state) do
    {a, b, c, d} = state
    state = {nodeID, b, c, d}
    {:reply, a, state}
  end

  # Handle calls for Gossip and PushSum
  def handle_call(:getStateGossip, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
