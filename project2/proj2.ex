defmodule Proj2 do
  use GenServer

  def main(input) do
    # Input of the nodes, Topology and Algorithm
    #input = System.argv()
    [numNodes, topology, algorithm] = input
    numNodes = numNodes |> String.to_integer()
    startTime = System.monotonic_time(:millisecond)

    # Rounding of the values to the nearest square and cube
    numNodes =
      cond do
        topology == "torus" ->
          rowCountvalue = :math.pow(numNodes, 1 / 3) |> ceil
          rowCountvalue * rowCountvalue * rowCountvalue

        topology == "honeycomb" || topology == "randHoneycomb" || topology == "rand2D" ->
          row_count = :math.sqrt(numNodes) |> ceil
          row_count * row_count

        true ->
          numNodes
      end

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

  # ---------------------------------PUSH_SUM----------------------------------

  def startPushSum(allNodes, startTime, indexed_actors, neighbours_map) do
    chosenFirstNode = Enum.random(allNodes)
    neighbourList = Map.fetch!(neighbours_map, chosenFirstNode)
    IO.puts("Executing...")

    GenServer.cast(
      chosenFirstNode,
      {:ReceivePushSum, 0, 0, startTime, indexed_actors, neighbourList, neighbours_map}
    )
  end

  def sendPushSum(randomNode, myS, myW, startTime, indexed_actors, neighbours, neighbours_map) do
    GenServer.cast(
      randomNode,
      {:ReceivePushSum, myS, myW, startTime, indexed_actors, neighbours, neighbours_map}
    )
  end

  # Check if the nodes have converged
  def wait_till_converged_pushsum(allNodes, startTime) do
    pscounts =
      Enum.map(allNodes, fn pid ->
        state = GenServer.call(pid, :get_state)
        {_, pscount, _, _} = state
        pscount
      end)

    if length(Enum.filter(pscounts, fn x -> x == 2 end)) < (0.9 * length(allNodes)) |> trunc do
      wait_till_converged_gossip(allNodes, startTime)
    else
      endTime = System.monotonic_time(:millisecond)
      timeTaken = endTime - startTime
      IO.puts("Convergence achieved in #{timeTaken} Milliseconds")
    end
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

      topology == "rand2D" ->
        initial_map = %{}
        # creating a map with key = actor pid  and value = list of x and y coordinates
        actor_with_coordinates =
          Enum.map(actors, fn x ->
            Map.put(initial_map, x, [:rand.uniform()] ++ [:rand.uniform()])
          end)

        Enum.reduce(actor_with_coordinates, %{}, fn x, acc ->
          [actor_pid] = Map.keys(x)
          actor_coordinates = Map.values(x)

          list_of_neighbors =
            ([] ++
               Enum.map(actor_with_coordinates, fn x ->
                 if is_connected(actor_coordinates, Map.values(x)) do
                   Enum.at(Map.keys(x), 0)
                 end
               end))
            |> Enum.filter(&(&1 != nil))

          # one actor should not be its own neighbour
          updated_neighbors = list_of_neighbors -- [actor_pid]
          Map.put(acc, actor_pid, updated_neighbors)
        end)
  end

  # checks if 2 nodes are within 0.1 distance
  def is_connected(actor_cordinates, other_cordinates) do
    actor_cordinates = List.flatten(actor_cordinates)
    other_cordinates = List.flatten(other_cordinates)

    x1 = Enum.at(actor_cordinates, 0)
    x2 = Enum.at(other_cordinates, 0)
    y1 = Enum.at(actor_cordinates, 1)
    y2 = Enum.at(other_cordinates, 1)

    x_dist = :math.pow(x2 - x1, 2)
    y_dist = :math.pow(y2 - y1, 2)
    distance = round(:math.sqrt(x_dist + y_dist))

    cond do
      distance > 1 -> false
      distance <= 1 -> true
    end
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
