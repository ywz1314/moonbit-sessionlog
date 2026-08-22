///|
/// Movement networks reveal which exercises are repeatedly prescribed or
/// performed together.  Edge weights are counts, not claims of causality.
pub(all) struct MovementNode {
  name : String
  session_count : Int
  occurrence_count : Int
  total_sets : Int
  total_reps : Int
  average_pain : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MovementNode::name(self : MovementNode) -> String {
  self.name
}

///|
pub fn MovementNode::session_count(self : MovementNode) -> Int {
  self.session_count
}

///|
pub fn MovementNode::occurrence_count(self : MovementNode) -> Int {
  self.occurrence_count
}

///|
pub fn MovementNode::total_sets(self : MovementNode) -> Int {
  self.total_sets
}

///|
pub fn MovementNode::total_reps(self : MovementNode) -> Int {
  self.total_reps
}

///|
pub fn MovementNode::average_pain(self : MovementNode) -> Double {
  self.average_pain
}

///|
pub(all) struct MovementEdge {
  left : String
  right : String
  weight : Int
  shared_sessions : Int
  first_seen : String
  last_seen : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MovementEdge::left(self : MovementEdge) -> String {
  self.left
}

///|
pub fn MovementEdge::right(self : MovementEdge) -> String {
  self.right
}

///|
pub fn MovementEdge::weight(self : MovementEdge) -> Int {
  self.weight
}

///|
pub fn MovementEdge::shared_sessions(self : MovementEdge) -> Int {
  self.shared_sessions
}

///|
pub fn MovementEdge::first_seen(self : MovementEdge) -> String {
  self.first_seen
}

///|
pub fn MovementEdge::last_seen(self : MovementEdge) -> String {
  self.last_seen
}

///|
pub(all) struct MovementNetwork {
  nodes : Array[MovementNode]
  edges : Array[MovementEdge]
  session_count : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MovementNetwork::nodes(self : MovementNetwork) -> Array[MovementNode] {
  self.nodes.copy()
}

///|
pub fn MovementNetwork::edges(self : MovementNetwork) -> Array[MovementEdge] {
  self.edges.copy()
}

///|
pub fn MovementNetwork::session_count(self : MovementNetwork) -> Int {
  self.session_count
}

///|
fn canonical_pair(left : String, right : String) -> (String, String) {
  if left <= right {
    (left, right)
  } else {
    (right, left)
  }
}

///|
pub fn movement_network(sessions : Array[@core.Session]) -> MovementNetwork {
  let node_data : Array[(String, Int, Int, Int, Int, Int)] = []
  let edges : Array[MovementEdge] = []
  for session in sessions {
    let names = []
    for movement in session.movements {
      match node_data.search_by(item => item.0 == movement.name) {
        Some(index) => {
          let old = node_data[index]
          node_data[index] = (
            old.0,
            old.1 + 1,
            old.2 + 1,
            old.3 + movement.sets.length(),
            old.4 +
            movement.sets.fold(init=0, (total, value) => total + value.reps),
            old.5 + movement.pain,
          )
        }
        None =>
          node_data.push(
            (
              movement.name,
              1,
              1,
              movement.sets.length(),
              movement.sets.fold(init=0, (total, value) => total + value.reps),
              movement.pain,
            ),
          )
      }
      if !names.contains(movement.name) {
        names.push(movement.name)
      }
    }
    let mut left_index = 0
    while left_index < names.length() {
      let mut right_index = left_index + 1
      while right_index < names.length() {
        let pair = canonical_pair(names[left_index], names[right_index])
        match
          edges.search_by(edge => edge.left == pair.0 && edge.right == pair.1) {
          Some(index) => {
            let old = edges[index]
            edges[index] = MovementEdge::{
              left: old.left,
              right: old.right,
              weight: old.weight + 1,
              shared_sessions: old.shared_sessions + 1,
              first_seen: if session.date < old.first_seen {
                session.date
              } else {
                old.first_seen
              },
              last_seen: if session.date > old.last_seen {
                session.date
              } else {
                old.last_seen
              },
            }
          }
          None =>
            edges.push(MovementEdge::{
              left: pair.0,
              right: pair.1,
              weight: 1,
              shared_sessions: 1,
              first_seen: session.date,
              last_seen: session.date,
            })
        }
        right_index += 1
      }
      left_index += 1
    }
  }
  let nodes = node_data.map(item => MovementNode::{
    name: item.0,
    session_count: item.1,
    occurrence_count: item.2,
    total_sets: item.3,
    total_reps: item.4,
    average_pain: if item.2 == 0 {
      0.0
    } else {
      item.5.to_double() / item.2.to_double()
    },
  })
  nodes.sort_by((left, right) => right.session_count - left.session_count)
  edges.sort_by((left, right) => right.weight - left.weight)
  MovementNetwork::{ nodes, edges, session_count: sessions.length() }
}

///|
pub fn network_node(network : MovementNetwork, name : String) -> MovementNode? {
  match network.nodes.search_by(node => node.name == name) {
    Some(index) => Some(network.nodes[index])
    None => None
  }
}

///|
pub fn network_edge(
  network : MovementNetwork,
  left : String,
  right : String,
) -> MovementEdge? {
  let pair = canonical_pair(left, right)
  match
    network.edges.search_by(edge => edge.left == pair.0 && edge.right == pair.1) {
    Some(index) => Some(network.edges[index])
    None => None
  }
}

///|
pub fn neighbors(
  network : MovementNetwork,
  name : String,
) -> Array[(String, Int)] {
  let result : Array[(String, Int)] = []
  for edge in network.edges {
    if edge.left == name {
      result.push((edge.right, edge.weight))
    }
    if edge.right == name {
      result.push((edge.left, edge.weight))
    }
  }
  result.sort_by((left, right) => right.1 - left.1)
  result
}

///|
pub fn degree(network : MovementNetwork, name : String) -> Int {
  neighbors(network, name).length()
}

///|
pub fn weighted_degree(network : MovementNetwork, name : String) -> Int {
  neighbors(network, name).fold(init=0, (total, item) => total + item.1)
}

///|
pub fn network_density(network : MovementNetwork) -> Double {
  let n = network.nodes.length()
  if n < 2 {
    0.0
  } else {
    network.edges.length().to_double() / (n * (n - 1) / 2).to_double()
  }
}

///|
pub fn top_nodes(network : MovementNetwork, limit : Int) -> Array[MovementNode] {
  network.nodes[:Int::min(Int::max(0, limit), network.nodes.length())].to_owned()
}

///|
pub fn top_edges(network : MovementNetwork, limit : Int) -> Array[MovementEdge] {
  network.edges[:Int::min(Int::max(0, limit), network.edges.length())].to_owned()
}

///|
pub fn isolated_nodes(network : MovementNetwork) -> Array[MovementNode] {
  network.nodes.filter(node => degree(network, node.name) == 0)
}

///|
pub fn network_components(network : MovementNetwork) -> Array[Array[String]] {
  let remaining = network.nodes.map(node => node.name)
  let components : Array[Array[String]] = []
  while !remaining.is_empty() {
    let seed = remaining[0]
    ignore(remaining.remove(0))
    let component = [seed]
    let mut cursor = 0
    while cursor < component.length() {
      let current = component[cursor]
      for neighbor in neighbors(network, current) {
        if remaining.contains(neighbor.0) {
          match remaining.search_by(value => value == neighbor.0) {
            Some(index) => ignore(remaining.remove(index))
            None => ()
          }
          component.push(neighbor.0)
        }
      }
      cursor += 1
    }
    components.push(component)
  }
  components
}

///|
pub fn network_checksum(network : MovementNetwork) -> Int {
  let node_score = network.nodes.fold(init=13, (value, node) => {
    value * 31 + node.name.length() + node.session_count + node.total_reps
  })
  network.edges.fold(init=node_score, (value, edge) => value * 31 + edge.weight)
}

///|
pub fn network_text(network : MovementNetwork) -> String {
  let output = StringBuilder()
  output.write_string(
    "sessions=" +
    network.session_count.to_string() +
    " nodes=" +
    network.nodes.length().to_string() +
    " edges=" +
    network.edges.length().to_string() +
    "\n",
  )
  for edge in top_edges(network, 20) {
    output.write_string(
      edge.left +
      " -- " +
      edge.right +
      " weight=" +
      edge.weight.to_string() +
      "\n",
    )
  }
  output.to_string()
}

///|
pub fn movement_transition_counts(
  sessions : Array[@core.Session],
) -> Array[((String, String), Int)] {
  let counts : Array[((String, String), Int)] = []
  for session in sessions {
    let names = session.movements.map(movement => movement.name)
    let mut index = 0
    while index + 1 < names.length() {
      let transition = (names[index], names[index + 1])
      match counts.search_by(item => item.0 == transition) {
        Some(position) => {
          let old = counts[position]
          counts[position] = (old.0, old.1 + 1)
        }
        None => counts.push((transition, 1))
      }
      index += 1
    }
  }
  counts.sort_by((left, right) => right.1 - left.1)
  counts
}

///|
pub fn network_report(sessions : Array[@core.Session]) -> String {
  let network = movement_network(sessions)
  "density=" +
  network_density(network).to_string() +
  " components=" +
  network_components(network).length().to_string() +
  " checksum=" +
  network_checksum(network).to_string()
}
